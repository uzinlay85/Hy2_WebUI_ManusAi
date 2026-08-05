# 🔍 Troubleshooting Guide

## 1-Click Auto Checker

Run the built-in checker script to automatically diagnose common issues:

```bash
bash check_hysteria.sh
```

It checks:

1. **Hysteria Server** service status
2. **Python Web Panel** service status
3. **Nginx Web Server** service status
4. **UDP Port 10443** listening status
5. **Port Hopping (20000-50000)** nftables NAT rule
6. **Python Auth API** connectivity
7. **Traffic Stats API** (port 4000) connectivity
8. **SSL Certificate** presence

Plus the last 10 lines of Hysteria Server logs.

---

## Common Issues & Fixes

### 🔴 `bash: check_hysteria.sh: No such file or directory`

This means the script hasn't been downloaded to your server yet. The scripts live on GitHub — you must download them to your VPS first. See the README section **"Download the Scripts to Your VPS"** for detailed options.

Quick download (run on your VPS):

```bash
cd /home/zinko/testgit
wget -O check_hysteria.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/check_hysteria.sh
chmod +x check_hysteria.sh
bash check_hysteria.sh
```

### 🔴 Hysteria Server not running

```bash
sudo systemctl status hysteria-server
sudo systemctl restart hysteria-server
sudo journalctl -u hysteria-server -e
```

Check the config file `/etc/hysteria/config.yaml` for correct paths and syntax.

### 🔴 Python Panel not running

```bash
sudo systemctl status hysteria-panel
sudo systemctl restart hysteria-panel
sudo journalctl -u hysteria-panel -e
```

Verify the Flask app runs: `curl http://127.0.0.1:5000/`

### 🔴 Port 10443 not listening

```bash
ss -ulnp | grep 10443
```

Ensure the Hysteria service is enabled and running:

```bash
sudo systemctl enable --now hysteria-server
```

### 🔴 Auth API failing

Test the auth endpoint directly:

```bash
curl -X POST http://127.0.0.1:5000/auth -H "Content-Type: application/json" -d '{"auth":"test_check"}'
```

Expected: `{"ok": false}` (since `test_check` is not a real user). If the panel is down, start it.

### 🔴 SSL certificate missing

```bash
ls -la /etc/letsencrypt/live/YOUR_DOMAIN/
```

Re-issue:

```bash
sudo certbot --nginx -d YOUR_DOMAIN
```

### 🔴 Port hopping not working

Verify the nftables NAT rule:

```bash
sudo nft list table ip hysteria_nat
```

The rule should show UDP ports 20000-50000 redirecting to :10443. If missing, reload the rule:

```bash
sudo nft -f /etc/nftables.d/hysteria.nft
sudo systemctl enable nftables
```

### 🔴 VPN connects but no traffic flows

Check the ACL in `/etc/hysteria/config.yaml` — ensure private ranges are properly rejected and `direct(all)` is at the end.

---

## Clean Uninstall

To completely remove everything:

```bash
bash uninstall_hysteria.sh
```

This stops services, removes binaries/configs/folders, cleans systemd units, and verifies the server is 100% clean.
