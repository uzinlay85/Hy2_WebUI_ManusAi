# 🛡️ Enterprise Linux Security Audit, Multi-VPN Inspector & 24h Report (v5.0)

> Linux System Administrator & DevSecOps Security Engineer တစ်ဦး၏ စံနှုန်းများအတိုင်း **ဆာဗာလုံခြုံရေး အားနည်းချက်များ (Vulnerabilities)၊ တပ်ဆင်ထားသမျှ Multi-VPN စနစ်များ (Hysteria 2, AmneziaWG, VLESS / 3X-UI, Outline, WireGuard) ၏ Ports & Error Status၊ ၂၄ နာရီအတွင်း ဖြစ်ပျက်ခဲ့သမျှ မှတ်တမ်းများနှင့် လုံခြုံရေး အဆင့်သတ်မှတ်ချက် (Security Score 100/100)** တို့ကို အလိုအလျောက် စစ်ဆေးပြီး **၁ ချက်တည်း Auto-Fix ပြင်ဆင်ပေးနိုင်သော** Enterprise-Grade Security Suite ဖြစ်ပါသည်။

---

## 🔍 စစ်ဆေးပေးသော အဓိက အပိုင်းများ

```
┌────────────────────────────────────────────────────────────────────────┐
│             🌐 ALL-IN-ONE MULTI-VPN & SECURITY AUDIT SUITE             │
├────────────────────────────────────────────────────────────────────────┤
│ 1. ⏱️ 24h System Health & Uptime (Reboot/Crash Check)                   │
│ 2. 🌐 Multi-VPN Auto-Discovery (Hy2, AmneziaWG, VLESS/Xray, Outline)   │
│ 3. 🔐 SSH & Access Hardening (Port 2213, Root Login, Empty Passwords) │
│ 4. 🧱 Attack Surface & Ports (Exposed Internal APIs, UFW Policy)       │
│ 5. 🚨 Intrusion Detection (Fail2Ban Jails, 24h Brute-force Attacks)    │
│ 6. ⚡ Anti-DDoS & Kernel Hardening (SYN Cookies, BBR Optimization)     │
│ 7. 📦 System Patches & SSL Expiry (Pending CVEs, SSL Days Remaining)   │
│ 8. 🏆 DevSecOps Security Score (0-100) & Interactive 1-Click Auto-Fix  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ တပ်ဆင်ခြင်းနှင့် အသုံးပြုနည်းများ (Usage)

### နည်းလမ်း (၁) - `report24` ဟု အမြဲတမ်း ရိုက်စစ်နိုင်အောင် ဆာဗာထဲ တပ်ဆင်နည်း (Recommended 🌟)

ဆာဗာထဲတွင် အောက်ပါ Command ကို **တစ်ကြိမ်သာ** Run ပေးပါ:

```bash
sudo wget --no-cache -O /usr/local/bin/report24 "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh?$(date +%s)" && sudo sed -i 's/\r$//' /usr/local/bin/report24 && sudo chmod +x /usr/local/bin/report24
```

> ✅ တပ်ဆင်ပြီးပါက အောက်ပါ Command များကို သုံးနိုင်ပါသည်-

```bash
# ၁။ စစ်ဆေးပြီး အားနည်းချက်တွေ့ပါက Auto-Fix ပြင်မလားဟု မေးမြန်းပေးမည့်ပုံစံ:
report24

