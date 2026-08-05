# 🚀 Hysteria 2 + Python Web Management Panel

Linux VPS များတွင် **Hysteria 2 VPN** နှင့် **Python (Flask) Web Management Panel** ကို လွယ်ကူလျင်မြန်စွာ တပ်ဆင်၊ စီမံ၊ စစ်ဆေး၊ ပြန်လည်ဖျက်ဆီးနိုင်သော 1-Click Automation Toolkit ဖြစ်ပါသည်။

ဤ Repository တွင် VPN အသုံးပြုသူများ (Users) ကို စီမံရန်၊ Data Limit (GB) သတ်မှတ်ရန်၊ သက်တမ်း (Days) သတ်မှတ်ရန်နှင့် Real-time Traffic Statistics ကို ကြည့်ရှုနိုင်ရန် လိုအပ်သော Script များနှင့် Documentation အပြည့်အစုံ ပါဝင်ပါသည်။

---

## ✨ ပါဝင်သော စနစ်များနှင့် အင်္ဂါရပ်များ (Features)

- 🔐 **Hysteria 2** — မြန်ဆန်စိတ်ချရသော QUIC-based VPN Protocol
- 🖥️ **Web Management Panel** — Python (Flask) ဖြင့် ရေးသားထားသော User Management Web UI
- 👥 **User Management** — User အသစ်ထည့်ခြင်း / ဖျက်ခြင်း
- 📊 **Data Limits** — User တစ်ဦးချင်းစီအတွက် Data Limit (GB) သတ်မှတ်နိုင်ခြင်း (`0` = အကန့်အသတ်မရှိ)
- ⏳ **Expiry Dates** — User တစ်ဦးချင်းစီအတွက် သက်တမ်းရက် (Days) သတ်မှတ်နိုင်ခြင်း (`0` = အကန့်အသတ်မရှိ)
- 🟢 **Real-time Status Badges** — Active / Expired / Data Full / 🟢 Online / ⚪ Offline အခြေအနေများ ပြသပေးခြင်း
- 📈 **Traffic Statistics** — Hysteria trafficStats API မှတစ်ဆင့် Real-time Data သုံးစွဲမှုကို ပြသပေးခြင်း
- 🎯 **Port Hopping** — **nftables** ဖြင့် စိတ်ချရသော UDP Port Hopping (20000-50000) စနစ်
- 🛡️ **Anti-DPI Obfuscation** — Salamander obfs + HTTPS masquerade (Bing) ဖြင့် VPN Traffic ကို ဖုံးကွယ်ခြင်း
- ⚡ **Performance Tuning** — QUIC performance တိုးမြှင့်ရန် UDP Buffer ကို Tuning ပြုလုပ်ထားခြင်း
- 🔒 **Security Hardening** — trafficStats secret Auth + IPv4/IPv6 private IP range များကို ပိတ်ပင်ထားခြင်း
- 🔒 **SSL/TLS** — Certbot မှတစ်ဆင့် Let's Encrypt SSL Certificate ကို အလိုအလျောက် ရယူပေးခြင်း
- 🧹 **1-Click Uninstall** — Component များအားလုံးကို ရှင်းလင်းစွာ ဖျက်ဆီးပေးခြင်း

---

## ⚡ ၁ ချက်နှိပ် Command များ (Quick Commands)

VPS Terminal တွင် အောက်ပါ Command တစ်ကြောင်းကို Copy ကူးပြီး Paste ချကာ run နိုင်ပါသည်။

| လုပ်ဆောင်ချက် | 1-Line Command |
| :--- | :--- |
| **🚀 Install** (တပ်ဆင်ရန်) | `wget -O install.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/install_hysteria.sh && bash install.sh` |
| **🔍 Check** (စစ်ဆေးရန်) | `wget --no-cache -O check.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/check_hysteria.sh?$(date +%s)" && bash check.sh` |
| **🧹 Uninstall** (ဖျက်ရန်) | `wget -O uninstall.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/uninstall_hysteria.sh && bash uninstall.sh` |

---

## 🚀 စတင်တပ်ဆင်နည်း (Installation)

### လိုအပ်ချက်များ (Prerequisites)
1. Linux VPS (Ubuntu 20.04 / 22.04 / 24.04 သို့မဟုတ် Debian 11 / 12)
2. သင့် VPS IP သို့ ချိတ်ဆက်ထားသော Domain Name (DNS A Record point လုပ်ထားရမည်)
3. Root access (သို့မဟုတ် Sudo privileges)

