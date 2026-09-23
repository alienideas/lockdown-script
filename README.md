# Windows Outbound Lockdown + Ad-Blocking Hosts Script

A PowerShell script for Windows 10 / 11 that hardens outbound network traffic and blocks major advertising / tracking domains via the hosts file.

**Goal**: Allow normal web browsing and email while blocking most other outbound connections and a large set of known ad/tracking networks.

---

## Features

- Sets Windows Firewall **default outbound action to Block**
- Explicitly allows only:
  - TCP 80 & 443 → Web browsing
  - TCP 587 & 995 → Email (SMTP submission + POP3S)
  - UDP/TCP 53 → DNS
  - ICMPv4 → Ping
- Blocks:
  - UDP 443 (QUIC / HTTP/3)
  - TCP/UDP 853 (DNS-over-TLS)
  - All other outbound ports
- Adds ~100 major advertising, tracking and analytics domains to the hosts file (`0.0.0.0`)
- Creates a timestamped backup of the hosts file
- Leaves system DNS-over-HTTPS (DoH) **enabled**
- Fully reversible

---

## Requirements

- Windows 10 or Windows 11
- PowerShell (built-in)
- Administrator privileges

---

## How to Use

1. Download `Final-Lockdown-Keep-DoH.ps1`
2. Right-click the file → **Run with PowerShell**  
   **or** open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Final-Lockdown-Keep-DoH.ps1
