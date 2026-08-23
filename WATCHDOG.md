# 🛡️ Hysteria 2 Server Watchdog Monitoring System

> **Hysteria 2 Server** ကို ၂၄ နာရီ ၇ ရက် အလိုအလျောက် စောင့်ကြည့်ပြီး Services ပျက်သွားပါက ချက်ချင်း Auto Restart လုပ်ပေးသော Watchdog System

---

## 📋 Watchdog လုပ်ဆောင်ပုံ

```
မိနစ် ၅ တိုင်း Auto Run
         ↓
Services စစ်ဆေး (hysteria-server, hy2-panel, nginx)
         ↓
    OK?  ──── YES ──→ ၁ နာရီတိုင်း "All OK" Log တင်
     │
    NO
     │
     ↓
Auto Restart + Log မှတ်တမ်းတင်
```

---

## ⚡ တပ်ဆင်နည်း (Installation)

### ဆာဗာတွင် Command တစ်ကြောင်းတည်း Run ပါ

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

# ၁ နာရီတိုင်း OK status မှတ်တမ်းတင်
if $ALL_OK && [ $(date +%M) = "00" ]; then
    echo "[$DATE] ✅ All services OK" >> $LOG
fi

# Log ဖိုင် 500 ကြောင်းသာ သိမ်းပါ
tail -500 $LOG > ${LOG}.tmp 2>/dev/null && mv ${LOG}.tmp $LOG 2>/dev/null || true
EOF

chmod +x /usr/local/bin/hy2-watchdog
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/hy2-watchdog") | crontab -
echo "✅ Watchdog installed and active!"
```

### ✅ Install ပြီးပါပြီ! Cron Job မိနစ် ၅ တိုင်း အလိုအလျောက် Run မည်ဖြစ်သည်

---

## 🚀 အသုံးပြုနည်း (Usage)

### Manual Run (ချက်ချင်း စစ်ဆေးလိုပါက)
```bash
/usr/local/bin/hy2-watchdog
```

### Log ကြည့်ရန်
```bash
cat /var/log/hy2-watchdog.log
```

### Log Tail (နောက်ဆုံး ၂၀ ကြောင်း)
```bash
tail -20 /var/log/hy2-watchdog.log
```

### Real-time Log ကြည့်ရန်
```bash
tail -f /var/log/hy2-watchdog.log
```

### Cron Job ပါမပါ စစ်ရန်
```bash
crontab -l
```

---

## 📊 Log Output ဖတ်နည်း (Reading the Log)

### ပုံမှန် Log (ကောင်းနေပါက)
```
[2026-08-23 08:00:01] ✅ All services OK
[2026-08-23 09:00:01] ✅ All services OK
[2026-08-23 10:00:01] ✅ All services OK
```
> ✅ `All services OK` ကြောင်းများသာ ပါနေပါက Server ကောင်းနေပါသည်

### Service Down ဖြစ်ပြီး Auto Restart ဖြစ်ပါက
```
[2026-08-23 14:35:01] ⚠️  hysteria-server was DOWN - Auto Restarted
[2026-08-23 15:00:01] ✅ All services OK
```
> ⚠️ Down ဖြစ်ပြီး Auto Restart ဖြစ်ကြောင်း မှတ်တမ်းတင်သည်

### Log မရှိသေးပါက
```
cat: /var/log/hy2-watchdog.log: No such file or directory
```
> ✅ ဒါ ကောင်းသော သတင်းပါ! Services အားလုံး OK ဖြစ်နေ၍ Log ဖိုင် မဖန်တီးရသေးပါ

---

## 🔍 စစ်ဆေးနည်းများ (Diagnostics)

### ① Watchdog Status စစ်ဆေးရန်
```bash
# Script ရှိမရှိ
ls -la /usr/local/bin/hy2-watchdog

# Cron Job ရှိမရှိ
crontab -l | grep watchdog

# Log ကြည့်ရန်
cat /var/log/hy2-watchdog.log 2>/dev/null || echo "No downtime recorded yet"
```

### ② Server Reboot History စစ်ဆေးရန်
```bash
# ပြန်ပြီး Boot ဖြစ်ဖူးသော မှတ်တမ်း
last reboot | head -20

# Boot Sessions အားလုံး
journalctl --list-boots
```

### ③ Service Restart History စစ်ဆေးရန်
```bash
# Hysteria Server Restart မှတ်တမ်း
journalctl -u hysteria-server --no-pager | grep -E "Started|Stopped|Failed" | tail -20

# Panel Restart မှတ်တမ်း
journalctl -u hy2-panel --no-pager | grep -E "Started|Stopped|Failed" | tail -20
```

### ④ Kernel Panic / OOM (RAM ပြတ်) စစ်ဆေးရန်
```bash
journalctl -p 0..3 --no-pager -n 30 | grep -E "OOM|panic|killed|error"
```
> ⚠️ ဘာမှ မပေါ်ပါက → Server ကောင်းနေပါသည်

### ⑤ Downtime Events ရေတွက်ရန်
```bash
grep -c "was DOWN" /var/log/hy2-watchdog.log 2>/dev/null || echo "0 downtime events"
```

### ⑥ ယနေ့ Downtime Events ကြည့်ရန်
```bash
grep "$(date +%Y-%m-%d)" /var/log/hy2-watchdog.log 2>/dev/null | grep "was DOWN"
```

---

## 🗓️ Cron Schedule နားလည်နည်း

```
*/5 * * * * /usr/local/bin/hy2-watchdog
│   │ │ │ └─ Day of Week (0-7)
│   │ │ └─── Month (1-12)
│   │ └───── Day of Month (1-31)
│   └─────── Hour (0-23)
└─────────── */5 = Every 5 minutes
```

### Cron Schedule ပြောင်းလိုပါက
```bash
# Cron ဖွင့်ပြီး ပြင်ပါ
crontab -e