### တပ်ဆင်ပုံ အဆင့်ဆင့်
၁။ Terminal တွင် အောက်ပါ command ကို Run ပါ -
```bash
wget -O install.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/install_hysteria.sh && bash install.sh
```
၂။ မေးခွန်းတွင် သင့် Domain Name (ဥပမာ - `hy2.yourdomain.com`) ကို ရိုက်ထည့်ပါ။  
၃။ တပ်ဆင်ခြင်း ပြီးစီးပါက **Web UI Link**၊ **Admin Password** နှင့် **OBFS Password** များကို ပြသပေးပါလိမ့်မည်။

---

## 🖥️ Web Panel အသုံးပြုနည်း

တပ်ဆင်ပြီးပါက Browser တွင် `https://yourdomain.com` သို့ ဝင်ရောက်ပါ။

- **Default Admin Password:** `admin123`
- **စတင် ဝင်ရောက်ပြီးသည်နှင့် Settings box မှတစ်ဆင့် Admin Password ကို ချက်ချင်း ပြောင်းလဲပါ။**

### User အသစ်ထည့်ခြင်း
1. **📝 Name**: User နာမည် ရိုက်ထည့်ပါ
2. **👤 Password**: Password ရိုက်ထည့်ပါ (စာလုံးနှင့် ဂဏန်းများ သီးသန့် သုံးရန် အကြံပြုပါသည်)
3. **Data Limit (GB)**: အသုံးပြုနိုင်မည့် Data အကန့်အသတ် (GB) (`0` ဆိုပါက အကန့်အသတ်မရှိ)
4. **Days**: အသုံးပြုနိုင်မည့် ရက်ပေါင်း (`0` ဆိုပါက အကန့်အသတ်မရှိ)
5. **➕ Add User** ကို နှိပ်ပါ
6. ထွက်လာသော **Client URL** ကို `📋 Copy URL` နှိပ်၍ Client App (Happ, Nekobox, v2raytun, Hiddify, v2rayN) များတွင် ထည့်သွင်းသုံးစွဲပါ။

---

## 🧐 ဖိုင်များကို `cat` ဖြင့် စစ်ဆေးခြင်း (Config File Inspection)

စနစ် အလုပ်လုပ်ပုံ သို့မဟုတ် Configuration များကို တိုက်ရိုက် စစ်ဆေးလိုပါက VPS Terminal တွင် အောက်ပါ `cat` command များကို သုံး၍ စစ်ဆေးနိုင်ပါသည်-

### ၁။ Hysteria 2 Server Config ကို စစ်ဆေးရန်
```bash
cat /etc/hysteria/config.yaml
```

### ၂။ Python Web Panel App Code ကို စစ်ဆေးရန်
```bash
cat /opt/hysteria-panel/app.py
```

### ၃။ Python Panel Systemd Service ကို စစ်ဆေးရန်
```bash
cat /etc/systemd/system/hysteria-panel.service
```

### ၄။ Nginx Reverse Proxy Config ကို စစ်ဆေးရန်
```bash
cat /etc/nginx/sites-available/hysteria_panel
```

### ၅။ Port Hopping nftables Firewall Rule ကို စစ်ဆေးရန်
```bash
cat /etc/nftables.d/hysteria.nft
```

---

## 📊 တစ်ခုချင်းစီ သီးသန့် Manual စစ်ဆေး/စောင့်ကြည့်နည်းများ (Manual Monitoring & Diagnostics)

စနစ်တစ်ခုချင်းစီ၏ အခြေအနေ၊ Log များနှင့် API တုံ့ပြန်မှုများကို Manual စစ်ဆေးလိုပါက အောက်ပါ Command များကို သီးသန့် ရိုက်နှိပ် စစ်ဆေးနိုင်ပါသည်။

### 1. Hysteria 2 Server အခြေအနေနှင့် Log များ စစ်ဆေးရန်
```bash
# Service Status စစ်ရန်
systemctl status hysteria-server

# Log နောက်ဆုံး ၂၀ ကြောင်း ကြည့်ရန်
journalctl -u hysteria-server -n 20 --no-pager

# Live Log များကို Real-time စောင့်ကြည့်ရန် (Ctrl + C ဖြင့် ထွက်ရန်)
journalctl -u hysteria-server -f
```

### 2. Python Web Panel အခြေအနေနှင့် Log များ စစ်ဆေးရန်
```bash
# Service Status စစ်ရန်
systemctl status hysteria-panel

# Log နောက်ဆုံး ၂၀ ကြောင်း ကြည့်ရန်
journalctl -u hysteria-panel -n 20 --no-pager

# Live Log များကို Real-time စောင့်ကြည့်ရန် (Ctrl + C ဖြင့် ထွက်ရန်)
journalctl -u hysteria-panel -f
```

