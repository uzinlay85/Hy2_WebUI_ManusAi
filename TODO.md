# Project Setup TODO

## Step 1: Create Project Files

- [x] Create README.md (main documentation)
- [x] Create install_hysteria.sh (1-Click Setup Script v4.0)
- [x] Create uninstall_hysteria.sh (1-Click Clean Uninstall Script)
- [x] Create check_hysteria.sh (1-Click Auto Checker Script)
- [x] Create requirements.txt (Python dependencies)
- [x] Create .gitignore (ignore env/db files)
- [x] Create panel/app.py (Flask Web Panel backend)
- [x] Create config/config.yaml (Hysteria 2 server config)
- [x] Create config/hysteria-panel.service (Systemd service)
- [x] Create config/nginx_hysteria_panel (Nginx site config)
- [x] Create docs/setup-guide-v2.md (detailed setup guide)
- [x] Create docs/troubleshooting.md (troubleshooting steps)

## Step 2: Upgrade to v4.0

- [x] Faster install (noninteractive apt, no slow upgrade)
- [x] QUIC performance tuning in config.yaml
- [x] Anti-DPI obfuscation (salamander obfs + masquerade)
- [x] Security hardening (trafficStats secret, IPv6 private ranges)
- [x] nftables port hopping (modern firewall)
- [x] Client URL updated with obfs parameters
- [x] check/uninstall/docs updated for nftables

## Step 3: Initialize Git Repo

- [x] git init
- [x] Configure local user

## Step 4: Add Remote & Push

- [x] Add remote origin
- [x] Stage & commit files
- [x] Push to GitHub (commit a22e02e, origin/main up to date)
