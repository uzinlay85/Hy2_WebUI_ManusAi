# 🚀 New Server Complete Setup & Hardening Master Guide

> ဆာဗာအသစ် (New Linux VPS) တစ်ခု စတင်ဝယ်ယူပြီးတိုင်း **Hysteria 2 VPN၊ Web Management Panel၊ လုံခြုံရေး အပြည့်အဝ မြှင့်တင်ခြင်း (Security Hardening)၊ ၂၄/၇ Watchdog နှင့် စစ်ဆေးရေး Tools များ** အားလုံးကို အဆင့်ဆင့် စနစ်တကျ တပ်ဆင်အသုံးပြုနိုင်သည့် **Master Roadmap Guide** ဖြစ်ပါသည်။

---

## 🧭 ဆာဗာအသစ် တည်ဆောက်ခြင်း အဆင့် (၅) ဆင့် (Overview)

```
┌────────────────────────────────────────────────────────────────────────┐
│             🌟 NEW VPS DEPLOYMENT & HARDENING ROADMAP                  │
├────────────────────────────────────────────────────────────────────────┤
│ အဆင့် ၁ - Domain & DNS ကြိုတင် ပြင်ဆင်ခြင်း (Cloudflare DNS Only)        │
│ အဆင့် ၂ - 1-Click Hysteria 2 + Web Panel တပ်ဆင်ခြင်း (install.sh)       │
│ အဆင့် ၃ - 1-Click Server Hardening & Security Auto-Fix (harden.sh)     │
│ အဆင့် ၄ - 24/7 Watchdog Auto-Restart Monitoring ထည့်သွင်းခြင်း         │
│ အဆင့် ၅ - 24h Enterprise Security & Activity Suite (report24) တပ်ဆင်ခြင်း│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 အဆင့် (၁) - Domain & DNS ကြိုတင် ပြင်ဆင်ခြင်း

1. မိမိပိုင်ဆိုင်သော Domain Name (ဥပမာ `yourdomain.com` သို့မဟုတ် `hy2.yourdomain.com`) တွင် **DNS A Record** ပြုလုပ်ပါ:
   - **Type:** `A`
   - **Name:** `hy2` (သို့မဟုတ် မိမိကြိုက်နှစ်သက်ရာ Subdomain)
   - **IPv4 Address:** သင့် VPS ၏ Public IP
   - **Proxy status:** **DNS Only (Grey Cloud 🔘)** ဖြစ်ရပါမည်။ *(Cloudflare 🟧 Proxy ဖွင့်မထားရပါ)*
2. DNS Record ချိတ်ဆက်မှု အောင်မြင်စေရန် ၁ မိနစ်ခန့် စောင့်ပါ။

---

## 🚀 အဆင့် (၂) - 1-Click Hysteria 2 + Web Panel တပ်ဆင်ခြင်း

ဆာဗာ Terminal (Xshell / Putty / SSH) ထဲတွင် အောက်ပါ Command ကို Copy ကူးပြီး Run ပါ:

```bash
wget -O install.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/install_hysteria.sh && bash install.sh
```

### 📋 မေးခွန်းများ ဖြေဆိုရန်:
* **Domain Name:** မိမိ Subdomain (ဥပမာ - `hy2.yourdomain.com`) ကို ရိုက်ထည့်ပါ။
* **Port:** Default Port `10443` အတိုင်းထားရန် **Enter** သာ နှိပ်ပါ။

> 🎉 တပ်ဆင်ပြီးပါက **Web UI Link (`https://yourdomain.com`)** နှင့် **Default Password (`admin123`)** ကို ပြသပေးပါမည်။ Web UI သို့ ဝင်ရောက်ပြီး Admin Password ကို ချက်ချင်း အသစ်ပြောင်းလဲပါ။

---

## 🛡️ အဆင့် (၃) - 1-Click Server Hardening & Security Auto-Fix

တိုက်ခိုက်သူများ အဓိက ပစ်မှတ်ထားသော **Port 22 ကို လုံးဝပိတ်ခြင်း၊ Port 2213 သီးသန့် ထားရှိခြင်း၊ Root Login ကန့်သတ်ခြင်း၊ UFW Firewall နှင့် Fail2Ban ချိတ်ဆက်ခြင်း၊ Anti-DDoS ဖွင့်ခြင်း** တို့ကို ၁ ချက်တည်း ပြုလုပ်ရန်:

```bash
wget --no-cache -O harden.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/harden.sh?$(date +%s)" && sudo bash harden.sh
```

> ⚠️ **သတိပြုရန်:** ဤအဆင့်ပြီးပါက နောင်အကြိမ်များတွင် ဆာဗာသို့ SSH ဝင်ရောက်သည့်အခါ **Port `2213`** (ဥပမာ `ssh username@IP -p 2213`) ဖြင့်သာ ဝင်ရောက်ရမည်ဖြစ်ပါသည်။

---

## 🐶 အဆင့် (၄) - 24/7 Watchdog Auto-Restart စနစ် ထည့်သွင်းခြင်း

ဆာဗာ Services များ (Hysteria 2၊ Web Panel၊ Nginx) တစ်ခုခု Crash ဖြစ်သွားပါက ချက်ချင်း Auto-Restart လုပ်ပေးနိုင်ရန် Watchdog စနစ်ကို ထည့်ပါ:

