# 📊 VPS 24-Hour Activity & Health Report Tool

> **Linux VPS & Hysteria 2 Server** ၏ လွန်ခဲ့သော **၂၄ နာရီအတွင်း ဖြစ်ပျက်ခဲ့သမျှ အားလုံး** (Uptime၊ Reboot၊ VPN ချိတ်ဆက်မှု၊ သုံးစွဲသူများ၊ လုံခြုံရေးတိုက်ခိုက်မှုများနှင့် စနစ် Error များ) ကို တစ်ချက်တည်း စစ်ဆေးနိုင်သော Diagnostic Tool ဖြစ်ပါသည်။

---

## 📋 စစ်ဆေးပေးသော အချက်များ

| # | Section | စစ်ဆေးချက် |
|:---:|:---|:---|
| 1 | **⏱️ Uptime & Reboot** | ၂၄ နာရီအတွင်း Server Restart/Reboot ဖြစ်ခဲ့ခြင်း ရှိမရှိ |
| 2 | **🛡️ Watchdog Downtime** | Hysteria 2, Web Panel, Nginx တို့ ရပ်တန့်ခဲ့ဖူးခြင်း ရှိမရှိ |
| 3 | **👥 VPN Activity** | ၂၄ နာရီအတွင်း VPN ချိတ်ဆက်မှု အကြိမ်ရေ၊ Disconnect အကြိမ်ရေနှင့် User အလိုက် အသုံးပြုမှု |
| 4 | **🔐 Security Check** | အောင်မြင်သော SSH Logins များနှင့် Fail2Ban မှ Block လုပ်ခဲ့သော Attacker IP များ |
| 5 | **⚠️ System & Errors** | ၂၄ နာရီအတွင်း ဖြစ်ပွားခဲ့သော Critical System Errors နှင့် Kernel Panic များ |

---

## ⚡ အသုံးပြုနည်းများ (Usage)

### နည်းလမ်း (၁) - တပ်ဆင်စရာမလိုဘဲ တိုက်ရိုက် ၁ ချက်နှိပ် ကြည့်နည်း (Quick Run)

ဆာဗာထဲတွင် မည်သည့်ဖိုင်မှ Install လုပ်စရာမလိုဘဲ အောက်ပါ Command ဖြင့် ချက်ချင်း ကြည့်ရှုနိုင်ပါသည်-

```bash
wget --no-cache -O report24.sh "https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh?$(date +%s)" && bash report24.sh
```

---

### နည်းလမ်း (၂) - `report24` ဟု အမြဲတမ်း ရိုက်ကြည့်နိုင်ရန် တပ်ဆင်နည်း (Permanent Install)

ဆာဗာထဲတွင် `report24` ဟု command တစ်လုံးတည်းဖြင့် အချိန်မရွေး လွယ်ကူစွာ စစ်ဆေးနိုင်ရန် အောက်ပါ command ကို တစ်ကြိမ်သာ Run ပေးပါ-

```bash
sudo wget -O /usr/local/bin/report24 https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh && sudo chmod +x /usr/local/bin/report24
```

> ✅ တပ်ဆင်ပြီးပါက ဆာဗာ Terminal ဘယ်နေရာကမဆို **`report24`** ဟု ရိုက်လိုက်ရုံဖြင့် အစီရင်ခံစာကို ချက်ချင်း ထုတ်ပေးပါမည်!

```bash
report24
```

---

## 📊 Output ဖတ်နည်း (Understanding the Report)

### [1] Uptime & Reboot Check
```
[1] ⏱️ Uptime & Reboot Check (လွန်ခဲ့သော ၂၄ နာရီအတွင်း):
  • လက်ရှိ Uptime: up 1 day, 12 hours
  ✔ လွန်ခဲ့သော ၂၄ နာရီအတွင်း ဆာဗာ Restart/Reboot လုံးဝမဖြစ်ခဲ့ပါ (၁၀၀% တည်ငြိမ်သည်)
```
- **အစိမ်းရောင် (`✔`)**: ၂၄ နာရီလုံး ဆာဗာ လုံးဝ Restart မဖြစ်ဘဲ တည်ငြိမ်ခဲ့သည်။
- **ဝါ/နီ (`⚠️`)**: ဆာဗာ Reboot ဖြစ်ခဲ့သော အချိန်နှင့် မှတ်တမ်းများကို ပြသပေးမည် (Power/Kernel restart စစ်ရန်)။

---

