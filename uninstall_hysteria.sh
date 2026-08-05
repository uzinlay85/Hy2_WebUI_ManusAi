#!/bin/bash

# =============================================================
#  Hysteria 2 + Python Web Panel - 1-Click Clean Uninstall
#  & Verify Script
# =============================================================

echo "🛑 ၁။ Service များကို ရပ်တန့်နေပါသည်..."
systemctl stop hysteria-server hysteria-panel hysteria-webui 2>/dev/null
systemctl disable hysteria-server hysteria-panel hysteria-webui 2>/dev/null

echo "🔪 ၂။ နောက်ကွယ်မှ Process များကို ရှင်းလင်းနေပါသည်..."
pkill -f hysteria 2>/dev/null

echo "🗑️ ၃။ ဖိုင်များနှင့် Folder များကို ဖျက်ပစ်နေပါသည်..."
rm -rf /usr/local/bin/hysteria
rm -rf /etc/hysteria/
rm -rf /opt/hysteria-panel/
rm -rf /opt/hysteria-webui/

echo "🧹 ၄။ Systemd Service အဟောင်းများကို ရှင်းလင်းနေပါသည်..."
rm -f /etc/systemd/system/hysteria-server.service
rm -f /etc/systemd/system/hysteria-panel.service
rm -f /etc/systemd/system/hysteria-webui.service
rm -f /etc/systemd/system/hysteria-server@.service
rm -rf /etc/systemd/system/hysteria-server.service.d

echo "🌐 ၅။ Nginx Config အဟောင်းများကို ဖျက်ပစ်နေပါသည်..."
rm -f /etc/nginx/sites-available/zin_hy2
rm -f /etc/nginx/sites-enabled/zin_hy2
rm -f /etc/nginx/sites-available/hysteria_panel
rm -f /etc/nginx/sites-enabled/hysteria_panel

echo "🔄 ၆။ System ကို Refresh လုပ်နေပါသည်..."
systemctl daemon-reload
systemctl restart nginx

echo ""
echo "====================================================="
echo "✅ ရှင်းလင်းခြင်း ပြီးဆုံးပါပြီ! ရလဒ်များကို စစ်ဆေးနေပါသည်..."
echo "====================================================="

echo "[စစ်ဆေးချက် ၁] Systemd Services (ဘာမှမပေါ်ရပါ):"
ls /etc/systemd/system/ | grep -i hysteria

echo ""
echo "[စစ်ဆေးချက် ၂] ဖိုင်နှင့် Folder များ (ဘာမှမပေါ်ရပါ):"
ls -d /usr/local/bin/hysteria /etc/hysteria/ /opt/hysteria-panel/ /opt/hysteria-webui/ 2>/dev/null

echo ""
echo "[စစ်ဆေးချက် ၃] ပွင့်နေသော Port များ (10443, 5000, 4000) (ဘာမှမပေါ်ရပါ):"
ss -tulnp | grep -E "10443|5000|4000"

echo ""
echo "[စစ်ဆေးချက် ၄] Run နေသော Process များ (grep စာကြောင်း တစ်ကြောင်းသာ ပေါ်ရပါမည်):"
ps aux | grep -i hysteria

echo "====================================================="
echo "🎉 အထက်ပါရလဒ်များ ရှင်းလင်းနေပါက သင့်ဆာဗာသည် 100% Clean ဖြစ်သွားပါပြီ!"
