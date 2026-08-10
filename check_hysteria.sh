#!/bin/bash

# =============================================================
#  Hysteria 2 + Python Web Panel - 1-Click Auto Checker Script
#  Version 2.2 - Robust secret extraction + HTTP status check
# =============================================================

echo "====================================================="
echo "🔍 Hysteria 2 အလိုအလျောက် စစ်ဆေးရေးစနစ် (v2.2)"
echo "====================================================="

# ---------------------------------------------------------------------------
# Extract STATS_SECRET robustly using awk, then URL-encode it for curl
# (+ in secrets becomes space in query params unless encoded as %2B)
# ---------------------------------------------------------------------------
STATS_SECRET=""
APP_PY="/opt/hysteria-panel/app.py"
CONFIG_YAML="/etc/hysteria/config.yaml"

if [ -f "$APP_PY" ]; then
    STATS_SECRET=$(grep "^STATS_SECRET" "$APP_PY" | head -1 | awk -F"'" '{print $2}')
fi

# Fallback: read from hysteria config.yaml
if [ -z "$STATS_SECRET" ] && [ -f "$CONFIG_YAML" ]; then
    STATS_SECRET=$(grep "secret:" "$CONFIG_YAML" | tail -1 | awk '{print $2}')
fi

# URL-encode the secret (handles + → %2B, etc.) using Python3
if [ -n "$STATS_SECRET" ]; then
    ENCODED_SECRET=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$STATS_SECRET" 2>/dev/null)
else
    ENCODED_SECRET=""
fi

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

PORT="10443"
if [ -f "$CONFIG_YAML" ]; then
    DETECTED_PORT=$(grep "listen:" "$CONFIG_YAML" | head -n 1 | awk -F':' '{print $NF}' | tr -d ' ')
    if [ -n "$DETECTED_PORT" ]; then
        PORT="$DETECTED_PORT"
    fi
fi

# 4. Check UDP Port
echo -n "၄။ Port $PORT (UDP) ပွင့်/မပွင့်: "
if ss -ulnp | grep -q ":$PORT "; then
    echo -e "\e[32m✅ LISTENING\e[0m"
else
    echo -e "\e[31m❌ NOT LISTENING\e[0m"
fi

# 5. Check Single Port Mode
echo -n "၅။ Single Port Mode ($PORT): "
echo -e "\e[32m✅ ACTIVE (Single Main Port Only)\e[0m"

# 6. Check Auth Backend API
echo -n "၆။ Python Auth API ချိတ်ဆက်မှု: "
AUTH_RES=$(curl -s -X POST http://127.0.0.1:5000/auth -H "Content-Type: application/json" -d "{\"auth\": \"test_check\"}")
if echo "$AUTH_RES" | grep -q "ok"; then
    echo -e "\e[32m✅ RESPONDING\e[0m"
else
    echo -e "\e[31m❌ FAILED\e[0m"
fi

# 7. Check Traffic Stats API — send secret via Authorization header
echo -n "၇။ Data Usage (Traffic Stats) API: "
if [ -n "$STATS_SECRET" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 \
        -H "Authorization: ${STATS_SECRET}" \
        "http://127.0.0.1:4000/traffic")
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "\e[32m✅ RESPONDING (HTTP 200)\e[0m"
    else
        echo -e "\e[31m❌ FAILED (HTTP $HTTP_CODE)\e[0m"
        echo "   ↳ Secret used: ${STATS_SECRET:0:8}..."
    fi
else
    echo -e "\e[31m❌ FAILED (secret ကို $APP_PY မှ ဖတ်မရပါ)\e[0m"
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