### 3. Nginx Web Server အခြေအနေနှင့် Syntax စစ်ဆေးရန်
```bash
# Status စစ်ရန်
systemctl status nginx

# Nginx Config Syntax အမှားပါမပါ စစ်ရန်
nginx -t
```

### 4. UDP Port 10443 Listening ဟုတ်/မဟုတ် စစ်ဆေးရန်
```bash
ss -ulnp | grep 10443
```

### 5. Port Hopping (20000-50000) nftables NAT Rule စစ်ဆေးရန်
```bash
nft list table ip hysteria_nat
```

### 6. Python Auth API (`/auth`) တုံ့ပြန်မှု စစ်ဆေးရန်
```bash
curl -s -X POST http://127.0.0.1:5000/auth -H "Content-Type: application/json" -d '{"auth": "test_user"}'
```

### 7. Traffic Stats API (`/traffic`) တုံ့ပြန်မှု စစ်ဆေးရန်
```bash
SECRET=$(grep "secret:" /etc/hysteria/config.yaml | tail -1 | awk '{print $2}')
curl -s -H "Authorization: $SECRET" "http://127.0.0.1:4000/traffic"
```

### 8. Online Clients API (`/online`) လက်ရှိ ချိတ်ဆက်သူများ စစ်ဆေးရန်
```bash
SECRET=$(grep "secret:" /etc/hysteria/config.yaml | tail -1 | awk '{print $2}')
curl -s -H "Authorization: $SECRET" "http://127.0.0.1:4000/online"
```

### 9. Let's Encrypt SSL Certificate သက်တမ်းနှင့် ဖိုင်များ စစ်ဆေးရန်
```bash
# Certificate ဖိုင်များ စစ်ရန်
ls -la /etc/letsencrypt/live/

# SSL Certificate သက်တမ်း စစ်ရန်
certbot certificates
```

### 10. SQLite Database ထဲရှိ Users စာရင်း စစ်ဆေးရန်
```bash
sqlite3 /opt/hysteria-panel/users.db "SELECT * FROM users;"
```

---

## 🔍 စနစ်တစ်ခုလုံးကို အလိုအလျောက် စစ်ဆေးခြင်း (Auto Checker)

ပြဿနာတစ်စုံတစ်ရာ ရှိမရှိ အောက်ပါ Command ဖြင့် ၁ ချက်တည်း အလိုအလျောက် စစ်ဆေးနိုင်ပါသည်။

```bash
wget --no-cache -O check.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/check_hysteria.sh?$(date +%s)" && bash check.sh
```

---

## 🧹 ဖျက်ဆီးခြင်း (Uninstall)

ဆာဗာမှ Hysteria 2 နှင့် Python Panel အပါအဝင် ဖိုင်များ၊ Service များ၊ Config များကို လုံးဝ သန့်ရှင်းစွာ ဖျက်ပစ်လိုပါက အောက်ပါ Command ကို ရိုက်ပါ-

```bash
wget -O uninstall.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/uninstall_hysteria.sh && bash uninstall.sh
```

---

## 📁 Repository ဖိုင်ဖွဲ့စည်းပုံ (Structure)

```
Hy2_WebUI_ManusAi/
├── README.md                     ← ဤ Documentation ဖိုင်
├── install_hysteria.sh           ← 1-Click Auto Setup Script (v4.0)
├── uninstall_hysteria.sh         ← 1-Click Clean Uninstall Script
├── check_hysteria.sh             ← 1-Click Auto Checker Script (v2.2)
├── requirements.txt              ← Python dependencies
├── panel/
│   └── app.py                    ← Flask Web Panel backend code
├── config/
│   ├── config.yaml               ← Hysteria 2 server configuration
│   ├── hysteria-panel.service    ← Systemd service configuration
│   └── nginx_hysteria_panel      ← Nginx reverse proxy configuration
└── docs/
    ├── setup-guide-v2.md         ← အသေးစိတ် လက်ဖြင့် ပြင်ဆင်နည်း Guide
    └── troubleshooting.md        ← ပြဿနာဖြေရှင်းနည်းများ Guide
```

---

## 🤝 ကူညီထောက်ပံ့မှု (Support)

ပြဿနာ တစ်စုံတစ်ရာ ရှိပါက Auto Checker Script သို့မဟုတ် သီးသန့် Manual Command များဖြင့် စစ်ဆေးနိုင်ပါသည်။
