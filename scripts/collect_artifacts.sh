#!/usr/bin/env bash
# scripts/collect_artifacts.sh
# Organize & hash artifacts for a detonation run.
# Works on Linux (sensor/analysis VM). You provide source paths; it builds:
#  /<dest_root>/<sample_id>/{pcaps,sysmon,eventlogs,notes,extras}/
# and generates hashes.txt, manifest.json, transfer_log.txt, summary.txt
#
# Examples:
#  sudo ./collect_artifacts.sh -s 2025-11-08_Emotet \
#       --pcap /data/pcaps/det_20251108_*.pcap.gz \
#       --eventlogs ~/exports/{System.evtx,Application.evtx,Security.evtx} \
#       --sysmon ~/exports/Sysmon.evtx \
#       --notes ~/notes/2025-11-08_Emotet_notes.md \
#       --extra ~/screens/flow.png --compress
#
#  sudo ./collect_artifacts.sh -s T1234 --move --pcap /data/pcaps/run_*.pcap

set -euo pipefail

############################
# Defaults / Globals
############################
SAMPLE_ID=""
DEST_ROOT="/storage/artifacts"
DO_MOVE=0
DO_COMPRESS=0
OUT_DIR=""
LOGFILE=""
MANIFEST_JSON=""
START_TS_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
HOSTNAME_FQDN="$(hostname -f || hostname)"
USER_NAME="${SUDO_USER:-$USER}"

declare -a PCAP_PATHS
declare -a EVENTLOG_PATHS
declare -a SYSMON_PATHS
declare -a NOTES_PATHS
declare -a EXTRA_PATHS