```bash
cat > /usr/local/bin/hy2-watchdog << 'EOF'
#!/bin/bash
LOG="/var/log/hy2-watchdog.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
ALL_OK=true

for svc in hysteria-server hy2-panel nginx; do
    if ! systemctl is-active --quiet $svc; then
        systemctl restart $svc
        echo "[$DATE] ⚠️  $svc was DOWN - Auto Restarted" >> $LOG
        ALL_OK=false
    fi
done

if $ALL_OK && [ $(date +%M) = "00" ]; then
    echo "[$DATE] ✅ All services OK" >> $LOG
fi

tail -500 $LOG > ${LOG}.tmp 2>/dev/null && mv ${LOG}.tmp $LOG 2>/dev/null || true
EOF

chmod +x /usr/local/bin/hy2-watchdog
crontab -l 2>/dev/null | grep -v "hy2-watchdog" | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/hy2-watchdog") | crontab -
echo "✅ 24/7 Watchdog installed and active!"
```

---

## 📊 အဆင့် (၅) - Enterprise Security & 24h Report Tool (`report24`) တပ်ဆင်ခြင်း

နေ့စဉ် ဆာဗာလုံခြုံရေး ရမှတ် (Security Score 100/100) နှင့် ၂၄ နာရီအတွင်း သုံးစွဲမှု အစီရင်ခံစာကို အချိန်မရွေး ကြည့်ရှုနိုင်ရန် Tool ကို တပ်ဆင်ပါ:

```bash
sudo curl -fsSL "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh" -o /usr/local/bin/report24 && sudo chmod +x /usr/local/bin/report24
```

> ✅ တပ်ဆင်ပြီးပါက **`report24`** ဟု ရိုက်လိုက်ရုံဖြင့် အစီရင်ခံစာ အပြည့်အစုံကို ထုတ်ပေးပါမည်!

```bash
report24
```

---

## ⚡ အချိန်မရှိသူများအတွက် - အဆင့် (၃, ၄, ၅) ကို ၁ ချက်တည်း အပြီးသတ် Run ရန် (Quick Bundle)

အဆင့် (၂) Install ပြီးသည်နှင့် အောက်ပါ Command တစ်ကြောင်းတည်းကို Copy ကူးပြီး Paste ချလိုက်ပါက Hardening၊ Watchdog နှင့် Report Tool အားလုံး တစ်ပြိုင်တည်း ပြီးစီးသွားပါမည်:

```bash
wget --no-cache -O harden.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/harden.sh?$(date +%s)" && sudo bash harden.sh && sudo wget --no-cache -O /usr/local/bin/report24 "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh?$(date +%s)" && sudo chmod +x /usr/local/bin/report24 && cat > /usr/local/bin/hy2-watchdog << 'EOF'
#!/bin/bash
LOG="/var/log/hy2-watchdog.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
ALL_OK=true
for svc in hysteria-server hy2-panel nginx; do
    if ! systemctl is-active --quiet $svc; then
        systemctl restart $svc
        echo "[$DATE] ⚠️  $svc was DOWN - Auto Restarted" >> $LOG
        ALL_OK=false
    fi
done
if $ALL_OK && [ $(date +%M) = "00" ]; then echo "[$DATE] ✅ All services OK" >> $LOG; fi
tail -500 $LOG > ${LOG}.tmp 2>/dev/null && mv ${LOG}.tmp $LOG 2>/dev/null || true
EOF
chmod +x /usr/local/bin/hy2-watchdog && crontab -l 2>/dev/null | grep -v "hy2-watchdog" | crontab - && (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/hy2-watchdog") | crontab - && echo "🎉 ဆာဗာအသစ် Setup & Hardening အားလုံး ၁၀၀% ပြီးစီးပါပြီ!" && report24
```

---

## 📋 နေ့စဉ် / အပတ်စဉ် စစ်ဆေးထိန်းသိမ်းနည်းများ (Maintenance Checklist)

| အကြိမ်ရေ | Command | အသုံးပြုပုံ |
|:---|:---|:---|
| **နေ့စဉ်** | `report24` | လုံခြုံရေးရမှတ် (100/100)၊ တိုက်ခိုက်ခံရမှုနှင့် ၂၄ နာရီအတွင်း သုံးစွဲသူစာရင်း စစ်ဆေးရန် |
| **ပြဿနာရှိချိန်** | `audit` | Service များ၊ Port များနှင့် SSL သက်တမ်းကို ချက်ချင်း အသေးစိတ် စစ်ဆေးရန် |
| **အဆင့်မြှင့်တင်ရန်** | `update.sh` | Hysteria Core Engine သစ်နှင့် Web Panel Code သစ်များကို 1-Click Update လုပ်ရန် |

---

## 📜 ဆက်စပ် Documentation များ

| ဖိုင်အမည် | အကြောင်းအရာ |
|:---|:---|
| 📖 [README.md](README.md) | Main Project Overview & 1-Click Commands |
| 🚀 [NEW_SERVER_GUIDE.md](NEW_SERVER_GUIDE.md) | **ဆာဗာအသစ် Master Setup Guide (ဤဖိုင်)** |
| 🛡️ [REPORT24.md](REPORT24.md) | Enterprise Security Audit & 24h Activity Suite |
| 🔍 [AUDIT.md](AUDIT.md) | Server Full Health Audit Guide |
| 🐶 [WATCHDOG.md](WATCHDOG.md) | 24/7 Watchdog Monitoring System Guide |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