# မိနစ် ၁ တိုင်း (Aggressive monitoring)
* * * * * /usr/local/bin/hy2-watchdog

# မိနစ် ၅ တိုင်း (Default - Recommended)
*/5 * * * * /usr/local/bin/hy2-watchdog

# မိနစ် ၁၀ တိုင်း (Light monitoring)
*/10 * * * * /usr/local/bin/hy2-watchdog
```

---

## 🛠️ ပြဿနာဖြေရှင်းနည်း (Troubleshooting)

### Watchdog Run မဖြစ်ပါက
```bash
# Script Permission စစ်ပါ
ls -la /usr/local/bin/hy2-watchdog

# Permission ပြင်ပါ
chmod +x /usr/local/bin/hy2-watchdog

# Cron Service Running ဟုတ်မဟုတ် စစ်ပါ
systemctl status cron
```

### Service တစ်ခုခု Auto Restart မဖြစ်ပါက
```bash
# Manual ပြန် Restart
systemctl restart hysteria-server
systemctl restart hy2-panel
systemctl restart nginx

# Status စစ်ပါ
systemctl status hysteria-server hy2-panel nginx
```

### Log ဖိုင် ကြီးလွန်းပါက
```bash
# Manual Cleanup
tail -200 /var/log/hy2-watchdog.log > /tmp/watchdog.tmp
mv /tmp/watchdog.tmp /var/log/hy2-watchdog.log
```

### Watchdog ဖျက်ချင်ပါက
```bash
# Cron ဖြုတ်ပါ
crontab -l | grep -v "hy2-watchdog" | crontab -

# Script ဖျက်ပါ
rm /usr/local/bin/hy2-watchdog

# Log ဖျက်ပါ (Optional)
rm /var/log/hy2-watchdog.log
```

---

## 📡 External Monitoring (အကောင်းဆုံး - Free)

Server ပြင်ပမှ Monitor လုပ်ချင်ပါက **UptimeRobot** ကို အသုံးပြုပါ:

| Feature | UptimeRobot Free |
|:---|:---:|
| Monitor Sites | 50 ခုထိ |
| Check Interval | 5 မိနစ် |
| Email Alert | ✅ |
| Down History | ✅ |
| Cost | Free |

### Setup လုပ်နည်း
1. [uptimerobot.com](https://uptimerobot.com) မှ Register လုပ်ပါ
2. **Add New Monitor** နှိပ်ပါ
3. **Monitor Type**: HTTPS
4. **URL**: `https://your-domain.com`
5. **Alert Contacts**: Email ထည့်ပါ
6. **Save** နှိပ်ပါ

> ✅ Server Down ဖြစ်ပါက ချက်ချင်း Email Alert ရမည်ဖြစ်သည်

---

## 📊 Full Audit Script နှင့် ပေါင်းစပ်သုံးနည်း

Watchdog Log ကို [Full Audit Script](AUDIT.md) ထဲတွင် ထည့်ကြည့်နိုင်ပါသည်:

```bash
# Audit Script ထဲ Watchdog Section ထည့်ပါ
cat >> /usr/local/bin/audit << 'EXTRA'

echo -e "\n${BOLD}${BLUE}[9] Watchdog Downtime History${NC}"
sep
LOG="/var/log/hy2-watchdog.log"
if [ -f "$LOG" ]; then
    DOWNS=$(grep -c "was DOWN" "$LOG" 2>/dev/null || echo "0")
    LAST_OK=$(grep "All services OK" "$LOG" | tail -1 | awk '{print $1, $2}' | tr -d '[]')
    if [ "$DOWNS" -gt 0 ]; then
        warn "Total downtime events recorded: ${RED}${DOWNS}${NC}"
        grep "was DOWN" "$LOG" | tail -5 | while read line
        do echo -e "    ${RED}→${NC} $line"; done
    else
        ok "Downtime events: ${GREEN}None ✔${NC}"
    fi
    [ -n "$LAST_OK" ] && info "Last confirmed OK: ${LAST_OK}"
else
    info "Watchdog log: Not created yet (All services OK)"
fi
EXTRA

echo "✅ Watchdog section added to audit!"
```

---

## 📌 မှတ်ချက်

- Script သည် **Ubuntu 22.04 / 24.04** တွင် Test ပြုလုပ်ထားသည်
- **Root** permission လိုအပ်သည် (Cron for root)
- Watchdog သည် Services ကို Auto Restart သာ လုပ်ပေးသည်၊ Root Cause ကို မဖြေနိုင်
- Provider ပြဿနာ (Network, Hardware) များကို External Monitoring ဖြင့်သာ တွေ့ရမည်

---

## 📜 Related Documentation

| ဖိုင် | အကြောင်းအရာ |
|:---|:---|
| [README.md](README.md) | Main Installation Guide |
| [AUDIT.md](AUDIT.md) | Full Server Health Audit v2.1 |
| [WATCHDOG.md](WATCHDOG.md) | ဤ Document |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
