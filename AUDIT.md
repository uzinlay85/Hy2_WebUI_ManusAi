# 🔍 Hysteria 2 Server Full Audit v2.1

> **Hysteria 2 Server** ၏ ကျန်းမာရေး၊ လုံခြုံရေးနှင့် စွမ်းဆောင်ရည်ကို တစ်ခါထဲ စစ်ဆေးနိုင်သော Audit Script

---

## 📋 စစ်ဆေးနိုင်သော အချက်များ

| # | Section | စစ်ဆေးချက် |
|:---:|:---|:---|
| 1 | **Server Info** | Hostname, Public IP, Domain, Hy2 Port, Uptime |
| 2 | **Core Services** | Hysteria 2, Web Panel, Nginx, Fail2Ban Status |
| 3 | **Port Status** | TCP 80/443/8888 + UDP 10443 |
| 4 | **Hysteria 2 Health** | Auth Endpoint, Traffic API, Online Clients, User Count |
| 5 | **SSL Certificate** | Certificate Validity + Expiry Days |
| 6 | **Network** | BBR TCP, Queue Discipline |
| 7 | **Firewall** | UFW Rules |
| 8 | **Resources** | RAM, Swap, Disk, CPU |
| 9 | **Error Logs** | Hysteria-server + Panel Error Logs |

---

## ⚡ တပ်ဆင်နည်း (Installation)

### အဆင့် ၁ - Script ကို ဆာဗာထဲ ထည့်သွင်းပါ

