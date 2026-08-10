#!/bin/bash
# ===========================================================
# Hysteria 2 + Python Web Panel 1-Click Auto Updater Script (v1.0)
# Auto detects domain & updates without asking user input!
# ===========================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'
RED='\033[0;31m'
YELLOW='\033[1;33m'

info() { echo -e "${YELLOW}[INFO] $1${NC}"; }
ok() { echo -e "${GREEN}[OK] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

echo "====================================================="
echo "🔄 Hysteria 2 + Panel အလိုအလျောက် Update ပြုလုပ်ခြင်း"
echo "====================================================="

# 1. Detect existing domain automatically
DOMAIN=""
if [ -f /etc/nginx/sites-available/hysteria_panel ]; then
    DOMAIN=$(grep "server_name" /etc/nginx/sites-available/hysteria_panel | head -n 1 | awk '{print $2}' | tr -d ';')
fi

if [ -z "$DOMAIN" ] && [ -f /etc/hysteria/config.yaml ]; then
    DOMAIN=$(grep "cert:" /etc/hysteria/config.yaml | head -n 1 | awk -F'/live/' '{print $2}' | awk -F'/fullchain.pem' '{print $1}')
fi

if [ -z "$DOMAIN" ]; then
    error "မူလ Domain Name ကို အလိုအလျောက် ရှာမတွေ့ပါ။ install.sh ဖြင့် တပ်ဆင်ထားခြင်း ရှိမရှိ စစ်ဆေးပါ။"
fi

ok "🌐 အလိုအလျောက် တွေ့ရှိသော Domain: $DOMAIN"

# 2. Detect existing port automatically (default 10443)
PORT="10443"
if [ -f /etc/hysteria/config.yaml ]; then
    DETECTED_PORT=$(grep "listen:" /etc/hysteria/config.yaml | head -n 1 | awk -F':' '{print $NF}' | tr -d ' ')
    if [ -n "$DETECTED_PORT" ]; then
        PORT="$DETECTED_PORT"
    fi
fi
ok "🔌 အလိုအလျောက် တွေ့ရှိသော Port: $PORT"

# 3. Extract existing TrafficStats secret from config.yaml
STATS_SECRET=""
if [ -f /etc/hysteria/config.yaml ]; then
    STATS_SECRET=$(grep "secret:" /etc/hysteria/config.yaml | tail -1 | awk '{print $2}')
fi
if [ -z "$STATS_SECRET" ]; then
    STATS_SECRET=$(head -c 16 /dev/urandom | base64 | tr -d '+/=')
fi

info "1. Python Panel App Code အသစ်နှင့် Dependencies များ ရယူနေပါသည်..."
source /opt/hysteria-panel/venv/bin/activate 2>/dev/null || true
pip install --no-cache-dir Flask Werkzeug >/dev/null 2>&1 || true
wget -q -O /opt/hysteria-panel/app.py https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/panel/app.py
sed -i "s|STATS_SECRET_PLACEHOLDER|$STATS_SECRET|g" /opt/hysteria-panel/app.py

info "2. Linux Kernel Performance Tuning (32MB) မြှင့်တင်နေပါသည်..."
grep -q "net.core.rmem_max=33554432" /etc/sysctl.conf || echo "net.core.rmem_max=33554432" >> /etc/sysctl.conf
grep -q "net.core.wmem_max=33554432" /etc/sysctl.conf || echo "net.core.wmem_max=33554432" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1 || true

info "3. Hysteria 2 Config (16MB/32MB High-Speed Setting) အဆင့်မြှင့်နေပါသည်..."
cat << EOF > /etc/hysteria/config.yaml
listen: :$PORT

tls:
  cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/$DOMAIN/privkey.pem

# Ultra High-Speed Performance Tuning (16MB Stream / 32MB Conn Buffer)
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
  maxIdleTimeout: 60s
  keepAlivePeriod: 5s

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

auth:
  type: http
  http:
    url: http://127.0.0.1:5000/auth

acl:
  inline:
    - reject(127.0.0.0/8)
    - reject(::1/128)
    - reject(10.0.0.0/8)
    - reject(172.16.0.0/12)
    - reject(192.168.0.0/16)
    - reject(fc00::/7)
    - reject(fe80::/10)
    - direct(all)

trafficStats:
  listen: 127.0.0.1:4000
  secret: $STATS_SECRET
EOF

info "4. Firewall နှင့် Port Hopping Rules များကို Update ပြုလုပ်နေပါသည်..."
mkdir -p /etc/nftables.d
cat << EOF > /etc/nftables.d/hysteria.nft
table ip hysteria_nat {
    chain prerouting {
        type nat hook prerouting priority -100; policy accept;
        udp dport 20000-50000 redirect to :$PORT
    }
}
EOF
nft -f /etc/nftables.d/hysteria.nft 2>/dev/null || true
ufw allow $PORT/udp 2>/dev/null || true
ufw allow 20000:50000/udp 2>/dev/null || true

info "5. Certificate Permissions နှင့် Service များကို Restart ပြုလုပ်နေပါသည်..."
chmod -R 755 /etc/letsencrypt/archive /etc/letsencrypt/live 2>/dev/null || true
chown -R root:hysteria /etc/letsencrypt/live/ /etc/letsencrypt/archive/ 2>/dev/null || true
systemctl restart hysteria-server hysteria-panel nginx

echo "====================================================="
ok "🎉 Update ပြုလုပ်ခြင်း ၁၀၀% အောင်မြင်စွာ ပြီးစီးပါပြီ!"
echo "🌐 Web UI: https://$DOMAIN"
echo "====================================================="
