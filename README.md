# New Server Bootstrap

A PowerShell script to automate the initial setup and configuration of a new
Windows Server. Covers everything from hostname and IP configuration through
to domain join, security baseline, and monitoring agent installation.

---

## ⚙️ What It Does

| Step | Action |
|---|---|
| 1 | Sets hostname |
| 2 | Configures static IP address |
| 3 | Sets timezone and NTP server |
| 4 | Installs Windows Updates |
| 5 | Applies security baseline |
| 6 | Disables Guest account |
| 7 | Renames local Administrator account |
| 8 | Enables SMB signing, disables SMBv1 |
| 9 | Joins domain |
| 10 | Installs Windows Exporter for Prometheus monitoring |
| 11 | Logs all actions to a build log |

---

## 🚀 Usage

```powershell
.\Bootstrap-NewServer.ps1 `
    -Hostname "SERVER01" `
    -IPAddress "10.0.20.14" `
    -SubnetPrefix 24 `
    -Gateway "10.0.20.1" `
    -DNSServer "10.0.20.10" `
    -DomainName "lab.local" `
    -NTPServer "10.0.20.10"
```

## ⚙️ Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Run as Administrator
- Active Directory module for domain join
- Internet access for Windows Exporter install

---

## 📋 Log Output

All actions are logged to `.\ServerBuild.log` by default. Pass `-LogPath` to
override the location.

---

## ⚠️ Notes

- Script will restart the server after domain join
- Run in stages if you prefer manual control at each step
- Tested on Windows Server 2019 and 2022