```bash
sudo tee /usr/local/bin/audit > /dev/null << 'AUDITEOF'
#!/bin/bash
clear
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
info() { echo -e "  ${CYAN}ℹ${NC}  $1"; }
sep()  { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

sep
echo -e "${BOLD}${YELLOW}        🔍 Hysteria 2 Server Full Audit v2.1          ${NC}"
sep

echo -e "\n${BOLD}${BLUE}[SERVER INFO]${NC}"
DOMAIN=$(grep "server_name" /etc/nginx/sites-available/hysteria_panel 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
HY_PORT=$(grep "^listen:" /etc/hysteria/config.yaml 2>/dev/null | grep -oP ':\K[0-9]+')
PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "Unknown")
info "Hostname  : $(hostname)"
info "Public IP : ${PUBLIC_IP}"
info "Domain    : ${DOMAIN:-Not configured}"
info "Hy2 Port  : ${HY_PORT:-10443}/UDP"
info "Uptime    : $(uptime -p 2>/dev/null)"

echo -e "\n${BOLD}${BLUE}[1] Core Services Status${NC}"
sep
SERVICES=("hysteria-server:Hysteria 2 Server" "hy2-panel:Web Panel" "nginx:Nginx Proxy" "fail2ban:Fail2Ban IDS")
for svc in "${SERVICES[@]}"; do
    name="${svc%%:*}"; label="${svc##*:}"
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        ok "$label (${name}): ${GREEN}RUNNING${NC}"
    else
        fail "$label (${name}): ${RED}STOPPED / FAILED${NC}"
    fi
done

echo -e "\n${BOLD}${BLUE}[2] Port Status${NC}"
sep
echo -e "  ${CYAN}── TCP Ports ──${NC}"
for p in 80 443 8888; do
    proc=$(ss -tlnp 2>/dev/null | grep ":$p " | awk -F'"' '{print $2}' | head -1)
    if [ -n "$proc" ]; then
        ok "TCP ${p}: ${GREEN}OPEN${NC} (${proc})"
    else
        warn "TCP ${p}: ${YELLOW}NOT LISTENING${NC}"
    fi
done
echo -e "  ${CYAN}── UDP Ports ──${NC}"
UDP_PORT="${HY_PORT:-10443}"
if ss -ulnp 2>/dev/null | grep -q ":${UDP_PORT} "; then
    ok "UDP ${UDP_PORT}: ${GREEN}OPEN${NC} (hysteria)"
else
    warn "UDP ${UDP_PORT}: ${YELLOW}NOT LISTENING${NC}"
fi

echo -e "\n${BOLD}${BLUE}[3] Hysteria 2 Health Check${NC}"
sep
AUTH_RESP=$(curl -s --max-time 3 -X POST http://127.0.0.1:8888/auth \
    -H "Content-Type: application/json" \
    -d '{"auth":"health_check","addr":"127.0.0.1"}' 2>/dev/null)
if echo "$AUTH_RESP" | grep -q '"ok"'; then
    ok "Panel Auth Endpoint: ${GREEN}RESPONDING${NC}"
else
    fail "Panel Auth Endpoint: ${RED}NOT RESPONDING${NC}"
fi
STATS_SECRET=$(grep "secret:" /etc/hysteria/config.yaml 2>/dev/null | awk '{print $2}' | head -1)
STATS=$(curl -s --max-time 3 -H "Authorization: $STATS_SECRET" http://127.0.0.1:4000/traffic 2>/dev/null)
if [ -n "$STATS" ]; then
    ok "Traffic Stats API: ${GREEN}RESPONDING${NC}"
else
    warn "Traffic Stats API: ${YELLOW}No response${NC}"
fi
ONLINE=$(curl -s --max-time 3 -H "Authorization: $STATS_SECRET" http://127.0.0.1:4000/online 2>/dev/null)
CLIENT_COUNT=$(echo "$ONLINE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
ok "Online Clients: ${GREEN}${CLIENT_COUNT} connected${NC}"
DB_PATH=$(ls /opt/hysteria-panel/*.db 2>/dev/null | head -1)
if [ -n "$DB_PATH" ]; then
    USER_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "?")
    ok "Total Users in DB: ${GREEN}${USER_COUNT} users${NC}"
else
    warn "Database: ${YELLOW}Not found${NC}"
fi
AUTH_URL=$(awk '/^auth:/{f=1} f && /url:/{print $2; exit}' /etc/hysteria/config.yaml 2>/dev/null)
if echo "$AUTH_URL" | grep -q "8888"; then
    ok "Auth URL: ${GREEN}${AUTH_URL} ✔${NC}"
else
    fail "Auth URL: ${RED}${AUTH_URL:-Not found} (Should be :8888)${NC}"
fi

echo -e "\n${BOLD}${BLUE}[4] SSL Certificate${NC}"
sep
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
if [ -f "$CERT_PATH" ]; then
    EXP_DATE=$(openssl x509 -enddate -noout -in "$CERT_PATH" 2>/dev/null | cut -d= -f2)
    EXP_EPOCH=$(date -d "$EXP_DATE" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
    if [ "$DAYS_LEFT" -gt 14 ]; then
        ok "SSL Certificate: ${GREEN}Valid - ${DAYS_LEFT} days remaining${NC}"
    elif [ "$DAYS_LEFT" -gt 0 ]; then
        warn "SSL Certificate: ${YELLOW}Expiring soon - ${DAYS_LEFT} days!${NC}"
    else
        fail "SSL Certificate: ${RED}EXPIRED!${NC}"
    fi
else
    fail "SSL Certificate: ${RED}Not found for ${DOMAIN}${NC}"
fi

echo -e "\n${BOLD}${BLUE}[5] Network & Performance${NC}"
sep
BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
[ "$BBR" = "bbr" ] && ok "TCP BBR: ${GREEN}ACTIVE${NC}" || warn "TCP BBR: ${YELLOW}${BBR}${NC}"
QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null)
ok "Queue Discipline: ${GREEN}${QDISC}${NC}"

echo -e "\n${BOLD}${BLUE}[6] Firewall (UFW)${NC}"
sep
UFW_STATUS=$(ufw status | head -1 | awk '{print $2}')
if [ "$UFW_STATUS" = "active" ]; then
    ok "UFW: ${GREEN}ACTIVE${NC}"
else
    fail "UFW: ${RED}INACTIVE${NC}"
fi
ufw status 2>/dev/null | grep -E "ALLOW|DENY" | grep -v "v6" | \
    while read line; do echo -e "  ${CYAN}→${NC} $line"; done

echo -e "\n${BOLD}${BLUE}[7] Server Resources${NC}"
sep
free -h | awk 'NR==2{printf "  RAM   → Total: %s  |  Used: %s  |  Free: %s\n",$2,$3,$4}'
free -h | awk 'NR==3{printf "  Swap  → Total: %s  |  Used: %s  |  Free: %s\n",$2,$3,$4}'
df -h / | awk 'NR==2{printf "  Disk  → Total: %s  |  Used: %s  |  Free: %s  (%s)\n",$2,$3,$4,$5}'
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
info "CPU Load: ${CPU_USAGE}% | $(nproc) cores"

echo -e "\n${BOLD}${BLUE}[8] Recent Error Logs${NC}"
sep
for svc in hysteria-server hy2-panel; do
    ERRS=$(journalctl -u $svc -p err -n 3 --no-pager 2>/dev/null | grep -v "^--" | tail -3)
    if [ -z "$ERRS" ]; then
        ok "${svc}: ${GREEN}No errors${NC}"
    else
        warn "${svc}: ${YELLOW}Errors found${NC}"
        echo "$ERRS" | while read line; do echo -e "    ${RED}→${NC} $line"; done
    fi
done

sep
echo -e "${BOLD}${GREEN}      ✅ AUDIT COMPLETED - $(date '+%Y-%m-%d %H:%M:%S')        ${NC}"
sep
AUDITEOF

sudo chmod +x /usr/local/bin/audit
echo "✅ Audit v2.1 installed!"
```

