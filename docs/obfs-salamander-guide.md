# 🛡️ Hysteria 2 Salamander Obfuscation (obfs) Re-enablement Guide

ဤလမ်းညွှန်သည် **Hysteria 2 Server** တွင် **Salamander Obfuscation (obfs)** စနစ်ကို ပြန်လည် ထည့်သွင်း အသုံးပြုလိုပါက ပြုလုပ်ရမည့် အဆင့်များကို ဖော်ပြထားသော မှတ်တမ်းဖိုင် ဖြစ်ပါသည်။

---

## 📖 Obfuscation (obfs) ဆိုသည်မှာ အဘယ်နည်း။

Salamander obfuscation သည် Hysteria 2 ၏ QUIC/UDP VPN Traffic ကို ပုံဖျောက်ပေးသော စနစ်ဖြစ်ပါသည်။ ISP သို့မဟုတ် DPI (Deep Packet Inspection) Firewall များက VPN သုံးစွဲနေသည်ကို ခွဲခြား မသိရှိနိုင်အောင် ကာကွယ်ပေးပါသည်။

---

## ⚙️ ပြန်လည် ထည့်သွင်း အသုံးပြုနည်း (Step-by-Step)

### ၁။ Server Hysteria Configuration (`/etc/hysteria/config.yaml`) တွင် ထည့်သွင်းခြင်း

`/etc/hysteria/config.yaml` ဖိုင်ထဲတွင် အောက်ပါ `obfs` block ကို ဖြည့်စွက်ပါ:

```yaml
listen: :10443

tls:
  cert: /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem

# --- Obfuscation Section ---
obfs:
  type: salamander
  salamander:
    password: YOUR_OBFS_PASSWORD
# ---------------------------

auth:
  type: http
  http:
    url: http://127.0.0.1:5000/auth

trafficStats:
  listen: 127.0.0.1:4000
  secret: YOUR_STATS_SECRET
```

### ၂။ Web Panel (`/opt/hysteria-panel/app.py`) တွင် ပြန်လည် ထည့်သွင်းခြင်း

`app.py` ထဲတွင် `OBFS_PASS` variable ကို ထည့်သွင်းပြီး Client URL format ကို အောက်ပါအတိုင်း ပြောင်းလဲပါ:

```python
OBFS_PASS = 'YOUR_OBFS_PASSWORD'
```

Client URL Template:
```html
<span class="code" id="url_{{ loop.index }}">hy2://{{ user['password'] | urlencode_pass }}@{{ domain }}:10443/?insecure=0&sni={{ domain }}&obfs=salamander&obfs-password={{ obfs_pass }}#{{ user['name'] | urlencode }}</span>
```

### ၃။ Hysteria Server နှင့် Panel ကို Restart ပြုလုပ်ခြင်း

```bash
systemctl restart hysteria-server hysteria-panel
```

---

## 📝 နှိုင်းယှဉ်ချက် (Key Formats)

| အမျိုးအစား | Client Key Format |
| :--- | :--- |
| **Standard Mode (ယခုစနစ်)** | `hy2://PASSWORD@DOMAIN:10443/?insecure=0&sni=DOMAIN#NAME` |
| **Obfs Mode (Salamander)** | `hy2://PASSWORD@DOMAIN:10443/?insecure=0&sni=DOMAIN&obfs=salamander&obfs-password=OBFS_PASS#NAME` |
