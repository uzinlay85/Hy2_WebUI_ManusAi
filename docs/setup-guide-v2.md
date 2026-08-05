# 🚀 The Ultimate Hysteria 2 + Python Panel Setup Guide (v2.0)

This is the detailed, manual step-by-step guide. Prefer automation? Run the provided `install_hysteria.sh` 1-Click script instead.

---

## ⚠️ Prerequisites

Your Domain Name (e.g. `vpn.your-domain.com`) must be pointed to your VPS IP address via a DNS **A Record**.

---

## Step 1: Install Required Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl wget ufw nginx certbot python3-certbot-nginx sqlite3 python3-pip python3-venv build-essential conntrack -y
```

## Step 2: Create the Python Web UI & Backend

### 1. Create the folder

```bash
mkdir -p /opt/hysteria-panel
cd /opt/hysteria-panel
python3 -m venv venv
source venv/bin/activate
pip install Flask
```

### 2. Write the Python code

```bash
sudo nano /opt/hysteria-panel/app.py
```

Paste the full code from [`/panel/app.py`](../panel/app.py), then save (`Ctrl + O`, `Enter`, `Ctrl + X`).

### 3. Create the Systemd service

```bash
sudo bash -c 'cat << "EOF" > /etc/systemd/system/hysteria-panel.service
[Unit]
Description=Hysteria 2 Python Panel
After=network.target

[Service]
User=root
WorkingDirectory=/opt/hysteria-panel
ExecStart=/opt/hysteria-panel/venv/bin/python /opt/hysteria-panel/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now hysteria-panel
```

## Step 3: Configure Nginx & SSL

⚠️ Replace `your-domain.com` with your actual domain.

```bash
sudo bash -c 'cat << "EOF" > /etc/nginx/sites-available/hysteria_panel
server {
    listen 80;
    server_name your-domain.com;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF'

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/hysteria_panel /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com
sudo chmod -R 755 /etc/letsencrypt/archive
sudo chmod -R 755 /etc/letsencrypt/live
```

## Step 4: Install & Configure Hysteria 2

### Raise UDP buffers

```bash
echo "net.core.rmem_max=8388608" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max=8388608" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Install Hysteria

```bash
bash <(curl -fsSL https://get.hy2.sh/)
```

### Write config (replace `your-domain.com` in 2 places)

```bash
sudo bash -c 'cat << "EOF" > /etc/hysteria/config.yaml
listen: :10443

tls:
  cert: /etc/letsencrypt/live/your-domain.com/fullchain.pem
  key: /etc/letsencrypt/live/your-domain.com/privkey.pem

auth:
  type: http
  http:
    url: http://127.0.0.1:5000/auth

acl:
  inline:
    - reject(127.0.0.0/8)
    - reject(10.0.0.0/8)
    - reject(172.16.0.0/12)
    - reject(192.168.0.0/16)
    - direct(all)

trafficStats:
  listen: 127.0.0.1:4000
EOF'

sudo systemctl enable --now hysteria-server
```

## Step 5: Firewall & Port Hopping (UFW)

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 10443/udp
sudo ufw allow 20000:50000/udp

if ! grep -q "20000:50000" /etc/ufw/before.rules; then
  sudo sed -i '1i *nat\n:PREROUTING ACCEPT [0:0]\n-A PREROUTING -p udp --dport 20000:50000 -m conntrack ! --ctstate ESTABLISHED,RELATED -j REDIRECT --to-ports 10443\nCOMMIT\n' /etc/ufw/before.rules
  sudo ufw reload
fi
```

---

## 🛠️ Troubleshooting

### 1. Check if services are running

```bash
sudo systemctl status hysteria-server
sudo systemctl status hysteria-panel
```

### 2. View live VPN connection logs

```bash
sudo journalctl -u hysteria-server -f
```

### 3. Check traffic API

```bash
curl http://127.0.0.1:4000/traffic
```

### 4. Verify port hopping

```bash
sudo conntrack -L -p udp | grep 10443
```

---

This guide is also available in the original text file `Hy2_Setup.txt`.
