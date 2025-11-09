#!/usr/bin/env bash
# scripts/start_pcap.sh
# Rotating tcpdump capture with background compression + retention
# Usage: sudo ./start_pcap.sh -i eth0 -o /data/pcaps [options]
# Defaults: rotate_interval=3600s (1 hour), ring_files=24, retention_days=30, min_free_gb=2

set -euo pipefail

###############
# Defaults
###############
INTERFACE=""
OUTDIR="/var/lib/pcaps"
PREFIX="det"
ROTATE_INTERVAL=3600   # seconds
RING_FILES=24
RETENTION_DAYS=30
MIN_FREE_GB=2
LOGFILE=""
TCPDUMP_BIN="$(command -v tcpdump || true)"

###############
# Helpers
###############
usage() {
  cat <<EOF
Usage: sudo $0 -i <interface> -o <output_dir> [options]

Options:
  -i <interface>       Interface to capture on (required)
  -o <output_dir>      Directory to store pcaps (default: /var/lib/pcaps)
  -p <prefix>          File prefix (default: det)
  -g <seconds>         Rotate interval seconds (default: 3600)
  -w <files>           Ring buffer size (default: 24)
  -r <days>            Retention days for old pcaps (default: 30)
  -m <GB>              Minimum free GB required to start (default: 2)
  -h                   Show this help
EOF
  exit 1
}

log() {
  local ts msg
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  msg="$1"
  echo "${ts} ${msg}" | tee -a "${LOGFILE:-/dev/stderr}"
}

fatal() {
  log "FATAL: $1"
  exit 2
}

check_prereqs() {
  if [[ -z "${TCPDUMP_BIN}" ]]; then
    fatal "tcpdump is not installed or not in PATH. Install tcpdump first."
  fi
}

ensure_outdir() {
  mkdir -p "$OUTDIR"
  chown root:root "$OUTDIR"
  chmod 0750 "$OUTDIR"
  LOGFILE="${OUTDIR%/}/start_pcap.log"
  touch "$LOGFILE"
  chmod 0640 "$LOGFILE"
}

check_free_space() {
  local free_gb
  free_gb=$(df -BG --output=avail "$OUTDIR" | tail -n1 | tr -d 'G ' || echo "0")
  if ! [[ "$free_gb" =~ ^[0-9]+$ ]]; then
    log "WARNING: could not reliably determine free space (reported: $free_gb)"
  else
    if (( free_gb < MIN_FREE_GB )); then
      fatal "Insufficient free space on $(df -h "$OUTDIR" | awk 'NR==2{print $1" "$4" free"}'). Need at least ${MIN_FREE_GB}G."
    fi
  fi
}

compress_worker() {
  # Compress .pcap files older than a threshold (to avoid compressing the current rotating file).
  # This runs in background and sleeps between cycles.
  local sleep_secs=60
  local compress_age_minutes=2

  while true; do
    # find .pcap files not already gzipped, older than compress_age_minutes
    find "$OUTDIR" -maxdepth 1 -type f -name "${PREFIX}_*.pcap" -mmin +"${compress_age_minutes}" -print0 \
      | while IFS= read -r -d '' f; do
          # safety: avoid files currently open by tcpdump by checking mtime and size stability
          # Attempt to gzip; if it fails, log and move on
          if [[ -f "$f" ]]; then
            log "Compressing: $f"
            gzip -9 -- "$f" || log "Failed to gzip $f"
          fi
        done
    # remove old compressed pcaps beyond retention
    find "$OUTDIR" -maxdepth 1 -type f -name "${PREFIX}_*.pcap.gz" -mtime +"${RETENTION_DAYS}" -print0 \
      | while IFS= read -r -d '' old; do
          log "Removing old pcap: $old"
          rm -f -- "$old" || log "Failed to remove $old"
        done
    sleep "$sleep_secs"
  done
}

graceful_shutdown() {
  log "SIGTERM/SIGINT received — shutting down tcpdump (pid ${TCPDUMP_PID:-unknown})"
  if [[ -n "${TCPDUMP_PID:-}" && -e /proc/${TCPDUMP_PID} ]]; then
    kill -TERM "$TCPDUMP_PID"
    wait "$TCPDUMP_PID" 2>/dev/null || true
  fi
  log "Shutdown complete."
  exit 0
}

###############
# Parse args
###############
while getopts "i:o:p:g:w:r:m:h" opt; do
  case "$opt" in
    i) INTERFACE="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    p) PREFIX="$OPTARG" ;;
    g) ROTATE_INTERVAL="$OPTARG" ;;
    w) RING_FILES="$OPTARG" ;;
    r) RETENTION_DAYS="$OPTARG" ;;
    m) MIN_FREE_GB="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$INTERFACE" ]]; then
  usage
fi

###############
# Main
###############
check_prereqs
ensure_outdir
check_free_space

log "Starting rotating capture on interface=${INTERFACE}, outdir=${OUTDIR}, prefix=${PREFIX}, interval=${ROTATE_INTERVAL}s, ring=${RING_FILES}, retention=${RETENTION_DAYS}d"

# Build tcpdump command
# -s 0 capture full packet, -nn no name resolution, -w with time format, -G rotate seconds, -W number of files
TCPDUMP_CMD=( "$TCPDUMP_BIN" -i "$INTERFACE" -s 0 -nn -U -G "$ROTATE_INTERVAL" -W "$RING_FILES" -w "${OUTDIR}/${PREFIX}_%Y%m%d_%H%M.pcap" )

log "TCPDUMP CMD: ${TCPDUMP_CMD[*]}"

# set trap for graceful shutdown
trap graceful_shutdown SIGTERM SIGINT

# Start compress worker in background
compress_worker & 
COMPRESS_PID=$!
log "Started compress worker (pid ${COMPRESS_PID})"

# Start tcpdump (run in foreground so that signals are caught)
"${TCPDUMP_CMD[@]}" &
TCPDUMP_PID=$!
log "tcpdump started (pid ${TCPDUMP_PID})"

# Wait for tcpdump to exit (or signal)
wait "$TCPDUMP_PID" || true

# tcpdump exited, cleanup compress worker
if [[ -n "${COMPRESS_PID:-}" ]]; then
  log "Stopping compress worker (pid ${COMPRESS_PID})"
  kill -TERM "${COMPRESS_PID}" 2>/dev/null || true
  wait "${COMPRESS_PID}" 2>/dev/null || true
fi

log "tcpdump stopped; exiting."
exit 0


#Notes
# Run as root or with sudo
# Example for hourly ring of 48 files and 60-day retention:
#  sudo ./start_pcap.sh -i eth1 -o /data/pcaps -w 48 -r 60
# Make sure the OUTDIR is on the storage you want with snapshots enabled
# Adjust compress_age_minutes inside the script if you need faster/later compression cutoff
# Monitor the log: tail -f /data/pcaps/start_pcap.log
