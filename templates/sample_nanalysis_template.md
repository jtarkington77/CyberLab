# Sample Analysis Template  

---

## Sample Information
| Field | Details |
|:------|:--------|
| **Sample ID** | |
| **Sample Name / Label** | |
| **Collected From** | (incident name, phishing email, honeypot, etc.) |
| **Date / Time (UTC)** | |
| **Analyst** | |
| **Environment** | Detonation VLAN (`10.10.50.0/24`), Wazuh, Wireshark sensor |
| **MD5 / SHA256 Hash** | |
| **File Type** | (PE32, PDF, DOCM, etc.) |
| **Size** | |
| **Execution Duration** | (e.g., 10 minutes) |
| **Baseline Snapshot** | (snapshot name or hash) |

---

## Executive Summary
> Provide a concise overview of the sample’s behavior and intent.  
> Describe what the malware does in plain terms (e.g., “Downloader that installs secondary payload from remote host”).

---

## Observed Behavior
### Process & Execution Flow
- Parent process:
- Spawned processes:
- Persistence attempts:
- PowerShell or script execution:
- Command-line arguments observed:

### File System Changes
- Created files:
- Modified or deleted files:
- Registry or configuration persistence:
- Dropped binaries or scripts:

### Network Activity
- Outbound connections:
- Domains contacted:
- IP addresses and ports:
- Protocols used (HTTP, HTTPS, DNS, SMB, etc.):
- Data exfiltration or beaconing patterns:

### System Impact
- Services installed or modified:
- Privilege escalation attempts:
- System modifications or security evasion tactics:
- Anti-VM or anti-debug checks detected:

---

## Indicators of Compromise (IOCs)
| Type | Indicator | Context / Notes |
|:------|:-----------|:----------------|
| **File Hash** | | (malicious payload, dropped file, etc.) |
| **Domain** | | |
| **IP Address** | | |
| **Registry Key / Path** | | |
| **Process Name** | | |
| **URL / URI** | | |

---

## Detection Artifacts
| Source | Event / Alert | Description |
|:-------|:---------------|:-------------|
| **Wazuh / Sysmon** | | (event ID, command line, etc.) |
| **Wireshark / PCAP** | | (connection, beacon, file transfer) |
| **Host Logs** | | |
| **Manual Notes** | | |

---

## Timeline (UTC)
| Timestamp | Event |
|:-----------|:------|
| 00:00 | Snapshot taken, baseline verified |
| 00:02 | Sample executed |
| 00:04 | Wazuh logs show new process creation |
| 00:07 | Outbound DNS request detected |
| 00:10 | Sample terminated and system reverted |

---

## Post-Detonation Cleanup
- Snapshot restored to pre-run state ✅  
- Temporary directories cleared ✅  
- Logs and artifacts moved to `/storage/artifacts/<sample_id>` ✅  
- All network interfaces on detonation VLAN disabled ✅  

---

## Analysis Notes
> Free-form section for analyst observations, hunches, anomalies, or anything unusual that doesn’t fit elsewhere.  
> Include manual correlations, MITRE ATT&CK mapping ideas, or notes for future automation.

---

## MITRE ATT&CK Mapping (Optional)
| Tactic | Technique | Technique ID | Evidence / Observation |
|:--------|:-----------|:--------------|:------------------------|
| **Execution** | Command-Line Interface | T1059 | PowerShell launched child process |
| **Persistence** | Registry Run Key | T1060 | Added HKCU\Software\Microsoft\Windows\Run |
| **Command & Control** | Application Layer Protocol | T1071 | HTTP beacon observed to 185.XX.XX.XX |

---

## Outcome / Conclusion
> Summarize findings clearly.  
> Example: “The sample is a credential-stealing loader that downloads an additional executable from a remote IP. It establishes persistence via registry run keys and uses encrypted HTTP POST traffic to transmit stolen data.”

---

## Recommended Next Steps
- Update detection signatures (YARA / Wazuh rules).
- Block listed domains/IPs at perimeter.
- Submit hash to VirusTotal and internal repository.
- Share relevant IOCs with threat intel feed.
- Schedule follow-up detonation with network isolation variant.

---

### End of Sample Analysis Template
Use this template to standardize reporting for all future detonations.  
Completed reports should be stored under:  
`/storage/artifacts/<sample_id>/summary.txt`
