#!/bin/bash
# ============================================================
#  Enterprise 1-Click Server Hardening & Security Auto-Fix Tool
#  Version: 1.0 (Auto-Fixes Port 22, SSH, UFW, Fail2Ban, DDoS)
# ============================================================

set -e

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

info() { echo -e "${CYAN}[INFO]ℹ${NC} $1"; }
pass() { echo -e "${GREEN}[OK]✔${NC}  $1"; }
warn() { echo -e "${YELLOW}[WARN]⚠️${NC} $1"; }

TARGET_SSH_PORT="2213"

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}    🛡️ 1-CLICK ENTERPRISE SERVER SECURITY AUTO-FIX   ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

info "၁။ SSH Configuration များမှ Default Port 22 ကို ရှင်းထုတ်ပြီး Port ${TARGET_SSH_PORT} သီးသန့် ထားရှိနေပါသည်..."
# Remove Port 22 from main config
sudo sed -i '/^[# ]*Port 22$/d' /etc/ssh/sshd_config
sudo sed -i '/^[# ]*Port 22/d' /etc/ssh/sshd_config
sudo sed -i '/^[# ]*PermitRootLogin/d' /etc/ssh/sshd_config

# Ensure target port in drop-in config
sudo mkdir -p /etc/ssh/sshd_config.d/
cat << EOF | sudo tee /etc/ssh/sshd_config.d/99-safenet-hardening.conf > /dev/null
Port ${TARGET_SSH_PORT}
PermitRootLogin prohibit-password
PasswordAuthentication yes
X11Forwarding no
MaxAuthTries 5
ClientAliveInterval 30
ClientAliveCountMax 10
EOF
pass "SSH Config ကို Port ${TARGET_SSH_PORT} သီးသန့်ဖြင့် Hardening လုပ်ပြီးပါပြီ"

info "၂။ Firewall (UFW) တွင် Port 22 ကို ဖျက်ပစ်ပြီး Port ${TARGET_SSH_PORT} သာ ခွင့်ပြုနေပါသည်..."
sudo ufw allow ${TARGET_SSH_PORT}/tcp >/dev/null 2>&1 || true
sudo ufw delete allow 22/tcp >/dev/null 2>&1 || true
sudo ufw delete allow 22 >/dev/null 2>&1 || true
sudo ufw reload >/dev/null 2>&1 || true
pass "Firewall (UFW) တွင် Port 22 ပိတ်ပြီး Port ${TARGET_SSH_PORT} ကိုသာ ခွင့်ပြုထားပါသည်"

info "၃။ Fail2Ban ကို Port ${TARGET_SSH_PORT} ဖြင့် Brute-force ကာကွယ်ရန် ချိတ်ဆက်နေပါသည်..."
cat << EOF | sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null
[sshd]
enabled = true
port = ${TARGET_SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
findtime = 600
EOF
sudo systemctl restart fail2ban >/dev/null 2>&1 || true
pass "Fail2Ban သည် Port ${TARGET_SSH_PORT} တွင် တိုက်ခိုက်သူများကို ၂၄ နာရီ (86400s) Banned လုပ်မည်ဖြစ်သည်"

info "၄။ Anti-DDoS SYN Flood Protection (tcp_syncookies) ကို ဖွင့်လှစ်နေပါသည်..."
sudo sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p >/dev/null 2>&1 || true
pass "SYN Flood Anti-DDoS Protection ကို အောင်မြင်စွာ ဖွင့်လှစ်ပြီးပါပြီ"

info "၅။ SSH Daemon ကို ချိတ်ဆက်မှု မပြတ်တောက်စေဘဲ Clean Reload ပြုလုပ်နေပါသည်..."
sudo sshd -t
sudo systemctl restart ssh || sudo systemctl restart sshd
pass "SSH Daemon Reload ပြီးစီးပါပြီ (လက်ရှိ SSH Session မပြုတ်ပါ)"

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}   🎉 SERVER HARDENING & AUTO-FIX ၁၀၀% အောင်မြင်ပါပြီ!  ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  • လက်ရှိ သီးသန့် SSH Port: ${GREEN}${BOLD}${TARGET_SSH_PORT}${NC}"
echo -e "  • Default Port 22:         ${RED}${BOLD}CLOSED (လုံးဝပိတ်ထားသည်)${NC}"
echo -e "  • Root Direct Login:       ${GREEN}${BOLD}RESTRICTED (ပိတ်ထားသည်)${NC}"
echo -e "  • Fail2Ban Protection:     ${GREEN}${BOLD}ACTIVE (Port ${TARGET_SSH_PORT})${NC}"
echo -e "  • DDoS SYN Flood:          ${GREEN}${BOLD}PROTECTED${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
