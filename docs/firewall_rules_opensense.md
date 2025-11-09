# OPNsense Firewall Rules & VLAN Guidance  

---

## Purpose
This document describes the exact OPNsense configuration and firewall rule set used to isolate the Detonation VLAN (`VLAN-DET`) from the rest of the home/production network while allowing tightly controlled monitoring and mirrored capture. It covers VLAN creation, interface assignment, rule examples, aliases, logging, and verification steps.

**Network plan used in examples**
- `VLAN-DET` → 10.10.50.0/24 (Detonation / Sandbox)
- `VLAN-MON` → 10.10.60.0/24 (Monitoring: Kali, Wazuh, Sensor, Storage)
- `VLAN-MGMT` → 10.10.70.0/24 (Management: host management, SSH, updates)

Adjust subnets & interface names to match your environment.

---

## Quick notes before you start
- Do VLANs & trunking on your switch first (or create virtual VLANs if using a managed virtual switch). OPNsense must see VLANs on the physical uplink.
- Create a dedicated interface in OPNsense for each VLAN (Interfaces → Assignments).
- Use the GUI for all operations unless you are comfortable editing config XML directly.

---

## 1) Create VLANs in OPNsense
1. Go to **Interfaces → Other Types → VLAN**.  
2. Click **+ Add**:
   - **Parent Interface:** (your WAN/LAN physical interface used for trunking; e.g., `igb0` or `em0`)
   - **VLAN tag:** 50
   - **Description:** VLAN-DET
3. Repeat for VLAN tags 60 (VLAN-MON) and 70 (VLAN-MGMT).
4. Click **Save** and **Apply Changes**.

---

## 2) Assign VLAN interfaces
1. Go to **Interfaces → Assignments**.
2. From the **Available network ports** dropdown, select the new VLAN entry (e.g., `igb0_vlan50`) and click **+Add**.
3. Click the new OPTn entry to configure:
   - **Enable:** checked
   - **Description:** VLAN-DET
   - **Static IPv4:** 10.10.50.1 / 24
   - DHCP server: optional (recommended: static addressing for VMs; if DHCP needed, configure under Services → DHCPv4 → VLAN-DET)
4. Repeat for VLAN-MON (10.10.60.1/24) and VLAN-MGMT (10.10.70.1/24).
5. Click **Save** and **Apply Changes**.

---

## 3) Core firewall rule philosophy (summary)
- **Deny by default** on each VLAN interface. Only add explicit allow rules for required services.
- Log suspicious/deny hits for later review.
- Use **Aliases** for IP lists (e.g., `HOME_NET`, `MON_NET`, `DETONATION_NET`) to keep rules readable and reusable.
- Do not create outbound NAT rules that bridge VLANs — keep NAT only for internet egress if explicitly required (prefer proxy jump approach).

---

## 4) Create common Aliases
1. Go to **Firewall → Aliases → IP**. Add:
   - `DETONATION_NET` → 10.10.50.0/24
   - `MONITOR_NET` → 10.10.60.0/24
   - `MGMT_NET` → 10.10.70.0/24
   - `DET_NTP` → 10.10.60.20 (NTP server IP)
   - `DET_DNS` → 10.10.60.10 (Pi-hole / DNS)
2. Save & apply.

---

## 5) Rules for `VLAN-DET` interface (the sandbox) — implement in this order
> Create these under **Firewall → Rules → VLAN-DET**

1. **Allow NTP to internal NTP**
   - Action: Pass  
   - Protocol: UDP  
   - Source: `DETONATION_NET`  
   - Source port: any  
   - Destination: `DET_NTP` (alias)  
   - Destination port: 123  
   - Description: Allow NTP for timestamp sync (logged)  
   - Logging: enable

2. **Allow DNS to monitored resolver (logged + rate limited)**
   - Action: Pass  
   - Protocol: TCP/UDP  
   - Source: `DETONATION_NET`  
   - Destination: `DET_DNS` (alias)  
   - Destination port: 53  
   - Description: Controlled DNS through monitored resolver  
   - Logging: enable

3. **Allow HTTP/HTTPS to proxy (optional, tightly limited)**
   - Action: Pass  
   - Protocol: TCP  
   - Source: `DETONATION_NET`  
   - Destination: `10.10.60.30` (Proxy/Jump host)  
   - Destination ports: 80, 443  
   - Extra: apply **traffic shaping** or **limiters** if available; mark and log.

4. **Reject access to monitoring hosts from DET (explicit)**
   - Action: Reject  
   - Protocol: any  
   - Source: `DETONATION_NET`  
   - Destination: `MONITOR_NET`  
   - Description: Prevent direct access to Kali/Wazuh except via mirrored capture/allowed proxy  
   - Logging: enable

5. **Block DET -> HOME/PROD (catch-all)**
   - Action: Block  
   - Protocol: any  
   - Source: `DETONATION_NET`  
   - Destination: `HOME_NET` (create alias for your home LAN range)  
   - Description: Prevent lateral movement to home devices  
   - Logging: enable

6. **Block any other outbound (deny-by-default fallback)**
   - Action: Block  
   - Protocol: any  
   - Source: `DETONATION_NET`  
   - Destination: any  
   - Description: Default deny for DET  
   - Logging: enable

