# 🔄 Linux Server Auto-Update & Maintenance Guide

> Linux VPS ဆာဗာများတွင် **လုံခြုံရေး Patch များ (Security Updates)၊ System Packages များနှင့် VPN Core များ** ကို ဆာဗာမပျက်စီးစေဘဲ ၂၄/၇ အမြဲတမ်း Update ဖြစ်နေစေရန် စီမံခန့်ခွဲသည့် လမ်းညွှန်ချက် ဖြစ်ပါသည်။

---

## ⚡ အဆင့် (၁) - 1-Click Security Auto-Update တပ်ဆင်ခြင်း (Recommended 🌟)

ဆာဗာထဲတွင် Linux တရားဝင် `unattended-upgrades` စနစ်ကို တပ်ဆင်ထားပါက အရေးကြီးသော **Security Patches & Vulnerability Fixes** များကို နောက်ကွယ်မှ အလိုအလျောက် နေ့စဉ် တင်ပေးသွားမည်ဖြစ်ပါသည်:

```bash
sudo apt update && sudo apt install unattended-upgrades update-notifier-common -y

cat << 'EOF' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat << 'EOF' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

sudo systemctl restart unattended-upgrades
echo "✅ 24/7 Security Auto-Update is now ACTIVE!"
```

---

## 🧹 အဆင့် (၂) - အပတ်စဉ် Auto-Cleanup ထည့်သွင်းခြင်း

Disk နေရာ မပြည့်စေရန် အပတ်စဉ် တနင်္ဂနွေနေ့တိုင်း မလိုအပ်သော Package များနှင့် Log ဟောင်းများကို ရှင်းထုတ်ပေးမည့် Cron:

```bash
(crontab -l 2>/dev/null | grep -v "apt-get autoremove"; echo "0 4 * * 0 apt-get update && apt-get autoremove -y && apt-get clean && journalctl --vacuum-time=7d") | crontab -
echo "✅ Weekly Auto-Cleanup Scheduled!"
```

---

## 🛠️ Manual Update လုပ်နည်းများ

### ၁။ System Packages အားလုံး Update လုပ်ရန်:
```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean
```

### ၂။ Hysteria 2 VPN & Web Panel Update လုပ်ရန်:
```bash
wget -O update.sh https://raw.githubusercontent.com/uzinlay85/Hy2_WebUI_ManusAi/main/update_hysteria.sh && bash update.sh
```

---

## 📜 Documentation Links

| ဖိုင်အမည် | အကြောင်းအရာ |
|:---|:---|
| 📖 [README.md](README.md) | Main Project Overview |
| 🚀 [NEW_SERVER_GUIDE.md](NEW_SERVER_GUIDE.md) | ဆာဗာအသစ် Master Setup Roadmap |
| 🔄 [AUTO_UPDATE.md](AUTO_UPDATE.md) | **Auto-Update & Maintenance Guide (ဤဖိုင်)** |
| 🛡️ [REPORT24.md](REPORT24.md) | Enterprise Security Audit & 24h Activity Suite |
| 🔍 [AUDIT.md](AUDIT.md) | Server Full Health Audit |
| 🐶 [WATCHDOG.md](WATCHDOG.md) | 24/7 Watchdog Auto-Restart Guide |

---

*Maintained by [uzinlay85](https://github.com/uzinlay85) • Hysteria 2 WebUI Project*
