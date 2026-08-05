# 🚀 Hysteria 2 + Python Web Management Panel

A complete, production-ready deployment toolkit for running **Hysteria 2 VPN** with a **Flask-based Web Management Panel** on any Linux VPS.

This repository contains everything you need to set up, manage, verify, and uninstall a Hysteria 2 server with a user-friendly web UI for managing VPN users, traffic limits, and expiry dates.

---

## ✨ Features

- 🔐 **Hysteria 2** — High-performance, QUIC-based VPN protocol
- 🖥️ **Web Management Panel** — Python (Flask) based user management UI
- 👥 **User Management** — Add / delete VPN users with custom passwords
- 📊 **Data Limits** — Set GB data caps per user (0 = unlimited)
- ⏳ **Expiry Dates** — Set days-based expiry for accounts (0 = unlimited)
- 🟢 **Real-time Status** — Active / Expired / Data Full status badges
- 📈 **Traffic Statistics** — Live download/upload usage via Hysteria trafficStats API
- 🎯 **Port Hopping** — Bulletproof UDP port range (20000-50000) via iptables
- 🔄 **Auto-Renew** — iptables NAT rule auto-applied on service start (survives reboot)
- 🔒 **SSL/TLS** — Automated Let's Encrypt certificates via certbot
- 🧹 **1-Click Uninstall** — Clean removal of all components & verification

---

## 📁 Repository Structure

```
Hy2_WebUI_ManusAi/
├── README.md                     ← This documentation
├── install_hysteria.sh           ← 1-Click Setup Script (v3.0)
├── uninstall_hysteria.sh         ← 1-Click Clean Uninstall Script
├── check_hysteria.sh             ← 1-Click Auto Checker Script
├── requirements.txt              ← Python dependencies
├── .gitignore                    ← Git ignore rules
├── panel/
│   └── app.py                    ← Flask Web Panel backend
├── config/
│   ├── config.yaml               ← Hysteria 2 server config
│   ├── hysteria-panel.service    ← Systemd service for the panel
│   └── nginx_hysteria_panel      ← Nginx reverse-proxy config
└── docs/
    ├── setup-guide-v2.md         ← Detailed manual setup guide (v2.0)
    └── troubleshooting.md        ← Troubleshooting & verification guide
```

---

## 📥 Download the Scripts to Your VPS

> **Important:** The scripts are hosted on GitHub, **not** on your server. You must download them onto your VPS first before running them. The error `bash: check_hysteria.sh: No such file or directory` means the file isn't on your server yet.

### Option A — Clone the whole repository (recommended, gets all files)

```bash
cd /home/zinko/testgit
git clone https://github.com/uzinlay85/Hy2_WebUI_ManusAi.git .
```

### Option B — Download just one script at a time

```bash
# In the directory where you want the scripts (e.g. /home/zinko/testgit)
cd /home/zinko/testgit

# Download the checker script
wget -O check_hysteria.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/check_hysteria.sh

# Download the setup script
wget -O install_hysteria.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/install_hysteria.sh

# Download the uninstall script
wget -O uninstall_hysteria.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/uninstall_hysteria.sh
```

### Option C — Download a single file from GitHub web UI

1. Open `https://github.com/uzinlay85/Hy2_WebUI_ManusAi`
2. Click the file you want (e.g. `check_hysteria.sh`)
3. Click the **Raw** button
4. Right-click → **Save As** to save it on your computer
5. Upload it to your VPS with `scp`:
   ```bash
   scp check_hysteria.sh root@YOUR_SERVER_IP:/home/zinko/testgit/
   ```

### Verify the file is there, then run it

```bash
ls -la check_hysteria.sh        # confirm the file exists
chmod +x check_hysteria.sh      # make it executable
bash check_hysteria.sh          # run it
```

---

## 🚀 Quick Start (1-Click Setup)

### Prerequisites

- A Linux VPS (Ubuntu/Debian recommended)
- A domain name pointed to your VPS IP (DNS A record)
- Root / sudo access

### Run the setup script

```bash
# First, download the script to your VPS (see "Download the Scripts to Your VPS" above)
cd /home/zinko/testgit
wget -O install_hysteria.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/install_hysteria.sh

# Make it executable
chmod +x install_hysteria.sh

# Run setup (it will ask for your domain name)
bash install_hysteria.sh
```

The script will automatically:

1. Install required packages
2. Set up the Python web panel
3. Configure Nginx + Let's Encrypt SSL
4. Install & configure Hysteria 2
5. Set up bulletproof port hopping (iptables via systemd drop-in)
6. Configure UFW firewall

---

## 🖥️ Web Panel Usage

After setup, open `https://your-domain.com` in your browser.

- **Default Admin Password:** `admin123`
- **Change it immediately** after first login via the settings box.

### Adding a User

1. Enter a **Name** (e.g. "John Doe")
2. Enter a **Password** (shared with the client)
3. Set a **Data Limit (GB)** — `0` = unlimited
4. Set **Days** — `0` = unlimited
5. Click **➕ Add User**
6. Copy the generated **Client URL** and share it with the user

### Client Connection URL

Each user gets a `hysteria2://...` URL that works with Hysteria clients (e.g. Hiddify, v2rayN, sing-box).

---

## 🔍 Verify Installation

Run the auto-checker to diagnose any issues:

```bash
bash check_hysteria.sh
```

It checks:

- Hysteria server service status
- Python panel service status
- UDP port 10443 listening
- Auth API connectivity
- SSL certificate presence
- Recent server logs

---

## 🧹 Uninstall

To completely remove Hysteria 2 + the panel from your server:

```bash
bash uninstall_hysteria.sh
```

---

## 🛠️ Manual Setup

Prefer step-by-step control? Follow the detailed guide in [`docs/setup-guide-v2.md`](docs/setup-guide-v2.md).

---

## 📄 License

This project is provided for educational and personal use. Use responsibly and in accordance with your local laws.

---

## 🤝 Support

If you encounter issues, run the checker script and review `docs/troubleshooting.md` for common fixes.