### [2] Watchdog Downtime Log
```
[2] 🛡️ Watchdog Downtime Log (Service များ ရပ်တန့်ခဲ့ခြင်း ရှိမရှိ):
  ✔ လွန်ခဲ့သော ၂၄ နာရီအတွင်း Service များ (Hy2, Panel, Nginx) တစ်ခုမှ မရပ်ခဲ့ပါ
  ℹ နောက်ဆုံးပုံမှန်လည်ပတ်ကြောင်း အတည်ပြုချက်: [2026-08-24 08:00:01] ✅ All services OK
```
- **အစိမ်းရောင် (`✔`)**: VPN Services များ (Hysteria, Panel, Nginx) တစ်ခုမှ မရပ်တန့်ခဲ့ပါ။
- **အနီရောင် (`❌`)**: ရပ်တန့်ခဲ့သော Service အမည်နှင့် Restart လုပ်ခဲ့သည့် အချိန်ကို ပြသပေးမည်။

---

### [3] VPN အသုံးပြုမှု မှတ်တမ်း
```
[3] 👥 VPN အသုံးပြုမှု မှတ်တမ်း (Hysteria 2 Activity in 24h):
  • စုစုပေါင်း VPN ချိတ်ဆက်ခဲ့သော အကြိမ်: 265 ကြိမ်
  • စုစုပေါင်း Disconnect ဖြစ်ခဲ့သော အကြိမ်: 263 ကြိမ်
  • ချိတ်ဆက်ခဲ့သော User များ စာရင်း:
    ✔ User: me (ချိတ်ဆက်မှု 198 ကြိမ်)
    ✔ User: Soesoe (ချိတ်ဆက်မှု 67 ကြိမ်)
```
- မည်သည့် User က ၂၄ နာရီအတွင်း VPN ကို အကြိမ်ရေ မည်မျှ ချိတ်ဆက်သုံးစွဲခဲ့ကြောင်း အသေးစိတ် ခွဲခြမ်းပြသပေးပါသည်။
*(ဖုန်း Screen ပိတ်ချိန်/ဖွင့်ချိန်၊ လိုင်းပြောင်းချိန်များတွင် ခေတ္တ Reconnect ဖြစ်ခြင်းသည် Mobile VPN အတွက် ပုံမှန်ဖြစ်ပါသည်)*

---

### [4] လုံခြုံရေးနှင့် SSH / Fail2Ban မှတ်တမ်း
```
[4] 🔐 လုံခြုံရေးနှင့် SSH Login မှတ်တမ်း (Security Check):
  • အောင်မြင်စွာ ဝင်ရောက်ခဲ့သော SSH Logins:
    ✔ Aug 24 08:44:12 -> User: zinko from IP: 50.114.172.236
  • Fail2Ban မှ ဖမ်းဆီးပိတ်ပင်ခဲ့သော Attackers များ:
    🚫 Blocked IP: 116.110.16.228 at 2026-08-23 12:40:54
    🚫 Blocked IP: 195.178.110.232 at 2026-08-23 13:49:59
```
- မိမိကိုယ်တိုင် SSH ဝင်ခဲ့သော အချိန်နှင့် IP ကို စစ်ဆေးနိုင်သည်။
- အင်တာနက်ပေါ်မှ Hacker/Scanner Bot များကို Fail2Ban က အလိုအလျောက် ပိတ်ပင် (Block) ပေးထားသော စာရင်းကို ပြသသည်။

---

### [5] System & Kernel Errors
```
[5] ⚠️ System & Kernel Errors (၂၄ နာရီအတွင်း စနစ်ပိုင်း အမှားများ):
  ✔ Critical System Error နှင့် Kernel Panic လုံးဝမရှိပါ (Clean & Stable)
```
- **အစိမ်းရောင် (`✔`)**: ဆာဗာ Kernel နှင့် Operating System သည် လုံးဝ ကျန်းမာသန်စွမ်းသည်။

---

## 💾 အစီရင်ခံစာကို File အဖြစ် သိမ်းဆည်းနည်း

အစီရင်ခံစာကို Log ဖိုင်အဖြစ် သိမ်းလိုပါက:

```bash
report24 | tee /tmp/vps_report_$(date +%Y%m%d).log
```

---

## 🔄 Update & Uninstall

### Script ကို Update ပြုလုပ်ရန်
```bash
sudo wget -O /usr/local/bin/report24 https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/report24.sh && sudo chmod +x /usr/local/bin/report24
```

### ဖျက်ဆီးရန် (Uninstall)
```bash
sudo rm -f /usr/local/bin/report24
```

---

## 📜 Documentation Links

| စာမျက်နှာ | အကြောင်းအရာ |
|:---|:---|
| 📖 [README.md](README.md) | Main Installation Guide |
| 🔍 [AUDIT.md](AUDIT.md) | Full Server Health Audit v2.1 |
| 🛡️ [WATCHDOG.md](WATCHDOG.md) | 24/7 Watchdog Auto-Restart System |
| 📊 [REPORT24.md](REPORT24.md) | **၂၄ နာရီ အစီရင်ခံစာ စစ်ဆေးရေး Tool (ဤဖိုင်)** |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
