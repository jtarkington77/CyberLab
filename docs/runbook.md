# Cyber Security Lab Runbook   

---

## Purpose
This runbook outlines the operational flow of the Cyber Security Lab — how to safely conduct detonation tests, capture data, and analyze results while maintaining full isolation.  
It ensures each analysis follows a consistent, auditable process from start to finish.

---

## 1. Lab Initialization

### 1.1 Network & Isolation Verification
Before running any sample:
- Confirm the **Detonation VLAN** and **Monitoring VLAN** are active in OPNsense.  
- Ensure **no routing** exists between the lab VLANs and the home or production network.  
- Verify **libvirt isolation**: the detonation VM should only attach to the isolated libvirt bridge.  
- Confirm mirrored traffic from the detonation VLAN is visible on the Linux packet sensor.

### 1.2 Host Readiness
- Power on:
  - **Wazuh Manager (Wazoo)**
  - **Linux Packet Sensor**
  - **Kali Analysis VM**
- Start system logging on the manager and confirm the agent heartbeat is received from the detonation VM.
- Verify **time synchronization** on all systems (NTP must match across hosts).

---

## 2. Detonation Preparation

### 2.1 Snapshot & Baseline
- Take a **snapshot** of the detonation VM. Label with timestamp and sample ID.  
- Record baseline:
  - Running processes  
  - Open network ports  
  - System uptime  
  - Hash of clean state if desired (`Get-FileHash` on Windows).

### 2.2 Configure Capture
- Start `start_pcap.sh` on the packet sensor to begin rotating packet capture.  
- Confirm output files are writing to `/data/pcaps/`.  
- Verify disk space is sufficient for capture duration.

### 2.3 Logging
- Ensure Wazuh agent is active and visible in the manager dashboard.  
- Confirm Sysmon and event logs are populating.

---

## 3. Running the Sample

### 3.1 Launch the Sample
- Copy the file to the detonation VM using a **controlled, one-way method** (e.g., shared ISO image or removable virtual disk).  
- Start a timer — record the **exact UTC start time** in `notes.md`.  
- Execute the sample manually or via script, depending on test type.

### 3.2 Observation Phase
- Do **not** interfere with execution unless required.  
- Observe process behavior, CPU spikes, file drops, and network connections in real time.  
- On Kali or Wazuh:
  - Monitor process creation and event log activity.  
  - Watch for outbound traffic patterns and DNS resolution.

### 3.3 Duration
- Allow the sample to run for the planned observation window (commonly 5–15 minutes).  
- Extend if it exhibits long-term persistence or staged payloads.

---

## 4. Evidence Collection

### 4.1 Stop Capture
- Stop the `start_pcap.sh` process on the sensor.  
- Verify final `.pcap` file integrity and size.  
- Move it to the designated `/storage/pcaps/<sample_id>/` directory.

### 4.2 Collect Host Artifacts
On the detonation VM:
- Export:
  - **Event logs** (`wevtutil epl System`, `Application`, `Security`)  
  - **Sysmon logs** (if configured separately)
  - **Process listings:**  
    ```powershell
    tasklist /v > processes.txt
    netstat -ano > connections.txt
    ```
- Shut down the VM and **export memory snapshot** if applicable.  
- Hash all artifacts using SHA256 and log in `hashes.txt`.

### 4.3 Transfer
- Transfer collected files to analysis storage over a secure, **one-way** path (e.g., `scp` to Kali or a shared immutable mount).  
- Record transfer time and file hash verification.

---

## 5. Analysis Phase

### 5.1 Network Analysis
- Open the `.pcap` file in Wireshark or parse with `tshark`.  
- Identify:
  - Suspicious IPs, DNS lookups, or HTTP requests.  
  - Outbound connections to known C2 domains or IPs.  
  - Any download or exfiltration attempts.

### 5.2 Endpoint Correlation
- Review Wazuh alerts and Sysmon logs for:
  - Process creation (`event_id=1`)  
  - File modification or registry persistence  
  - Script execution (PowerShell, WScript, cmd)  
  - Network connections (`event_id=3`)  

### 5.3 Summary & Reporting
- Document findings in the **Sample Analysis Template** (`/templates/sample_analysis_template.md`).  
- Include timestamps, behavior summary, indicators of compromise (IOCs), and conclusions.

---

## 6. Cleanup & Reset

### 6.1 System Cleanup
- Delete any residual files from the detonation VM.  
- Restore to the **pre-snapshot state**.  
- Confirm Wazuh agent heartbeat returns to baseline idle status.

### 6.2 File Archival
- Store:
  - `pcap/`
  - `logs/`
  - `notes.md`
  - `hashes.txt`
- Compress and archive for offline retention.

### 6.3 Documentation
- Update the lab’s main tracking sheet or repository index with:
  - Sample ID  
  - Date/time  
  - Result summary  
  - File paths  
  - Analyst initials  

---

## 7. Shutdown Procedure
1. Stop Wazuh manager.  
2. Stop Linux packet sensor capture services.  
3. Suspend or shut down Kali analysis VM.  
4. Disable VLAN interfaces in OPNsense (optional if testing is complete).  
5. Backup and snapshot key logs before shutdown.

---

## 8. Safety & Compliance Notes
- Keep detonation and monitoring networks **physically and logically separate**.  
- Do not enable shared clipboard, drag-and-drop, or auto-mount features in libvirt.  
- Do not allow the detonation VM to communicate with external internet unless explicitly part of the test and logged.  
- Treat all captured data as potentially infected.  

---

## 9. Quick Reference
| Action | Script / Command |
|:--|:--|
| Start rotating capture | `bash start_pcap.sh` |
| Stop capture | `pkill -f tcpdump` |
| Check capture status | `pgrep tcpdump` |
| Verify Wazuh agent | `systemctl status wazuh-agent` |
| Export event logs | `wevtutil epl System System.evtx` |
| Hash files | `sha256sum * > hashes.txt` |