# ၂။ စစ်ဆေးပြီး အားနည်းချက်အားလုံးကို မေးခွန်းမမေးဘဲ တိုက်ရိုက် Auto-Fix လုပ်မည့်ပုံစံ:
report24 --fix
```

---

### နည်းလမ်း (၂) - တပ်ဆင်စရာမလိုဘဲ ၁ ချက်နှိပ် တိုက်ရိုက် ကြည့်နည်း (Quick 1-Line)

```bash
wget --no-cache -O report24.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh?$(date +%s)" && bash report24.sh
```

---

## 📊 Output ဖတ်နည်းနှင့် လုံခြုံရေး စံနှုန်းများ

### [1] SSH & Access Hardening
- **Custom SSH Port**: Default Port 22 အစား Port 2213 စသည့် Custom Port သုံးထားခြင်း ရှိမရှိ စစ်ဆေးသည်။ (Bot Attack ၉၀% လျှော့ချနိုင်သည်)
- **PermitRootLogin**: Root အကောင့်ဖြင့် တိုက်ရိုက် ဝင်ရောက်မှုကို ကန့်သတ်ထားခြင်း ရှိမရှိ စစ်ဆေးသည်။
- **Empty Passwords**: စနစ်အတွင်း Password မပါသော အန္တရာယ်ရှိ အကောင့်များ ရှိမရှိ စစ်ဆေးသည်။

### [2] Attack Surface & Internal Port Binding
- **Port 8888 (Web Panel)** နှင့် **Port 4000 (Traffic Stats API)** တို့သည် `127.0.0.1` (Localhost) တွင်သာ လုံခြုံစွာ Bind လုပ်ထားခြင်း ရှိမရှိ စစ်ဆေးသည်။ (ပြင်ပမှ တိုက်ရိုက် Hack မရအောင် ကာကွယ်ထားခြင်း)
- **UFW Firewall**: Firewall Active ဖြစ်မဖြစ် စစ်ဆေးသည်။

### [3] Intrusion Detection & 24h Attack Analytics
- **Fail2Ban**: လက်ရှိ Block ထားသော Attacker IP အရေအတွက်နှင့် ၂၄ နာရီအတွင်း ဖမ်းဆီးခဲ့သော Hacker IP များကို ပြသပေးသည်။
- **Failed Password Count**: ၂၄ နာရီအတွင်း Password မှားယွင်းရိုက်နှိပ်ပြီး Brute-force စမ်းသပ်မှု အကြိမ်ရေကို စောင့်ကြည့်သည်။

### [4] Anti-DDoS & Kernel Hardening
- **TCP SYN Cookies (`net.ipv4.tcp_syncookies = 1`)**: SYN Flood DDoS တိုက်ခိုက်မှုကို ကာကွယ်ပေးထားခြင်း ရှိမရှိ စစ်ဆေးသည်။
- **BBR Congestion Control**: အင်တာနက် အမြန်နှုန်း အမြင့်ဆုံး ရရှိစေရန် Google BBR စနစ် ပွင့်မပွင့် စစ်ဆေးသည်။

### [5] VPN & Web Panel Security
- **Default Admin Password**: Web Panel Admin Password သည် မူလ Default `admin123` အတိုင်း ဖြစ်နေပါက အနီရောင် သတိပေးချက် ပြသပြီး အမှတ်လျှော့ချမည်။

---

## 🏆 DevSecOps Security Score & Rating စံနှုန်းများ

| ရမှတ် (Score) | အဆင့်အတန်း (Rating) | အဓိပ္ပာယ် |
|:---:|:---:|:---|
| **90 - 100** | **Grade A+** 🟢 | **Enterprise Hardened** — လုံခြုံရေး အလွန် ခိုင်မာပြီး တိုက်ခိုက်မှုများကို အပြည့်အဝ ကာကွယ်ထားသည် |
| **80 - 89** | **Grade A** 🟢 | **Secure & Stable** — စံချိန်မီ လုံခြုံမှုရှိသည် |
| **70 - 79** | **Grade B** 🟡 | **Moderate** — တိုးတက်ပြင်ဆင်ရန် လိုအပ်သော အားနည်းချက် အချို့ရှိသည် |
| **< 70** | **Grade C / High Risk** 🔴 | **Action Required** — ဆာဗာ တိုက်ခိုက်ခံရနိုင်ခြေ မြင့်မားနေသည် (ချက်ချင်း ပြင်ဆင်ရန် လိုသည်) |

---

## 🛠️ Security အားနည်းချက်များ တွေ့ရှိပါက ဖြေရှင်းနည်းများ (Hardening Guide)

### ၁။ Default Port 22 မှ Custom Port သို့ ပြောင်းလဲခြင်း
```bash
# Port 2213 သို့ ပြောင်းရန်
sudo sed -i 's/^#*Port .*/Port 2213/' /etc/ssh/sshd_config
sudo ufw allow 2213/tcp
sudo systemctl restart sshd
```

### ၂။ Root Login ကို ကန့်သတ်ခြင်း
```bash
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### ③ SYN Flood Anti-DDoS ဖွင့်ခြင်း
```bash
echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### ④ Fail2Ban တပ်ဆင်ပြီး ဖွင့်ခြင်း
```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

---

## 📜 Documentation Links

| စာမျက်နှာ | အကြောင်းအရာ |
|:---|:---|
| 📖 [README.md](README.md) | Main Installation Guide |
| 🔍 [AUDIT.md](AUDIT.md) | Full Server Health Audit v2.1 |
| 🛡️ [WATCHDOG.md](WATCHDOG.md) | 24/7 Watchdog Auto-Restart System |
| 📊 [REPORT24.md](REPORT24.md) | **Enterprise Security Audit & 24h Report (ဤဖိုင်)** |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
