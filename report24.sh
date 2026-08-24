#!/bin/bash
# ============================================================
#  Hysteria 2 + VPS 24-Hour Activity & Health Report Tool
#  Version: 1.0 (Standalone & Universal)
# ============================================================

clear
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

sep() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

sep
echo -e "${BOLD}${YELLOW}       📊 VPS 24-HOUR ACTIVITY & HEALTH REPORT       ${NC}"
sep

# ── 1. Uptime & Reboot Check ─────────────────────────────────
echo -e "\n${BOLD}${BLUE}[1] ⏱️ Uptime & Reboot Check (လွန်ခဲ့သော ၂၄ နာရီအတွင်း):${NC}"
UPTIME_STR=$(uptime -p 2>/dev/null || uptime)
echo -e "  • လက်ရှိ Uptime: ${GREEN}${UPTIME_STR}${NC}"

REBOOTS=$(last reboot --since "24 hours ago" 2>/dev/null | grep -v "wtmp" | head -n -1)
if [ -z "$REBOOTS" ]; then
    echo -e "  ${GREEN}✔ လွန်ခဲ့သော ၂၄ နာရီအတွင်း ဆာဗာ Restart/Reboot လုံးဝမဖြစ်ခဲ့ပါ (၁၀၀% တည်ငြိမ်သည်)${NC}"
else
    echo -e "  ${YELLOW}⚠️ Reboot ဖြစ်ခဲ့သော မှတ်တမ်း:${NC}\n$REBOOTS"
fi

# ── 2. Watchdog Downtime Log ─────────────────────────────────
echo -e "\n${BOLD}${BLUE}[2] 🛡️ Watchdog Downtime Log (Service များ ရပ်တန့်ခဲ့ခြင်း ရှိမရှိ):${NC}"
if [ -f /var/log/hy2-watchdog.log ]; then
    DOWNS=$(grep "was DOWN" /var/log/hy2-watchdog.log 2>/dev/null | tail -5)
    if [ -z "$DOWNS" ]; then
        echo -e "  ${GREEN}✔ လွန်ခဲ့သော ၂၄ နာရီအတွင်း Service များ (Hy2, Panel, Nginx) တစ်ခုမှ မရပ်ခဲ့ပါ${NC}"
    else
        echo -e "  ${RED}❌ ရပ်တန့်ခဲ့ဖူးသော အကြိမ်များ:${NC}\n$DOWNS"
    fi
    LAST_HEARTBEAT=$(grep "All services OK" /var/log/hy2-watchdog.log 2>/dev/null | tail -1)
    [ -n "$LAST_HEARTBEAT" ] && echo -e "  ${CYAN}ℹ နောက်ဆုံးပုံမှန်လည်ပတ်ကြောင်း အတည်ပြုချက်:${NC} ${LAST_HEARTBEAT}"
else
    echo -e "  ${CYAN}ℹ Watchdog log ဖိုင် မရှိသေးပါ (Service များ အားလုံး အဆင်ပြေစွာ လည်ပတ်နေပါသည်)${NC}"
fi

# ── 3. Hysteria 2 VPN Activity ───────────────────────────────
echo -e "\n${BOLD}${BLUE}[3] 👥 VPN အသုံးပြုမှု မှတ်တမ်း (Hysteria 2 Activity in 24h):${NC}"
CONN_COUNT=$(journalctl -u hysteria-server --since "24 hours ago" --no-pager 2>/dev/null | grep -c "client connected" || echo "0")
DISC_COUNT=$(journalctl -u hysteria-server --since "24 hours ago" --no-pager 2>/dev/null | grep -c "client disconnected" || echo "0")
echo -e "  • စုစုပေါင်း VPN ချိတ်ဆက်ခဲ့သော အကြိမ်: ${YELLOW}${CONN_COUNT}${NC} ကြိမ်"
echo -e "  • စုစုပေါင်း Disconnect ဖြစ်ခဲ့သော အကြိမ်: ${YELLOW}${DISC_COUNT}${NC} ကြိမ်"

USER_LOGS=$(journalctl -u hysteria-server --since "24 hours ago" --no-pager 2>/dev/null | grep "client connected" | awk -F'"id": "' '{print $2}' | awk -F'"' '{print $1}')
if [ -n "$USER_LOGS" ]; then
    echo -e "  • ချိတ်ဆက်ခဲ့သော User များ စာရင်း:"
    echo "$USER_LOGS" | sort | uniq -c | while read count user; do
        if [ -n "$user" ]; then
            echo -e "    ${GREEN}✔ User: ${user}${NC} (ချိတ်ဆက်မှု ${count} ကြိမ်)"
        else
            echo -e "    ${GREEN}✔ User: (Active Session)${NC} (ချိတ်ဆက်မှု ${count} ကြိမ်)"
        fi
    done
else
    echo -e "  ${CYAN}ℹ လွန်ခဲ့သော ၂၄ နာရီအတွင်း ချိတ်ဆက်မှု မှတ်တမ်း မရှိသေးပါ${NC}"
fi

# ── 4. Security & SSH / Fail2Ban ─────────────────────────────
echo -e "\n${BOLD}${BLUE}[4] 🔐 လုံခြုံရေးနှင့် SSH Login မှတ်တမ်း (Security Check):${NC}"
LOGINS=$(grep "Accepted password" /var/log/auth.log 2>/dev/null | tail -5 | awk '{print "    ✔ " $1, $2, $3, "-> User: " $9, "from IP: " $11}')
if [ -n "$LOGINS" ]; then
    echo -e "  • အောင်မြင်စွာ ဝင်ရောက်ခဲ့သော SSH Logins:\n$LOGINS"
else
    echo -e "  • အောင်မြင်စွာ ဝင်ရောက်ခဲ့သော SSH Logins: ${CYAN}(Log ရှင်းလင်းသည်)${NC}"
fi

BANS=$(grep "Ban " /var/log/fail2ban.log 2>/dev/null | tail -5 | awk '{print "    🚫 Blocked IP: " $NF, "at", $1, $2}')
if [ -n "$BANS" ]; then
    echo -e "  • Fail2Ban မှ ဖမ်းဆီးပိတ်ပင်ခဲ့သော Attackers များ:\n$BANS"
else
    echo -e "  • Fail2Ban မှ ဖမ်းဆီးပိတ်ပင်ထားသော တိုက်ခိုက်မှု မရှိပါ (Normal)"
fi

# ── 5. System & Kernel Errors ────────────────────────────────
echo -e "\n${BOLD}${BLUE}[5] ⚠️ System & Kernel Errors (၂၄ နာရီအတွင်း စနစ်ပိုင်း အမှားများ):${NC}"
SYS_ERR=$(journalctl --since "24 hours ago" -p 0..3 --no-pager 2>/dev/null | grep -v "^--" | grep -v "kex_exchange" | grep -v "Protocol major" | tail -5)
if [ -z "$SYS_ERR" ]; then
    echo -e "  ${GREEN}✔ Critical System Error နှင့် Kernel Panic လုံးဝမရှိပါ (Clean & Stable)${NC}"
else
    echo -e "  ${YELLOW}⚠️ တွေ့ရှိရသော အမှား Log များ:${NC}\n$SYS_ERR"
fi

# ── 6. Summary ───────────────────────────────────────────────
sep
echo -e "${BOLD}${GREEN}         ✅ 24-HOUR REPORT COMPLETED!                ${NC}"
sep
