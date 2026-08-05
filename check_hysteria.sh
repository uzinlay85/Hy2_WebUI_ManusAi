#!/bin/bash

# =============================================================
#  Hysteria 2 + Python Web Panel - 1-Click Auto Checker Script
# =============================================================

echo "====================================================="
echo "🔍 Hysteria 2 အလိုအလျောက် စစ်ဆေးရေးစနစ် စတင်နေပါသည်..."
echo "====================================================="

# 1. Check Hysteria Service
echo -n "၁။ Hysteria Server အခြေအနေ: "
if systemctl is-active --quiet hysteria-server; then
    echo -e "\e[32m✅ RUNNING (အလုပ်လုပ်နေပါသည်)\e[0m"
else
    echo -e "\e[31m❌ FAILED (ရပ်တန့်နေပါသည်)\e[0m"
fi

# 2. Check Python Panel Service
echo -n "၂။ Python Web Panel အခြေအနေ: "
if systemctl is-active --quiet hysteria-panel; then
    echo -e "\e[32m✅ RUNNING (အလုပ်လုပ်နေပါသည်)\e[0m"
else
    echo -e "\e[31m❌ FAILED (ရပ်တန့်နေပါသည်)\e[0m"
fi

# 3. Check UDP Port 10443
echo -n "၃။ Port 10443 (UDP) ပွင့်/မပွင့်: "
if ss -ulnp | grep -q "10443"; then
    echo -e "\e[32m✅ LISTENING (ပွင့်နေပါသည်)\e[0m"
else
    echo -e "\e[31m❌ NOT LISTENING (ပိတ်နေပါသည်)\e[0m"
fi

# 4. Check Auth Backend API
echo -n "၄။ Python Auth API ချိတ်ဆက်မှု: "
AUTH_RES=$(curl -s -X POST http://127.0.0.1:5000/auth -H "Content-Type: application/json" -d "{\"auth\": \"test_check\"}")
if echo "$AUTH_RES" | grep -q "ok"; then
    echo -e "\e[32m✅ RESPONDING (ချိတ်ဆက်မှု ရရှိပါသည်)\e[0m"
else
    echo -e "\e[31m❌ FAILED (ချိတ်ဆက်၍ မရပါ)\e[0m"
fi

# 5. Check SSL Certificates
DOMAIN="${1:-hy2-bear.truehand.top}"
echo -n "၅။ SSL Certificate ဖိုင်များ: "
if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo -e "\e[32m✅ FOUND (တွေ့ရှိပါသည်)\e[0m"
else
    echo -e "\e[31m❌ MISSING (ရှာမတွေ့ပါ - SSL မရရှိသေးပါ)\e[0m"
fi

echo "====================================================="
echo "📜 Hysteria Server ၏ နောက်ဆုံး Log (၁၀) ကြောင်း:"
echo "-----------------------------------------------------"
journalctl -u hysteria-server -n 10 --no-pager
echo "====================================================="
