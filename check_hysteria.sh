#!/bin/bash

# =============================================================
#  Hysteria 2 + Python Web Panel - 1-Click Auto Checker Script
#  Version 2.0 - Comprehensive 8-point system check
# =============================================================

echo "====================================================="
echo "🔍 Hysteria 2 အလိုအလျောက် စစ်ဆေးရေးစနစ် (v2.0)"
echo "====================================================="

# 1. Check Hysteria Service
echo -n "၁။ Hysteria Server အခြေအနေ: "
if systemctl is-active --quiet hysteria-server; then
    echo -e "\e[32m✅ RUNNING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 2. Check Python Panel Service
echo -n "၂။ Python Web Panel အခြေအနေ: "
if systemctl is-active --quiet hysteria-panel; then
    echo -e "\e[32m✅ RUNNING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 3. Check Nginx Web Server
echo -n "၃။ Nginx Web Server အခြေအနေ: "
if systemctl is-active --quiet nginx; then
    echo -e "\e[32m✅ RUNNING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 4. Check UDP Port 10443
echo -n "၄။ Port 10443 (UDP) ပွင့်/မပွင့်: "
if ss -ulnp | grep -q "10443"; then
    echo -e "\e[32m✅ LISTENING\e[0m"
else
    echo -e "\e[31m❌ NOT LISTENING\e[0m"
fi

# 5. Check Port Hopping (iptables NAT)
echo -n "၅။ Port Hopping (20000-50000) အလုပ်လုပ်/မလုပ်: "
if iptables -t nat -L PREROUTING -n -v | grep -q "dpts:20000:50000 redir ports 10443"; then
    echo -e "\e[32m✅ ACTIVE (Rule ဝင်နေပါသည်)\e[0m"
else
    echo -e "\e[31m❌ MISSING (Rule မရှိပါ)\e[0m"
fi

# 6. Check Auth Backend API
echo -n "၆။ Python Auth API ချိတ်ဆက်မှု: "
AUTH_RES=$(curl -s -X POST http://127.0.0.1:5000/auth -H "Content-Type: application/json" -d "{\"auth\": \"test_check\"}")
if echo "$AUTH_RES" | grep -q "ok"; then
    echo -e "\e[32m✅ RESPONDING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 7. Check Traffic Stats API
echo -n "၇။ Data Usage (Traffic Stats) API: "
if curl -s --max-time 2 http://127.0.0.1:4000/traffic | grep -q "{"; then
    echo -e "\e[32m✅ RESPONDING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 8. Check SSL Certificates
echo -n "၈။ SSL Certificate ဖိုင်များ: "
if [ -d "/etc/letsencrypt/live" ] && [ "$(ls -A /etc/letsencrypt/live | grep -v README)" ]; then
    echo -e "\e[32m✅ FOUND\e[0m"
else
    echo -e "\e[31m❌ MISSING\e[0m"
fi

echo "====================================================="
echo "📜 Hysteria Server ၏ နောက်ဆုံး Log (၁၀) ကြောင်း:"
echo "-----------------------------------------------------"
journalctl -u hysteria-server -n 10 --no-pager
echo "====================================================="