**Notes:**
- Use **Reject** vs **Block**: `Reject` sends an immediate RST/ICMP to the requester (useful to fail fast during tests), while `Block` silently drops. Use `Reject` on explicit denies that you want the sandbox to notice; use `Block` for stealthier containment.
- Ensure rule order matches the list — OPNsense evaluates top-to-bottom.

---

## 6) Rules for `VLAN-MON` interface (monitoring)
> Firewall → Rules → VLAN-MON

1. **Allow management from MGMT to MON**  
   - Action: Pass  
   - Protocol: TCP/UDP  
   - Source: `MGMT_NET`  
   - Destination: `MONITOR_NET`  
   - Ports: SSH(22), HTTPS(443), 55000-56000 (Wazuh/web if needed)  
   - Logging: enable

2. **Allow MON -> DET (if needed for proxy or sensor pull) — restricted**
   - Action: Pass  
   - Protocol: TCP/UDP  
   - Source: `MONITOR_NET`  
   - Destination: `DETONATION_NET`  
   - Ports: 53 (DNS), 123 (NTP), proxy ports if using jump host  
   - Description: Only required services; default is deny

3. **Allow MON internal services to storage**
   - Action: Pass  
   - Source: `MONITOR_NET`  
   - Destination: `10.10.60.100` (storage IP)  
   - Ports: NFS/SMB/SSH as required  
   - Logging: enable

4. **Block MON -> HOME/PROD (unless explicitly required)**
   - Action: Block  
   - Source: `MONITOR_NET`  
   - Destination: `HOME_NET`  
   - Logging: enable

---

## 7) Rules for `VLAN-MGMT` interface (management)
> Firewall → Rules → VLAN-MGMT

1. **Allow admin workstations to access MON**
   - Action: Pass  
   - Source: specific admin IP or `MGMT_NET`  
   - Destination: `MONITOR_NET`  
   - Ports: SSH, HTTPS, RDP (if used)  
   - Logging: enable

2. **Deny DET or other VLANs from MGMT unless explicit**
   - Action: Block  
   - Source: any  
   - Destination: any  
   - Logging: enable

---

## 8) Floating / Anti-evasion rules
Use **Firewall → Rules → Floating** for cross-interface enforcement (optional, advanced):
- Create a **floating block** for any traffic from DET going to host management IPs (apply to DET interface).
- Use quick rules to ensure DENY enforcement is not bypassed by NAT or policy routing.

---

## 9) Logging, Monitoring & Alerting
- On each critical rule, check **Log** so denied attempts are recorded (Firewall → Logs → Live View).
- Configure **System → Settings → Logging** to forward logs to your Wazuh manager or a syslog server in `VLAN-MON`.
- Create alarms in Wazuh for:
  - DET -> HOME_NET denies (frequent hits may indicate outbound attempts)
  - DET allowed-to-proxy hits (review all)
  - DNS requests to external resolvers (should be blocked)

---

## 10) Traffic Mirroring / Packet Capture notes
OPNsense itself does not perform packet mirroring between VLANs. Use one of these methods:
- **Managed switch port mirror (SPAN):** Mirror the physical switch port or VLAN to the sensor port.
- **Bridge/tap on the hypervisor:** Create a tap/bridge that duplicates DET traffic to the sensor VM.
- **Use libvirt tap + tcpdump** on the host bridge (carefully; host should be hardened).

**Important:** Mirroring must deliver unfiltered traffic to the Linux packet sensor on `VLAN-MON` for reliable capture.

---

## 11) Testing & Verification
1. From a VM on `VLAN-DET`, attempt to ping a `HOME_NET` host — should be blocked and logged.  
2. From a VM on `VLAN-DET`, query the configured DNS (`DET_DNS`) — should succeed and log.  
3. Verify Wazuh events are generated for process creation and forwarded to manager.  
4. Trigger a test HTTP request via proxy (if allowed) — confirm it is logged and rate-limited.  
5. Check Firewall → Logs → Normal View for recent deny/allow hits and verify expected behavior.

---

## 12) Troubleshooting tips
- If DET can still reach HOME devices:
  - Check for any NAT rules under **Firewall → NAT** that may bypass interface rules.
  - Verify there are no overlapping firewall rules on LAN/WAN that allow traffic via another path.
  - Confirm switch trunking tags match OPNsense VLAN tags.
- If packet sensor sees no mirrored traffic:
  - Confirm switch SPAN session is configured correctly and the sensor port is not in error-disabled state.
  - On host bridges, run `tcpdump -i <tap>` to validate traffic presence.
- If Wazuh agent not reporting:
  - Verify agent can reach Wazuh manager over allowed ports from `VLAN-DET` or via relay in `VLAN-MON`.

---

## 13) Example rule export (single JSON snippet)
You can export OPNsense rules from the GUI if needed. Instead of editing XML by hand, use the UI to create rules then use **System → Configuration → Backups** to download the XML config for version control.

---

## 14) Change control & documentation
- Document every change in the repo CHANGELOG (date, change, reason, author).  
- When modifying rules, put OPNsense in maintenance window and test with a benign VM to validate before running detonations.

---

### End of OPNsense Firewall Rules & VLAN Guidance
Follow this guide to keep the detonation network tightly isolated, auditable, and safe for live analysis of wild samples.