############################
# Helpers
############################
usage() {
  cat <<'EOF'
Usage:
  collect_artifacts.sh -s <sample_id> [options]

Required:
  -s, --sample-id <id>     Sample ID (folder name under DEST_ROOT)

Options:
  -d, --dest-root <path>   Destination root (default: /storage/artifacts)
      --pcap <glob|path>   PCAP/PCAPNG file(s) (repeatable)
      --eventlogs <paths>  Windows Event Log .evtx exports (repeatable)
      --sysmon <paths>     Sysmon .evtx or JSON logs (repeatable)
      --notes <paths>      notes.md or text files (repeatable)
      --extra <paths>      Any additional files (repeatable)
      --move               Move instead of copy (atomic mv)
      --compress           Create <sample_id>.tar.gz at the end
  -h, --help               Show help

Examples:
  collect_artifacts.sh -s 2025-11-08_Test --pcap /data/pcaps/*.pcap.gz --notes ~/notes.md --compress
EOF
  exit 1
}

log() {
  local ts msg
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  msg="$1"
  echo "${ts} ${msg}"
  [[ -n "$LOGFILE" ]] && echo "${ts} ${msg}" >> "$LOGFILE"
}

fatal() {
  log "FATAL: $1"
  exit 2
}

ensure_tools() {
  local req=(sha256sum jq)
  for b in "${req[@]}"; do
    command -v "$b" >/dev/null 2>&1 || fatal "Missing required tool: $b"
  done
}

mk_layout() {
  OUT_DIR="${DEST_ROOT%/}/${SAMPLE_ID}"
  mkdir -p "$OUT_DIR"/{pcaps,sysmon,eventlogs,notes,extras}
  LOGFILE="${OUT_DIR}/collect_artifacts.log"
  : > "$LOGFILE"
  chmod 0750 "$OUT_DIR" || true
  chmod 0640 "$LOGFILE" || true
}

copy_or_move() {
  local mode="$1"; shift
  local dest_sub="$1"; shift
  local arr=("$@")

  local dest="${OUT_DIR}/${dest_sub}"
  mkdir -p "$dest"

  shopt -s nullglob
  for src in "${arr[@]}"; do
    # Expand globs safely
    for f in $src; do
      [[ -f "$f" ]] || { log "SKIP (not a file): $f"; continue; }
      if [[ "$mode" == "move" ]]; then
        log "MOVE $f -> $dest/"
        mv -f -- "$f" "$dest/" || log "WARN: move failed for $f"
      else
        log "COPY $f -> $dest/"
        cp -f -- "$f" "$dest/" || log "WARN: copy failed for $f"
      fi
    done
  done
  shopt -u nullglob
}

hash_dir_recursive() {
  local d="$1"
  local outfile="${OUT_DIR}/hashes.txt"
  log "Hashing contents of $d -> hashes.txt"
  ( cd "$OUT_DIR" && find . -type f ! -name "hashes.txt" -print0 \
      | sort -z \
      | xargs -0 sha256sum ) > "$outfile"
  chmod 0640 "$outfile" || true
}

write_transfer_log() {
  local f="${OUT_DIR}/transfer_log.txt"
  log "Writing transfer log"
  {
    echo "sample_id: ${SAMPLE_ID}"
    echo "host: ${HOSTNAME_FQDN}"
    echo "user: ${USER_NAME}"
    echo "started_utc: ${START_TS_UTC}"
    echo "completed_utc: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "mode: $([[ $DO_MOVE -eq 1 ]] && echo move || echo copy)"
  } > "$f"
  chmod 0640 "$f" || true
}

write_summary_stub() {
  local f="${OUT_DIR}/summary.txt"
  [[ -e "$f" ]] && return 0
  log "Creating summary.txt"
  cat > "$f" <<EOF
Sample ID: ${SAMPLE_ID}
Start (UTC): ${START_TS_UTC}
End   (UTC): $(date -u +'%Y-%m-%dT%H:%M:%SZ')

Executive Summary:
- (What did it do? High-level behavior.)

Key Observations:
- Process creation / persistence:
- Network indicators (IPs/domains/URIs):
- Downloads / dropped files:
- Notable registry or service changes:

Evidence:
- PCAPs: ./pcaps
- Event Logs: ./eventlogs
- Sysmon: ./sysmon
- Notes: ./notes

IOCs (draft):
- IPs:
- Domains:
- Hashes:

Next Steps:
- (Follow-up analysis, rules, detections.)
EOF
  chmod 0640 "$f" || true
}

write_manifest_json() {
  MANIFEST_JSON="${OUT_DIR}/manifest.json"
  log "Writing manifest.json"
  local now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  # Build file list with sizes
  local tmpfile
  tmpfile="$(mktemp)"
  ( cd "$OUT_DIR" && find . -type f -printf '%P\t%s\n' | sort ) > "$tmpfile"

  # Compose JSON with jq
  jq -Rn --slurpfile files "$tmpfile" '
    def toobj($line):
      ($line | split("\t")) as $f |
      { path: $f[0], bytes: ($f[1] | tonumber) };

    { sample_id: $ENV.SAMPLE_ID,
      host: $ENV.HOSTNAME_FQDN,
      user: $ENV.USER_NAME,
      created_utc: $ENV.START_TS_UTC,
      finalized_utc: "'"$now"'",
      files: (inputs | split("\n") | map(select(length>0)) | map(toobj(.)))
    }
  ' > "$MANIFEST_JSON"
  rm -f "$tmpfile"
  chmod 0640 "$MANIFEST_JSON" || true
}

compress_bundle() {
  local tgz="${OUT_DIR}.tar.gz"
  log "Creating archive: $tgz"
  ( cd "$(dirname "$OUT_DIR")" && tar -czf "$(basename "$tgz")" "$(basename "$OUT_DIR")" )
  chmod 0640 "$tgz" || true
  log "Archive created."
}

############################
# Parse args
############################
[[ $# -eq 0 ]] && usage
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--sample-id) SAMPLE_ID="${2:-}"; shift 2 ;;
    -d|--dest-root) DEST_ROOT="${2:-}"; shift 2 ;;
    --pcap)         PCAP_PATHS+=("${2:-}"); shift 2 ;;
    --eventlogs)    EVENTLOG_PATHS+=("${2:-}"); shift 2 ;;
    --sysmon)       SYSMON_PATHS+=("${2:-}"); shift 2 ;;
    --notes)        NOTES_PATHS+=("${2:-}"); shift 2 ;;
    --extra)        EXTRA_PATHS+=("${2:-}"); shift 2 ;;
    --move)         DO_MOVE=1; shift ;;
    --compress)     DO_COMPRESS=1; shift ;;
    -h|--help)      usage ;;
    *)              echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$SAMPLE_ID" ]] && fatal "Missing required -s|--sample-id"

############################
# Main
############################
ensure_tools
mk_layout
log "Collecting artifacts for sample_id=${SAMPLE_ID} dest=${OUT_DIR}"

MODE="copy"; [[ $DO_MOVE -eq 1 ]] && MODE="move"

# Perform transfers
[[ ${#PCAP_PATHS[@]}     -gt 0 ]] && copy_or_move "$MODE" "pcaps"     "${PCAP_PATHS[@]}"
[[ ${#EVENTLOG_PATHS[@]} -gt 0 ]] && copy_or_move "$MODE" "eventlogs" "${EVENTLOG_PATHS[@]}"
[[ ${#SYSMON_PATHS[@]}   -gt 0 ]] && copy_or_move "$MODE" "sysmon"    "${SYSMON_PATHS[@]}"
[[ ${#NOTES_PATHS[@]}    -gt 0 ]] && copy_or_move "$MODE" "notes"     "${NOTES_PATHS[@]}"
[[ ${#EXTRA_PATHS[@]}    -gt 0 ]] && copy_or_move "$MODE" "extras"    "${EXTRA_PATHS[@]}"

# Generate metadata
hash_dir_recursive "$OUT_DIR"
write_transfer_log
write_summary_stub
write_manifest_json

# Optional compression
if [[ $DO_COMPRESS -eq 1 ]]; then
  compress_bundle
fi

log "Done."
exit 0


# Install deps (if needed) sudo apt-get install -y tcpdump jq coreutils Run
# Run
# sudo ./collect_artifacts.sh -s <name you choose> --pcap /data/pacaps/*.pcap.gz --eventlogs
# ~/exports/*.evtx --notes ~/notes/sampleA.md --compress

