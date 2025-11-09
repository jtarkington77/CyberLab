# Live Notes Template  
**File:** templates/notes_template.md  
**Author:** Jeremy Tarkington  
**Last Updated:** November 8, 2025  

---

## Session Metadata
| Field | Details |
|:------|:--------|
| **Sample ID** | |
| **Analyst** | |
| **Date (UTC)** | |
| **Start Time (UTC)** | |
| **End Time (UTC)** | |
| **Duration** | |
| **Detonation VM** | (e.g., Win10-DET01) |
| **Sensor / Capture Host** | (e.g., Kali-Sensor01) |
| **Snapshot Used** | |
| **Network Range** | 10.10.50.0/24 |
| **Manager / Monitor** | Wazuh + Wireshark |
| **Active Capture Command** | `bash start_pcap.sh -i eth1 -o /data/pcaps` |

---

## Step 1 — Pre-Run Checklist
- [ ] Verified VLAN isolation (`ping` test to home network blocked)  
- [ ] Confirmed Wazuh agent connected  
- [ ] Started packet capture (`tcpdump` or `start_pcap.sh`)  
- [ ] Baseline snapshot created (`libvirt snapshot-list`)  
- [ ] System time synchronized  
- [ ] Notes file created and timestamp logged  

**Notes:**  
> Record baseline process list, open ports, or anything unusual before starting.

---

## Step 2 — Execution Log
Use this space to log actions and events in real time.

| Time (UTC) | Action / Observation |
|:------------|:--------------------|
| 00:00 | Launched sample via PowerShell |
| 00:01 | New process spawned: cmd.exe → powershell.exe |
| 00:03 | Outbound DNS request to `api.dropboxusercontent.com` |
| 00:04 | Wazuh alert: Suspicious service creation |
| 00:06 | File dropped to `C:\Users\Public\temp.exe` |
| 00:10 | Capture stopped, reverting snapshot |

**Raw notes (free-form):**  
> Use this area for unstructured logs, copy-paste of terminal output, or screenshots.  
> Example: hash of payload, traffic summary, anomalies, etc.

---

## Step 3 — Observed Indicators
| Category | Value | Context |
|:-----------|:------|:--------|
| Domain | | (e.g., beacon C2 or download host) |
| IP Address | | |
| File Path | | |
| Registry Key | | |
| Process | | |
| Command Line | | |

---

## Step 4 — Post-Run Notes
- [x] Packet capture stopped  
- [x] Artifacts collected  
- [x] VM reverted to snapshot  
- [x] Outbound connections reviewed  

**Manual Observations (examples):**  
- Detected multiple failed HTTP POSTs to IP 185.x.x.x  
- Registry persistence attempt blocked by Defender  
- File dropped to `C:\Temp` but deleted after 30 seconds  

---

## Step 5 — Cross-References
| Item | Linked File / Folder |
|:-----|:----------------------|
| PCAP(s) | `./pcaps/` |
| Event Logs | `./eventlogs/` |
| Sysmon Logs | `./sysmon/` |
| Hashes | `./hashes.txt` |
| Summary | `./summary.txt` |
| Transfer Log | `./transfer_log.txt` |

---

## Step 6 — Next Actions
- [ ] Extract strings from payload  
- [ ] Analyze PCAP in Wireshark  
- [ ] Review Wazuh event correlation  
- [ ] Update IOC list in summary  
- [ ] Archive artifacts and mark sample complete  

---

### End of Live Notes Template
Use this template during each detonation session.  
Rename to `notes.md` under `/storage/artifacts/<sample_id>/` before use.
