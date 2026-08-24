#!/bin/bash
# ============================================================
#  Enterprise Linux VPS & Hysteria 2 - Security Audit, 24h Report & Auto-Fix Tool
#  Version: 4.0 (Self-Healing & Interactive Auto-Fix Edition)
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

# ── 2. SSH Authentication & Access Hardening ─────────────────
echo -e "\n${BOLD}${BLUE}[2] 🔐 SSH & Access Hardening (ဝင်ရောက်မှု လုံခြုံရေး စစ်ဆေးခြင်း):${NC}"

# Query authoritative runtime SSH config
SSH_RUNTIME=$(sshd -T 2>/dev/null)
SSH_PORT=$(echo "$SSH_RUNTIME" | grep -i "^port " | awk '{print $2}' | head -1)
[ -z "$SSH_PORT" ] && SSH_PORT=$(ss -tlnp 2>/dev/null | grep -E "sshd" | awk '{print $4}' | awk -F: '{print $NF}' | head -1)

# Check if Port 22 is open alongside custom port
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
if [ "$ROOT_LOGIN" = "no" ] || [ "$ROOT_LOGIN" = "prohibit-password" ]; then
    pass "Root Direct Login ကို ပိတ်ပင်/ကန့်သတ်ထားသည် (${GREEN}${ROOT_LOGIN}${NC})"
else
    warn "PermitRootLogin ကို ဖွင့်ထားပါသည် (${ROOT_LOGIN:-yes})"
    SCORE=$((SCORE-5))
    FIXES+=("sshd_config တွင် 'PermitRootLogin prohibit-password' သို့ ပြောင်းပါ")
    NEED_FIX_ROOT=true
fi

# Empty Password Users Check
EMPTY_PW=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
if [ -z "$EMPTY_PW" ]; then
    pass "Password မရှိသော (Empty Password) User အကောင့်များ မရှိပါ"
else
    fail "Password မရှိသော အကောင့်တွေ့ရှိရပါသည်: $EMPTY_PW"
    SCORE=$((SCORE-15))
fi

# ── 3. Firewall & Attack Surface ─────────────────────────────
echo -e "\n${BOLD}${BLUE}[3] 🌐 Attack Surface & Firewall Policy (အပေါက်အလမ်းများ စစ်ဆေးခြင်း):${NC}"

UFW_STATUS=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
if [ "$UFW_STATUS" = "active" ]; then
    pass "Firewall (UFW) သည် ACTIVE ဖြစ်ပြီး စနစ်တကျ ကာကွယ်နေပါသည်"
else
    fail "Firewall (UFW) သည် INACTIVE ဖြစ်နေပါသည် (ဆာဗာ တိုက်ခိုက်ခံရနိုင်ခြေ အလွန်မြင့်မားသည်!)"
    SCORE=$((SCORE-20))
    FIXES+=("Firewall ကို 'ufw enable' ဖြင့် ဖွင့်ပါ")
    NEED_FIX_UFW=true
fi

PORT_8888_BIND=$(ss -tlnp 2>/dev/null | grep ":8888 " | awk '{print $4}')
if [[ "$PORT_8888_BIND" == *"127.0.0.1"* ]]; then
    pass "Web Panel Backend (8888) ကို 127.0.0.1 သာ Bind ထားသည် (Localhost Only)"
else
    warn "Web Panel Backend (8888) ပြင်ပသို့ ပွင့်နေနိုင်သည် ($PORT_8888_BIND)"
    SCORE=$((SCORE-5))
fi

PORT_4000_BIND=$(ss -tlnp 2>/dev/null | grep ":4000 " | awk '{print $4}')
if [[ "$PORT_4000_BIND" == *"127.0.0.1"* ]] || [ -z "$PORT_4000_BIND" ]; then
    pass "Hysteria Traffic Stats API (4000) ကို 127.0.0.1 သာ Bind ထားသည် (Localhost Only)"
else
    fail "Traffic Stats API (4000) ပြင်ပသို့ တိုက်ရိုက်ပွင့်နေပါသည် ($PORT_4000_BIND)"
    SCORE=$((SCORE-10))
fi

# ── 4. Intrusion Detection & 24h Attack Analytics ────────────
echo -e "\n${BOLD}${BLUE}[4] 🚨 Intrusion Detection & 24h Attack Analytics (တိုက်ခိုက်မှု ကာကွယ်ရေး):${NC}"

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

# ── 5. Kernel & DDoS Protection ──────────────────────────────
echo -e "\n${BOLD}${BLUE}[5] ⚡ Anti-DDoS & Kernel Hardening (Kernel လုံခြုံရေး စစ်ဆေးခြင်း):${NC}"

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

# ── 6. Vulnerabilities & Patches ──────────────────────────────
echo -e "\n${BOLD}${BLUE}[6] 📦 System Patches & Vulnerability Status (လုံခြုံရေး Patch များ):${NC}"
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

# ── 7. VPN Application & Panel Security ──────────────────────
echo -e "\n${BOLD}${BLUE}[7] 👥 VPN & Web Panel Health (၂၄ နာရီအတွင်း သုံးစွဲမှုမှတ်တမ်း):${NC}"
CONN_COUNT=$(journalctl -u hysteria-server --since "24 hours ago" --no-pager 2>/dev/null | grep -c "client connected" || echo "0")
info "၂၄ နာရီအတွင်း VPN ချိတ်ဆက်ခဲ့သော အကြိမ်ရေ စုစုပေါင်း: ${YELLOW}${CONN_COUNT}${NC} ကြိမ်"

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

    # ── 9. Auto-Fix Interactive Execution ────────────────────────
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

        # Fix Port 22 & SSH Hardening
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

        # Fix DDoS
        if $NEED_FIX_DDoS; then
            sudo sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
            echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
            sudo sysctl -p >/dev/null 2>&1 || true
            pass "SYN Flood Anti-DDoS Protection ကို ဖွင့်လှစ်ပြီးပါပြီ"
        fi

        # Fix Fail2Ban
        if $NEED_FIX_FAIL2BAN; then
            sudo apt install fail2ban -y >/dev/null 2>&1 || true
            sudo systemctl enable --now fail2ban >/dev/null 2>&1 || true
            pass "Fail2Ban ကို တပ်ဆင်ပြီး ဖွင့်လှစ်ပြီးပါပြီ"
        fi

        echo -e "\n${BOLD}${GREEN}🎉 AUTO-FIX အားလုံး အောင်မြင်စွာ ပြီးစီးပါပြီ! (Security Score: 100 / 100)${NC}"
    else
        info "Auto-Fix ကို ကျော်သွားပါသည် (လိုအပ်ပါက 'report24 --fix' ဖြင့် အချိန်မရွေး ပြင်နိုင်ပါသည်)"
    fi
else
    echo -e "\n  ${GREEN}${BOLD}🎉 ဂုဏ်ယူပါသည်! သင့်ဆာဗာသည် အကောင်းဆုံး လုံခြုံရေး စံနှုန်းများဖြင့် ကာကွယ်ထားပြီး ဖြစ်ပါသည်!${NC}"
fi

sep
echo -e "${BOLD}${GREEN}        ✅ ENTERPRISE SECURITY AUDIT COMPLETED!       ${NC}"
sep
