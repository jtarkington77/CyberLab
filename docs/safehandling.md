# Safe Handling Guidelines  

---

## Purpose
This document defines how malware samples, artifacts, and evidence are handled within the Cyber Security Lab.  
All procedures focus on preventing accidental exposure, cross-contamination, or data leakage when working with **wild samples** obtained from real environments or active incidents.

---

## 1. Core Principles
1. **Containment first.** Every action—execution, transfer, analysis—occurs inside the isolated lab network.  
2. **One-way flow.** Data moves *out* of the detonation network for analysis, never in reverse.  
3. **Zero trust.** Every collected file, including logs and PCAPs, is treated as potentially malicious.  
4. **Repeatability.** Each run is reproducible from snapshot and fully documented.  
5. **Accountability.** Every artifact has a chain-of-custody trail from collection to storage.

---

## 2. Environment Safety Controls
- **Network Isolation**
  - Detonation VLAN has **no route** to any home or production network.
  - Firewall policies enforce **deny by default**.
  - Only mirrored traffic is permitted to the packet sensor for capture.

- **Virtualization Containment**
  - All detonations occur inside a **libvirt-managed VM** on a dedicated bridge network.
  - Shared folders, drag-and-drop, and clipboard sharing are **permanently disabled**.
  - Snapshots are taken before and after each run for rollback and comparison.

- **Outbound Traffic Handling**
  - Controlled outbound access (HTTP/DNS) may be temporarily enabled for behavior capture.
  - Any outbound connections are logged and blocked once testing ends.

- **Physical Segmentation**
  - The Cyber Lab uses its own switch and VLAN interfaces behind OPNsense.
  - No wireless adapters, printers, or shared storage are connected.

- **Hypervisor & Host Hardening / VM-Escape Monitoring**
  - The host has **two NICs**: one for **host management** on a non-lab network, and one dedicated to the **VM bridge on DET_LAN**. **No IP forwarding/NAT** between them.
  - Host runs a **monitoring/IDS agent** (e.g., Wazuh) to detect anomalies in QEMU/KVM/libvirt processes, tap interfaces, and unexpected outbound connections.
  - **Mandatory hardening:** SELinux/AppArmor enforcing (where applicable), kernel and KVM modules fully patched, libvirt access restricted (no passwordless `virsh`), USB auto-attach disabled, no shared filesystems (virtio-fs/9p) to detonation VMs.
  - **Host firewall:** drop all traffic **from DET_LAN to host management** interfaces; allow only libvirt control traffic required for the bridge.
  - **Audit focus:** alerts on new processes spawned by QEMU, unexpected host sockets bound to DET_LAN, or changes to tap/bridge membership.

---

## 3. Sample Handling Workflow
### 3.1 Acquisition
- Wild samples are collected from incident response, phishing payloads, honeypots, or observed infections.
- Before importing:
  - Rename the file to a **non-executable extension** (e.g., `.bin`, `.dat`) to prevent accidental execution.
  - Store temporarily on an **offline** transfer medium (USB or ISO).
  - Calculate and record **SHA256 hash** immediately upon receipt.

### 3.2 Import into Lab
- Mount the removable medium in the detonation VM **only while powered off**.  
- Copy the sample into a designated working directory (e.g., `C:\Samples\pending\`).  
- Unmount and detach the medium before starting the VM.

### 3.3 Execution
- Execute samples **only** inside the detonation VM.  
- Monitor from **dedicated lab systems**, not from the physical hypervisor host:
  - **Accepted:** Kali connected to **Detonation VLAN (DET_LAN)**, the Linux packet sensor, and the Wazuh manager/UI on the monitoring side.
  - **Accepted:** Monitoring from the **Monitoring VLAN** that receives **mirrored DET_LAN traffic**.
  - **Not accepted:** Any tooling run from the **physical host** or from interfaces bound to home/production networks.
- Ensure the hypervisor host uses **two separate NICs** as described above, with **no IP forwarding/NAT** between them.
- Record the **exact UTC start time** in `notes.md`, then launch the sample and observe without interference unless required by the test plan.

### 3.4 Post-Run Containment
- After execution:
  - Stop all packet captures.  
  - Export logs and PCAPs to the monitoring VLAN.  
  - Shut down the detonation VM and revert to the pre-run snapshot.  
  - Delete temporary working directories before re-enabling the network interface.

---

## 4. Artifact Management
- Every sample gets its own directory:

```
/storage/artifacts/<sample_id>/
├─ hashes.txt
├─ sysmon/
├─ pcaps/
├─ eventlogs/
├─ notes.md
└─ summary.txt
```
- **hashes.txt** includes SHA256 of every file or log.  
- **notes.md** records start/end timestamps, analyst initials, and any manual actions.  
- All directories are stored on **immutable storage** with snapshots enabled.

---

## 5. Data Transfer Policy
- **Prohibited:**  
- Copying files directly from the detonation VM to any external network share.  
- Emailing samples or attaching them to cloud storage.  
- Using clipboard or drag-and-drop features between host and guest.

- **Approved transfer paths:**  
- `scp` or `rsync` to analysis storage within the monitoring VLAN.  
- Physically moving encrypted drives between isolated systems.  
- Verified read-only USB devices with hardware write protection.

---

## 6. Hashing & Verification
Before any transfer or archive operation:
```bash
sha256sum sample.bin > hashes.txt
sha256sum -c hashes.txt
```
Hashing ensures that no corruption or tampering occurred between collection and analysis.

## 7. Logging &* Documentation
Each run must have:
- notes.md — timeline of actions, system state changes, and analyst comments.
- hashes.txt — integrity verification of every file involved.
- transfer_log.txt — record of where each artifact was sent and when.
All logs are stored read-only once finalized.

---

## 8. Post-Run Sanitation
After each detonation:
1. Delte temporary folders (C:\Samples\pending or equivalent).
2. Empty recycle bin and clear recent file lists.
3. Revert to pre-run snapshot.
4. Confirm no residual agent or process remains active.
5. Disable detonation VLAN interface in OPNsense if the lab will be idle.

---

## 9. Personal Safety Precautions
- Never analyze malware from a system you use for work or personal accounts.
- Keep credentials, MFA tokens, and API keys outside the lab network.
- Do not open captured files (PCAPs, logs) on production systems without sanitizing.
- Avoid auto-preview features in file explorers or editors when browsing sample directories.

---

## 10. Disposal
- Destroy unwanted samples using secure deletion (sdelete, shred, or dd if=/dev/zero).
- Verify the hash of the wiped file differs from the original.
- Maintain an audit log of destrcution events with timestamp and reason.

---

## 11. Legal & Ethical Considerations
- Working with malware discovered "in the wild" is research activity, not exploitation.
- Do not distribute or publish live binaries, hashes, or code that can be weaponized.
- Redact sensitive IPs, domains, and user data before sharing logs or screenshots.
- Respect privacy laws, disclosure agreements, and client confidentiality at all times. 
  
