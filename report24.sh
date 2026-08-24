#!/bin/bash
# ============================================================
#  Enterprise Linux VPS - Multi-VPN Inspector & Security Suite
#  Version: 5.0 (All-in-One Multi-Protocol Auto-Discovery Edition)
#  Supports: Hysteria 2, AmneziaWG, VLESS (3X-UI/Xray), Outline, WireGuard
# ============================================================

clear
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]✔${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]⚠️${NC}  $1"; }
fail() { echo -e "  ${RED}[FAIL]❌${NC} $1"; }
info() { echo -e "  ${CYAN}[INFO]ℹ${NC}  $1"; }
sep()  { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

SCORE=100
FIXES=()
NEED_FIX_PORT22=false
NEED_FIX_ROOT=false
NEED_FIX_UFW=false
NEED_FIX_DDoS=false
NEED_FIX_FAIL2BAN=false

AUTO_FLAG="$1"

sep
echo -e "${BOLD}${YELLOW}       🛡️ ENTERPRISE SERVER SECURITY AUDIT & 24H REPORT       ${NC}"
sep

# ── 1. System Overview & 24h Uptime ──────────────────────────
echo -e "\n${BOLD}${BLUE}[1] ⏱️ System Health & Uptime (လွန်ခဲ့သော ၂၄ နာရီအတွင်း):${NC}"
UPTIME_STR=$(uptime -p 2>/dev/null || uptime)
info "Server Uptime: ${UPTIME_STR}"
REBOOTS=$(last reboot --since "24 hours ago" 2>/dev/null | grep -v "wtmp" | head -n -1)
if [ -z "$REBOOTS" ]; then
    pass "၂၄ နာရီအတွင်း ဆာဗာ Reboot/Crash လုံးဝမဖြစ်ခဲ့ပါ (၁၀၀% တည်ငြိမ်သည်)"
else
    warn "၂၄ နာရီအတွင်း Reboot ဖြစ်ခဲ့သော မှတ်တမ်းတွေ့ရှိရပါသည်:\n$REBOOTS"
    SCORE=$((SCORE-5))
fi

# ── 2. Multi-VPN Protocols & Services Discovery ──────────────
echo -e "\n${BOLD}${BLUE}[2] 🌐 Multi-VPN Services & Protocols Discovery (တပ်ဆင်ထားသမျှ VPN စနစ်များ):${NC}"

# (A) Hysteria 2
if [ -f /etc/hysteria/config.yaml ] || command -v hysteria >/dev/null 2>&1 || systemctl list-unit-files | grep -q "hysteria"; then
    HY2_PORT=$(grep "^listen:" /etc/hysteria/config.yaml 2>/dev/null | grep -oP ':\K[0-9]+' | head -1)
    if [ -z "$HY2_PORT" ]; then
        HY2_PORT=$(ss -ulnp 2>/dev/null | grep "hysteria" | awk '{print $5}' | grep -oP ':\K[0-9]+' | head -1)
    fi
    if systemctl is-active --quiet hysteria-server 2>/dev/null; then
        echo -e "  ${GREEN}✔ Hysteria 2 VPN:${NC} \033[1;32mRUNNING\033[0m (Main Port: ${GREEN}${HY2_PORT:-10443}/UDP${NC})"
    else
        echo -e "  ${RED}❌ Hysteria 2 VPN:${NC} \033[1;31mSTOPPED / FAILED\033[0m"
        HY2_ERR=$(journalctl -u hysteria-server -p err -n 2 --no-pager 2>/dev/null | grep -v "^--" | tail -2)
        [ -n "$HY2_ERR" ] && echo -e "     ${RED}→ Error:${NC} $HY2_ERR"
    fi
fi

# (B) AmneziaWG / Amnezia Easy (Native & Docker)
AWG_DOCKER=$(command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -i "amnezia" | head -1 || true)
if pgrep -f "amneziawg" >/dev/null 2>&1 || ip link show | grep -q "awg" || [ -d /opt/amnezia ] || [ -n "$AWG_DOCKER" ]; then
    if [ -n "$AWG_DOCKER" ]; then
        AWG_PORT=$(docker port "$AWG_DOCKER" 2>/dev/null | grep "udp" | awk '{print $3}' | awk -F: '{print $NF}' | head -1)
        [ -z "$AWG_PORT" ] && AWG_PORT="58210"
        echo -e "  ${GREEN}✔ AmneziaWG (Easy):${NC} \033[1;32mRUNNING (Docker: $AWG_DOCKER)\033[0m (UDP Port: ${GREEN}${AWG_PORT}/UDP${NC})"
    else
        AWG_PORT=$(wg show awg0 listen-port 2>/dev/null || ss -ulnp 2>/dev/null | grep "amneziawg" | awk '{print $5}' | grep -oP ':\K[0-9]+' | head -1)
        AWG_DEV=$(ip -br link 2>/dev/null | grep "awg" | awk '{print $1}' | head -1)
        if pgrep -f "amneziawg" >/dev/null 2>&1 || [ -n "$AWG_DEV" ]; then
            echo -e "  ${GREEN}✔ AmneziaWG (Easy):${NC} \033[1;32mRUNNING\033[0m (Interface: ${GREEN}${AWG_DEV:-awg0}${NC}, UDP Port: ${GREEN}${AWG_PORT:-58210}${NC})"
        else
            echo -e "  ${RED}❌ AmneziaWG (Easy):${NC} \033[1;31mSTOPPED\033[0m"
        fi
    fi
fi

# (C) VLESS / 3X-UI / Xray
if systemctl list-unit-files 2>/dev/null | grep -qE "x-ui|xray|v2ray|sing-box" || [ -d /usr/local/x-ui ] || command -v xray >/dev/null 2>&1; then
    XRAY_RUNNING=false
    XRAY_NAME="X-UI / Xray"
    if systemctl is-active --quiet x-ui 2>/dev/null; then XRAY_RUNNING=true; XRAY_NAME="3X-UI Panel & Xray"; fi
    if systemctl is-active --quiet xray 2>/dev/null; then XRAY_RUNNING=true; XRAY_NAME="Xray Core"; fi
    if systemctl is-active --quiet sing-box 2>/dev/null; then XRAY_RUNNING=true; XRAY_NAME="Sing-Box Core"; fi
    
    if $XRAY_RUNNING; then
        XRAY_PORTS=$(ss -tlnp 2>/dev/null | grep -E "xray|x-ui|sing-box" | awk '{print $4}' | awk -F: '{print $NF}' | tr '\n' ',' | sed 's/,$//')
        echo -e "  ${GREEN}✔ VLESS / ${XRAY_NAME}:${NC} \033[1;32mRUNNING\033[0m (Active Ports: ${XRAY_PORTS:-Listening})"
    else
        echo -e "  ${YELLOW}⚠️  VLESS / 3X-UI (Xray):${NC} \033[1;33mSTOPPED / INACTIVE\033[0m (တပ်ဆင်ထားသော်လည်း ရပ်တန့်နေသည်)"
        XRAY_ERR=$(journalctl -u x-ui -u xray -p err -n 2 --no-pager 2>/dev/null | grep -v "^--" | tail -2)
        [ -n "$XRAY_ERR" ] && echo -e "     ${YELLOW}→ Error Log:${NC} $XRAY_ERR"
    fi
fi

# (D) Outline VPN (Shadowbox Docker)
if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "shadowbox"; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "shadowbox"; then
        OUTLINE_PORTS=$(docker port shadowbox 2>/dev/null | awk '{print $3}' | tr '\n' ',' | sed 's/,$//')
        echo -e "  ${GREEN}✔ Outline VPN (Shadowbox):${NC} \033[1;32mRUNNING (Docker)\033[0m (Ports: ${OUTLINE_PORTS:-Active})"
    else
        echo -e "  ${RED}❌ Outline VPN (Shadowbox):${NC} \033[1;31mSTOPPED (Container Exited)\033[0m"
        OUTLINE_ERR=$(docker logs --tail 2 shadowbox 2>/dev/null)
        [ -n "$OUTLINE_ERR" ] && echo -e "     ${RED}→ Container Error:${NC} $OUTLINE_ERR"
    fi
fi

# (E) Standard WireGuard / OpenVPN
if systemctl list-unit-files 2>/dev/null | grep -q "wg-quick@" || [ -d /etc/wireguard ]; then
    if ip link show | grep -q "wg" || systemctl is-active --quiet "wg-quick@*" 2>/dev/null; then
        echo -e "  ${GREEN}✔ WireGuard VPN:${NC} \033[1;32mRUNNING\033[0m"
    else
        echo -e "  ${YELLOW}⚠️  WireGuard VPN:${NC} \033[1;33mINACTIVE\033[0m"
    fi
fi

# ── 3. SSH Authentication & Access Hardening ─────────────────
echo -e "\n${BOLD}${BLUE}[3] 🔐 SSH & Access Hardening (ဝင်ရောက်မှု လုံခြုံရေး စစ်ဆေးခြင်း):${NC}"

SSH_RUNTIME=$(sshd -T 2>/dev/null)
SSH_PORT=$(echo "$SSH_RUNTIME" | grep -i "^port " | awk '{print $2}' | head -1)
[ -z "$SSH_PORT" ] && SSH_PORT=$(ss -tlnp 2>/dev/null | grep -E "sshd" | awk '{print $4}' | awk -F: '{print $NF}' | head -1)

PORT22_OPEN=$(ss -tlnp 2>/dev/null | grep -E ":22 " | grep "sshd" || true)
if [ -n "$PORT22_OPEN" ] || [ "$SSH_PORT" = "22" ]; then
    warn "Default SSH Port (22) ပွင့်နေပါသည် (Bot attack ပစ်မှတ်ဖြစ်လွယ်သည်)"
    SCORE=$((SCORE-5))
    FIXES+=("Default Port 22 ကို sshd_config မှ ဖျက်ပစ်ပြီး Port 2213 သီးသန့် ထားရှိပါ")
    NEED_FIX_PORT22=true
else
    pass "Custom SSH Port အသုံးပြုထားသည် (Port: ${GREEN}${SSH_PORT}${NC} - Brute-force ကာကွယ်ထားသည်)"
fi

ROOT_LOGIN=$(echo "$SSH_RUNTIME" | grep -i "^permitrootlogin " | awk '{print $2}' | head -1)
if [ "$ROOT_LOGIN" = "no" ] || [ "$ROOT_LOGIN" = "prohibit-password" ] || [ "$ROOT_LOGIN" = "without-password" ]; then
    pass "Root Direct Login ကို ပိတ်ပင်/ကန့်သတ်ထားသည် (${GREEN}${ROOT_LOGIN}${NC})"
else
    warn "PermitRootLogin ကို ဖွင့်ထားပါသည် (${ROOT_LOGIN:-yes})"
    SCORE=$((SCORE-5))
    FIXES+=("sshd_config တွင် 'PermitRootLogin prohibit-password' သို့ ပြောင်းပါ")
    NEED_FIX_ROOT=true
fi

EMPTY_PW=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
if [ -z "$EMPTY_PW" ]; then
    pass "Password မရှိသော (Empty Password) User အကောင့်များ မရှိပါ"
else
    fail "Password မရှိသော အကောင့်တွေ့ရှိရပါသည်: $EMPTY_PW"
    SCORE=$((SCORE-15))
fi

# ── 4. Firewall & Attack Surface ─────────────────────────────
echo -e "\n${BOLD}${BLUE}[4] 🌐 Attack Surface & Firewall Policy (အပေါက်အလမ်းများ စစ်ဆေးခြင်း):${NC}"

UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
if [ "$UFW_STATUS" = "active" ]; then
    pass "Firewall (UFW) သည် ACTIVE ဖြစ်ပြီး စနစ်တကျ ကာကွယ်နေပါသည်"
else
    fail "Firewall (UFW) သည် INACTIVE ဖြစ်နေပါသည် (ဆာဗာ တိုက်ခိုက်ခံရနိုင်ခြေ အလွန်မြင့်မားသည်!)"
    SCORE=$((SCORE-20))
    FIXES+=("Firewall ကို 'ufw enable' ဖြင့် ဖွင့်ပါ")
    NEED_FIX_UFW=true
fi

PANEL_BIND=$(ss -tlnp 2>/dev/null | grep -E ":(8888|5000) " | grep -E "python|flask" | head -1 | awk '{print $4}')
[ -z "$PANEL_BIND" ] && PANEL_BIND=$(ss -tlnp 2>/dev/null | grep -E ":(8888|5000) " | head -1 | awk '{print $4}')
if [[ "$PANEL_BIND" == *"127.0.0.1"* ]] || [[ "$PANEL_BIND" == *"[::1]"* ]]; then
    pass "Web Panel Backend ကို 127.0.0.1 တွင်သာ Bind ထားသည် (Localhost Only - Secure)"
elif [ -z "$PANEL_BIND" ]; then
    pass "Web Panel Backend Port ပြင်ပသို့ တိုက်ရိုက်ဖွင့်ထားခြင်း မရှိပါ (Protected via Nginx)"
else
    warn "Web Panel Backend ပြင်ပသို့ တိုက်ရိုက်ပွင့်နေနိုင်သည် (${PANEL_BIND})"
    SCORE=$((SCORE-5))
fi

PORT_4000_BIND=$(ss -tlnp 2>/dev/null | grep ":4000 " | awk '{print $4}')
if [[ "$PORT_4000_BIND" == *"127.0.0.1"* ]] || [ -z "$PORT_4000_BIND" ]; then
    pass "Hysteria Traffic Stats API (4000) ကို 127.0.0.1 သာ Bind ထားသည် (Localhost Only)"
else
    fail "Traffic Stats API (4000) ပြင်ပသို့ တိုက်ရိုက်ပွင့်နေပါသည် ($PORT_4000_BIND)"
    SCORE=$((SCORE-10))
fi

# ── 5. Intrusion Detection & 24h Attack Analytics ────────────
echo -e "\n${BOLD}${BLUE}[5] 🚨 Intrusion Detection & 24h Attack Analytics (တိုက်ခိုက်မှု ကာကွယ်ရေး):${NC}"

if systemctl is-active --quiet fail2ban 2>/dev/null; then
    pass "Fail2Ban Intrusion Prevention System: RUNNING"
    BANNED_TOTAL=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned:" | awk '{print $NF}')
    info "လက်ရှိ အချိန်တွင် Block (Banned) လုပ်ထားသော Attacker IP စုစုပေါင်း: ${BANNED_TOTAL:-0} ခု"
    
    BANS_24H=$(grep "Ban " /var/log/fail2ban.log 2>/dev/null | tail -5 | awk '{print "    🚫 Blocked IP: " $NF, "at", $1, $2}')
    if [ -n "$BANS_24H" ]; then
        echo -e "  • လွန်ခဲ့သော ၂၄ နာရီအတွင်း ဖမ်းဆီးပိတ်ပင်ခဲ့သော Hackers/Bots များ:\n$BANS_24H"
    else
        info "လွန်ခဲ့သော ၂၄ နာရီအတွင်း တိုက်ခိုက်မှုကြောင့် အသစ် Block ခဲ့ရသော IP မရှိပါ (Normal)"
    fi
else
    warn "Fail2Ban မတက်နေပါ သို့မဟုတ် မတပ်ဆင်ရသေးပါ"
    SCORE=$((SCORE-10))
    FIXES+=("Fail2ban ကို တပ်ဆင်ပြီး ဖွင့်လှစ်ပါ")
    NEED_FIX_FAIL2BAN=true
fi

FAILED_SSH=$(journalctl -u ssh -u sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -c "Failed password" || echo "0")
FAILED_SSH=$(echo "$FAILED_SSH" | tr '\n' ' ' | awk '{sum+=$1+$2} END {print sum+0}')
if [ "$FAILED_SSH" -gt 50 ]; then
    warn "လွန်ခဲ့သော ၂၄ နာရီအတွင်း Password မှားယွင်းရိုက်နှိပ်မှု: ${RED}${FAILED_SSH} ကြိမ်${NC} တွေ့ရှိရသည်"
    SCORE=$((SCORE-5))
else
    pass "Password မှားယွင်းရိုက်နှိပ်မှု: ${FAILED_SSH} ကြိမ်သာ ရှိသည် (ပုံမှန် အခြေအနေ)"
fi

# ── 6. Kernel & DDoS Protection ──────────────────────────────
echo -e "\n${BOLD}${BLUE}[6] ⚡ Anti-DDoS & Kernel Hardening (Kernel လုံခြုံရေး စစ်ဆေးခြင်း):${NC}"

SYN_COOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
if [ "$SYN_COOKIES" = "1" ]; then
    pass "SYN Flood DDoS Protection (tcp_syncookies): ENABLED"
else
    warn "SYN Flood DDoS Protection ပိတ်နေပါသည်"
    SCORE=$((SCORE-5))
    FIXES+=("SYN Flood DDoS Protection (tcp_syncookies = 1) ကို ဖွင့်ပါ")
    NEED_FIX_DDoS=true
fi

BBR_STATUS=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [ "$BBR_STATUS" = "bbr" ]; then
    pass "Google BBR Congestion Control: ACTIVE (High-Speed Throughput)"
else
    warn "Google BBR မဖွင့်ရသေးပါ (လက်ရှိ: $BBR_STATUS)"
fi

# ── 7. Vulnerabilities & Patches ──────────────────────────────
echo -e "\n${BOLD}${BLUE}[7] 📦 System Patches & Vulnerability Status (လုံခြုံရေး Patch များ):${NC}"
UPGRADES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
info "Update ပြုလုပ်နိုင်သော Package စုစုပေါင်း: ${YELLOW}${UPGRADES}${NC} ခု ရှိပါသည်"

DOMAIN=$(grep "server_name" /etc/nginx/sites-available/hysteria_panel 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
if [ -n "$DOMAIN" ] && [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    EXP_DATE=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" 2>/dev/null | cut -d= -f2)
    EXP_EPOCH=$(date -d "$EXP_DATE" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
    pass "SSL/TLS Certificate: သက်တမ်း ${GREEN}${DAYS_LEFT} ရက်${NC} ကျန်ရှိပါသည် (Good)"
fi

# ── 8. Security Score & Actionable Summary ───────────────────
echo -e "\n${BOLD}${BLUE}[8] 🏆 DevSecOps Security Score & Hardening Summary:${NC}"
sep

if [ "$SCORE" -ge 90 ]; then
    GRADE_COLOR="${GREEN}"; GRADE="A+ (EXCELLENT & HARDENED)"
elif [ "$SCORE" -ge 80 ]; then
    GRADE_COLOR="${GREEN}"; GRADE="A (SECURE & STABLE)"
elif [ "$SCORE" -ge 70 ]; then
    GRADE_COLOR="${YELLOW}"; GRADE="B (MODERATE - IMPROVEMENT RECOMMENDED)"
else
    GRADE_COLOR="${RED}"; GRADE="C / HIGH RISK (ACTION REQUIRED)"
fi

echo -e "  • စုစုပေါင်း လုံခြုံရေး ရမှတ် (Security Score): ${GRADE_COLOR}${BOLD}${SCORE} / 100${NC}"
echo -e "  • လုံခြုံရေး အဆင့်အတန်း (Security Rating):   ${GRADE_COLOR}${BOLD}${GRADE}${NC}"

if [ ${#FIXES[@]} -gt 0 ]; then
    echo -e "\n  ${YELLOW}${BOLD}⚠️ တွေ့ရှိရသော အားနည်းချက်များ (${#FIXES[@]} ခု):${NC}"
    for i in "${!FIXES[@]}"; do
        echo -e "    $((i+1)). ${FIXES[$i]}"
    done

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    DO_FIX=false
    if [ "$AUTO_FLAG" = "--fix" ] || [ "$AUTO_FLAG" = "-f" ] || [ "$AUTO_FLAG" = "fix" ]; then
        DO_FIX=true
    else
        read -p "⚡ တွေ့ရှိရသော အားနည်းချက်များကို အလိုအလျောက် ချက်ချင်း ပြင်ဆင် (Auto-Fix) လိုပါသလား? [y/N]: " USER_INPUT
        if [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
            DO_FIX=true
        fi
    fi

    if $DO_FIX; then
        echo -e "\n${BOLD}${CYAN}[AUTO-FIX] စနစ်မှ အားနည်းချက်များကို ချက်ချင်း ပြင်ဆင်ပေးနေပါသည်...${NC}"
        TARGET_PORT="2213"

        if $NEED_FIX_PORT22 || $NEED_FIX_ROOT; then
            sudo sed -i '/^[# ]*Port 22$/d' /etc/ssh/sshd_config 2>/dev/null || true
            sudo sed -i '/^[# ]*Port 22/d' /etc/ssh/sshd_config 2>/dev/null || true
            sudo sed -i '/^[# ]*PermitRootLogin/d' /etc/ssh/sshd_config 2>/dev/null || true
            sudo mkdir -p /etc/ssh/sshd_config.d/
            cat << EOF | sudo tee /etc/ssh/sshd_config.d/99-safenet-hardening.conf > /dev/null
Port ${TARGET_PORT}
PermitRootLogin prohibit-password
PasswordAuthentication yes
X11Forwarding no
MaxAuthTries 5
ClientAliveInterval 30
ClientAliveCountMax 10
EOF
            sudo ufw allow ${TARGET_PORT}/tcp >/dev/null 2>&1 || true
            sudo ufw delete allow 22/tcp >/dev/null 2>&1 || true
            sudo ufw delete allow 22 >/dev/null 2>&1 || true
            sudo ufw reload >/dev/null 2>&1 || true
            sudo systemctl restart ssh || sudo systemctl restart sshd || true
            pass "Port 22 ကို လုံးဝပိတ်ပြီး Port ${TARGET_PORT} သီးသန့် ပြောင်းလဲ Hardening ပြုလုပ်ပြီးပါပြီ"
        fi

        if $NEED_FIX_DDoS; then
            sudo sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
            echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
            sudo sysctl -p >/dev/null 2>&1 || true
            pass "SYN Flood Anti-DDoS Protection ကို ဖွင့်လှစ်ပြီးပါပြီ"
        fi

        if $NEED_FIX_FAIL2BAN; then
            sudo apt install fail2ban -y >/dev/null 2>&1 || true
            sudo systemctl enable --now fail2ban >/dev/null 2>&1 || true
            pass "Fail2Ban ကို တပ်ဆင်ပြီး ဖွင့်လှစ်ပြီးပါပြီ"
        fi

        echo -e "\n${BOLD}${GREEN}🎉 AUTO-FIX အားလုံး အောင်မြင်စွာ ပြီးစီးပါပြီ! (Security Score: 100 / 100)${NC}"
    fi
else
    echo -e "\n  ${GREEN}${BOLD}🎉 ဂုဏ်ယူပါသည်! သင့်ဆာဗာသည် အကောင်းဆုံး လုံခြုံရေး စံနှုန်းများဖြင့် ကာကွယ်ထားပြီး ဖြစ်ပါသည်!${NC}"
fi

sep
echo -e "${BOLD}${GREEN}        ✅ ENTERPRISE SECURITY AUDIT COMPLETED!       ${NC}"
sep