### အဆင့် ၂ - Execute Permission ပေးပါ

```bash
sudo chmod +x /usr/local/bin/audit
```

> ✅ Install ပြီးသွားပါသည်! ယခု `audit` command ကို ဘယ်နေရာမှမဆို ရိုက်ရန်သာ ကျန်ပါသည်။

---

## 🚀 အသုံးပြုနည်း (Usage)

```bash
# Basic run
audit

# Root permission နဲ့
sudo audit

# File သို့ Save လုပ်ရန်
audit | tee /tmp/audit-$(date +%Y%m%d).log

# Color မပါဘဲ Plain Text
audit | sed 's/\x1b\[[0-9;]*m//g' | tee /tmp/audit-plain.log
```

---

## 📊 Output ဖတ်နည်း (Reading the Output)

### Status Indicators

| Icon | အဓိပ္ပာယ် |
|:---:|:---|
| `✔` 🟢 | အောင်မြင်သည် / Normal |
| `❌` 🔴 | ပျက်နေသည် / Critical Error |
| `⚠️` 🟡 | သတိပြုရမည် / Warning |
| `ℹ` 🔵 | သတင်းအချက်အလက် / Info |

---

### [1] Core Services - ဖြေရှင်းနည်း
Service တစ်ခုခု `❌ STOPPED` ဖြစ်ပါက:
```bash
systemctl restart hysteria-server  # Hysteria 2
systemctl restart hy2-panel        # Web Panel
systemctl restart nginx            # Nginx
```

### [2] Port Status - ဖြေရှင်းနည်း
```bash
# TCP 8888 NOT LISTENING
systemctl restart hy2-panel

# UDP 10443 NOT LISTENING
systemctl restart hysteria-server
ufw allow 10443/udp
```

### [3] Auth URL ❌ ဖြစ်ပါက
```bash
sed -i 's|http://127.0.0.1:5000/auth|http://127.0.0.1:8888/auth|g' /etc/hysteria/config.yaml
systemctl restart hysteria-server
```

### [4] SSL Certificate - ဖြေရှင်းနည်း

| Status | ဆောင်ရွက်ချက် |
|:---|:---|
| `Valid - XX days` | ပုံမှန် ✅ |
| `Expiring soon` | `certbot renew --nginx` |
| `EXPIRED!` | ချက်ချင်း Renew လုပ်ပါ |

```bash
certbot renew --nginx
systemctl reload nginx
```

### [7] Resources - သတိပြုချက်

| Resource | Warning Level |
|:---|:---|
| RAM Used | 90%+ ကျော်ပါက Server Upgrade |
| Disk Used | 80%+ ကျော်ပါက Log Cleanup |
| CPU Load | 80%+ ကျော်ပါက Process စစ်ဆေး |

```bash
# Disk Cleanup
journalctl --vacuum-time=7d
apt autoremove -y && apt clean
```

### [8] Error Logs အပြည့်အဝ ကြည့်ရန်
```bash
journalctl -u hysteria-server -n 50 --no-pager
journalctl -u hy2-panel -n 50 --no-pager
```

---

## 📌 System Requirements

- **OS**: Ubuntu 22.04 / 24.04 LTS
- **Permission**: Root or sudo
- **Required**: Hysteria 2 + Python Panel (`install_hysteria.sh` ဖြင့် Install ထားရမည်)

---

## 📜 Version History

| Version | ပြောင်းလဲချက် |
|:---|:---|
| v1.0 | Initial release (nginx, x-ui, fail2ban only) |
| v2.0 | Hysteria 2 checks, SSL, Traffic Stats, Online Clients added |
| v2.1 | Port parsing bug fix, Auth URL section-aware grep fix |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
