#!/bin/bash

# =============================================================
#  Hysteria 2 + Python Web Panel - 1-Click Setup Script (v4.0)
#  Faster • More Performant • More Secure • Official-Aligned
#  - Noninteractive apt (fast install)
#  - QUIC performance tuning
#  - Anti-DPI obfuscation (salamander obfs + masquerade)
#  - trafficStats secret protection
#  - IPv6 private range blocking
#  - nftables port hopping (modern firewall)
# =============================================================

set -e

# Color helpers
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------
# 1. Get Domain Name from User
# -----------------------------------------------------------
read -p "🌐 သင့်ရဲ့ Domain Name ကို ရိုက်ထည့်ပါ (ဥပမာ - hy2-bear.truehand.top): " DOMAIN
if [ -z "$DOMAIN" ]; then
    err "Domain Name ထည့်သွင်းခြင်း မရှိပါသဖြင့် ရပ်တန့်လိုက်ပါသည်။"
    exit 1
fi
read -p "🔌 Hysteria 2 Port သတ်မှတ်ပါ (Default [10443]): " PORT_INPUT
HY2_PORT=${PORT_INPUT:-10443}

# Generate a random obfs password automatically
# NOTE: tr -d '+/=' removes all base64 special chars to keep sed-safe alphanumeric only
OBFS_PASS=$(head -c 32 /dev/urandom | base64 | tr -d '+/=' | head -c 20)
# Generate a random trafficStats secret
STATS_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '+/=' | head -c 20)

info "🚀 $DOMAIN အတွက် Hysteria 2 (v4.0) + Python Panel ကို စတင် တပ်ဆင်နေပါပြီ..."
sleep 2

# -----------------------------------------------------------
# 2. Install Packages (Faster - noninteractive, no full upgrade)
# -----------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
info "Updating package lists..."
apt update -y
info "Installing required packages (this may take a few minutes)..."
apt install -y --no-install-recommends \
    curl wget ufw nginx certbot python3-certbot-nginx \
    sqlite3 python3-pip python3-venv build-essential nftables
ok "Packages installed."

# -----------------------------------------------------------
# 3. Setup Python Panel
# -----------------------------------------------------------
mkdir -p /opt/hysteria-panel
cd /opt/hysteria-panel
python3 -m venv venv
source venv/bin/activate
pip install --no-cache-dir Flask Werkzeug
ok "Python panel environment ready."

cat << "EOF" > /opt/hysteria-panel/app.py
from flask import Flask, request, jsonify, render_template_string, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash
import sqlite3, urllib.parse, urllib.request, json, os, datetime, secrets

app = Flask(__name__)
DB_FILE = '/opt/hysteria-panel/users.db'

def get_flask_secret():
    try:
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        conn.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        row = conn.execute("SELECT value FROM settings WHERE key = 'flask_secret'").fetchone()
        if not row:
            sec = os.urandom(24).hex()
            conn.execute("INSERT INTO settings (key, value) VALUES ('flask_secret', ?)", (sec,))
            conn.commit()
            conn.close()
            return sec
        conn.close()
        return row['value']
    except Exception:
        return os.urandom(24)

app.secret_key = get_flask_secret()

def get_hysteria_port():
    try:
        if os.path.exists("/etc/hysteria/config.yaml"):
            with open("/etc/hysteria/config.yaml", "r") as f:
                for line in f:
                    if line.strip().startswith("listen:"):
                        val = line.split("listen:")[1].strip()
                        port = val.split(":")[-1].strip()
                        if port.isdigit(): return port
    except: pass
    return '10443'

HYSTERIA_PORT = get_hysteria_port()
OBFS_PASS = 'OBFS_PASS_PLACEHOLDER'
STATS_SECRET = 'STATS_SECRET_PLACEHOLDER'

def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.execute("CREATE TABLE IF NOT EXISTS users (password TEXT PRIMARY KEY, name TEXT)")
    conn.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    try: conn.execute("ALTER TABLE users ADD COLUMN name TEXT")
    except: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN limit_gb REAL DEFAULT 0")
    except: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN expiry_date TEXT")
    except: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN last_seen TEXT")
    except: pass
    if not conn.execute("SELECT value FROM settings WHERE key = 'admin_pass'").fetchone():
        default_hash = generate_password_hash('admin123')
        conn.execute("INSERT INTO settings (key, value) VALUES ('admin_pass', ?)", (default_hash,))
    conn.commit()
    conn.close()

init_db()

def verify_admin_pass(pass_input):
    conn = get_db()
    row = conn.execute("SELECT value FROM settings WHERE key = 'admin_pass'").fetchone()
    conn.close()
    if not row: return False
    stored = row['value']
    if stored.startswith('scrypt:') or stored.startswith('pbkdf2:'):
        return check_password_hash(stored, pass_input)
    return stored == pass_input

def get_server_tag():
    conn = get_db()
    row = conn.execute("SELECT value FROM settings WHERE key = 'server_tag'").fetchone()
    conn.close()
    return row['value'] if row else ''

def generate_csrf_token():
    if '_csrf_token' not in session:
        session['_csrf_token'] = secrets.token_hex(16)
    return session['_csrf_token']

app.jinja_env.globals['csrf_token'] = generate_csrf_token

@app.before_request
def csrf_protect():
    if request.method == "POST":
        if request.path == "/auth": return
        token = session.get('_csrf_token', None)
        req_token = request.form.get('csrf_token') or (request.json.get('csrf_token') if request.is_json else None)
        if not token or token != req_token:
            return "CSRF Token Validation Failed!", 400

def get_traffic_stats():
    try:
        req = urllib.request.Request(
            "http://127.0.0.1:4000/traffic",
            headers={"Authorization": STATS_SECRET}
        )
        with urllib.request.urlopen(req, timeout=2) as response:
            return json.loads(response.read().decode())
    except Exception: return {}

def get_online_clients():
    try:
        req = urllib.request.Request(
            "http://127.0.0.1:4000/online",
            headers={"Authorization": STATS_SECRET}
        )
        with urllib.request.urlopen(req, timeout=2) as response:
            return json.loads(response.read().decode())
    except Exception: return {}

def format_last_seen(dt_str):
    if not dt_str: return "Never"
    try:
        dt = datetime.datetime.strptime(dt_str, '%Y-%m-%d %H:%M:%S')
        now = datetime.datetime.now()
        diff = now - dt
        seconds = int(diff.total_seconds())
        if seconds < 0 or seconds < 60: return "Just now"
        minutes = seconds // 60
        if minutes < 60: return f"{minutes}m ago"
        hours = minutes // 60
        if hours < 24: return f"{hours}h ago"
        days = hours // 24
        if days < 30: return f"{days}d ago"
        return dt.strftime('%Y-%m-%d')
    except Exception: return dt_str

@app.route("/auth", methods=["POST"])
def auth():
    data = request.json or {}
    raw_auth = data.get("auth", "")
    unquoted_auth = urllib.parse.unquote(raw_auth)
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE password = ? OR password = ?", (unquoted_auth, raw_auth)).fetchone()
    if user:
        real_pass = user['password']
        now = datetime.datetime.now()
        now_str = now.strftime('%Y-%m-%d %H:%M:%S')
        conn.execute("UPDATE users SET last_seen = ? WHERE password = ?", (now_str, real_pass))
        conn.commit()
        if user['expiry_date']:
            try:
                exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                if now > exp_date:
                    conn.close()
                    return jsonify({"ok": False}), 401
            except Exception: pass
        limit_gb = user['limit_gb']
        if limit_gb and limit_gb > 0:
            stats = get_traffic_stats()
            user_stat = stats.get(real_pass) or stats.get(raw_auth, {})
            total_used = user_stat.get('tx', 0) + user_stat.get('rx', 0)
            if total_used >= (limit_gb * 1024 * 1024 * 1024):
                conn.close()
                return jsonify({"ok": False}), 401
        conn.close()
        return jsonify({"ok": True, "id": real_pass}), 200
    conn.close()
    return jsonify({"ok": False}), 401

LOGIN_TEMPLATE = """
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Login</title><style>body{font-family:sans-serif;background:#f3f4f6;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;}.login-box{background:#fff;padding:30px;border-radius:8px;box-shadow:0 4px 10px rgba(0,0,0,0.1);text-align:center;width:100%;max-width:350px;}input{width:90%;padding:12px;margin:15px 0;border:1px solid #ccc;border-radius:4px;box-sizing:border-box;font-size:16px;}button{width:100%;padding:12px;background:#3b82f6;color:white;border:none;border-radius:4px;cursor:pointer;font-weight:bold;font-size:16px;}.error{color:#ef4444;margin-bottom:10px;font-size:14px;font-weight:bold;}</style></head><body><div class="login-box"><h2>⚡ Hysteria 2 Panel</h2>{% if error %}<div class="error">{{ error }}</div>{% endif %}<form method="POST"><input type="hidden" name="csrf_token" value="{{ csrf_token() }}"><input type="password" name="admin_pass" placeholder="Enter Admin Password" required autofocus><button type="submit">Login</button></form></div></body></html>
"""

HTML_TEMPLATE = """
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"><title>Hysteria 2 Manager</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f8fafc;padding:20px;margin:0;color:#334155;}.header{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;flex-wrap:wrap;gap:10px;}.container{max-width:1250px;margin:auto;background:#fff;padding:25px;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,0.04);}input,button{padding:10px 14px;margin:5px;border-radius:8px;border:1px solid #cbd5e1;font-size:14px;outline:none;}input:focus{border-color:#2563eb;}button{background:#2563eb;color:white;border:none;cursor:pointer;font-weight:600;transition:opacity 0.2s;}button:hover{opacity:0.9;}.btn-copy{background:#059669;padding:8px 12px;font-size:12px;margin-top:5px;width:100%;border-radius:6px;}.btn-danger{background:#dc2626;padding:8px 12px;border-radius:6px;}.btn-logout{background:#64748b;text-decoration:none;padding:10px 18px;color:white;border-radius:8px;font-size:14px;font-weight:600;}.table-wrapper{overflow-x:auto;-webkit-overflow-scrolling:touch;margin-top:20px;border-radius:10px;border:1px solid #e2e8f0;}table{width:100%;border-collapse:collapse;font-size:14px;white-space:nowrap;}th,td{padding:12px 14px;border-bottom:1px solid #e2e8f0;text-align:left;}th{background:#f8fafc;color:#475569;font-weight:600;}.code{background:#0f172a;color:#34d399;padding:8px 12px;display:block;word-break:break-all;font-family:monospace;border-radius:6px;font-size:12px;white-space:normal;max-width:280px;}.settings-box{background:#fffbeb;padding:20px;border-radius:12px;border:1px solid #fde68a;box-sizing:border-box;}.usage-badge{background:#e0e7ff;color:#3730a3;padding:4px 8px;border-radius:4px;font-weight:600;font-size:12px;display:inline-block;margin-bottom:2px;}.status-online{color:#15803d;font-weight:600;background:#dcfce7;padding:4px 10px;border-radius:12px;font-size:12px;display:inline-block;}.status-offline{color:#64748b;font-weight:600;background:#f1f5f9;padding:4px 10px;border-radius:12px;font-size:12px;display:inline-block;}.status-error{color:#b91c1c;font-weight:600;background:#fee2e2;padding:4px 10px;border-radius:12px;font-size:12px;display:inline-block;}@media (max-width:768px){body{padding:10px;}.container{padding:15px;border-radius:12px;}.header{flex-direction:column;align-items:stretch;gap:12px;text-align:center;}.header h2{font-size:20px;}.btn-logout{width:100%;box-sizing:border-box;text-align:center;}.add-form{flex-direction:column;align-items:stretch !important;padding:15px !important;}.add-form input,.add-form button,.add-form .input-group{width:100% !important;margin:4px 0 !important;box-sizing:border-box;}.add-form button[type="submit"]{padding:14px;font-size:15px;margin-top:8px !important;}.settings-grid{flex-direction:column !important;gap:15px !important;margin-top:20px !important;}.settings-box{width:100% !important;min-width:100% !important;padding:15px !important;}.settings-box input,.settings-box button{width:100% !important;margin:4px 0 !important;box-sizing:border-box;}.settings-box button{padding:12px;}}</style><script>function copyToClipboard(id){const text=document.getElementById(id).innerText;navigator.clipboard.writeText(text).then(()=>{showToast('✅ Client URL Copied!');}).catch(()=>{showToast('✅ Copied!');});}function genPass(){const chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';let res='';for(let i=0;i<16;i++){res+=chars.charAt(Math.floor(Math.random()*chars.length));}document.getElementById('user_pass_input').value=res;showToast('🎲 Random Password Generated');}function showToast(msg){let t=document.getElementById('toast');if(!t){t=document.createElement('div');t.id='toast';t.style.cssText='position:fixed;bottom:25px;left:50%;transform:translateX(-50%);background:#0f172a;color:#34d399;padding:12px 24px;border-radius:30px;font-weight:600;font-size:14px;box-shadow:0 10px 25px rgba(0,0,0,0.25);z-index:9999;transition:opacity 0.3s;opacity:0;pointer-events:none;';document.body.appendChild(t);}t.innerText=msg;t.style.opacity='1';setTimeout(()=>{t.style.opacity='0';},2000);}</script></head><body><div class="container"><div class="header"><h2 style="margin:0;">⚡ Hysteria 2 User Management</h2><a href="/logout" class="btn-logout">🚪 Logout</a></div><form method="POST" action="/add" class="add-form" style="display:flex;flex-wrap:wrap;gap:10px;align-items:center;background:#f9fafb;padding:18px;border-radius:12px;border:1px solid #e2e8f0;"><input type="hidden" name="csrf_token" value="{{ csrf_token() }}"><input type="text" name="user_name" placeholder="📝 Name" required style="flex:1;min-width:100px;"><div class="input-group" style="display:flex;flex:1.2;min-width:180px;gap:4px;"><input type="text" name="user_pass" id="user_pass_input" placeholder="👤 Password (Blank = Auto)" style="flex:1;margin:0;"><button type="button" onclick="genPass()" style="background:#64748b;margin:0;padding:10px 12px;" title="Generate Random Password">🎲 Auto</button></div><input type="number" step="0.1" name="limit_gb" placeholder="Data Limit (GB) [0=Unl]" required style="flex:1;min-width:120px;" value="0"><input type="number" name="days" placeholder="Days [0=Unl]" required style="flex:1;min-width:100px;" value="0"><button type="submit">➕ Add User</button></form><div class="table-wrapper"><table><tr><th>Name</th><th>Password</th><th>Status</th><th>Data Usage / Limit</th><th>Left Days</th><th>Last Seen</th><th>Client URL</th><th>Action</th></tr>{% for user in users %}<tr><td><b>{{ user['name'] or 'Unknown' }}</b></td><td>{{ user['password'] }}</td><td>{% if user['status'] == 'Online' %}<span class="status-online">🟢 Online</span>{% elif user['status'] == 'Offline' %}<span class="status-offline">⚪ Offline</span>{% else %}<span class="status-error">🔴 {{ user['status'] }}</span>{% endif %}</td><td style="min-width:140px;"><span class="usage-badge">⬇️ {{ user['tx'] | format_bytes }}</span><br><span class="usage-badge" style="background:#dcfce7;color:#4338ca;">⬆️ {{ user['rx'] | format_bytes }}</span><br><small style="color:#6b7280;font-weight:bold;">Total: {{ (user['tx'] + user['rx']) | format_bytes }} / {% if user['limit_gb'] > 0 %}{{ user['limit_gb'] }} GB{% else %}Unlimited{% endif %}</small></td><td>{% if user['expiry_date'] %}<b>{{ user['left_days'] }} Days</b><br><small style="color:#6b7280;">(Exp: {{ user['expiry_date'] }})</small>{% else %}<b>Unlimited</b>{% endif %}</td><td style="min-width:110px;"><b>{{ user['last_seen'] | last_seen }}</b><br><small style="color:#6b7280;">{{ user['last_seen'] or 'Never' }}</small></td><td><span class="code" id="url_{{ loop.index }}">hy2://{{ user['password'] | urlencode_pass }}@{{ domain }}:{{ port }}/?security=tls&sni={{ domain }}#{{ (user['name'] + server_tag) | urlencode }}</span><button class="btn-copy" onclick="copyToClipboard('url_{{ loop.index }}')">📋 Copy URL</button></td><td><form method="POST" action="/delete" style="margin:0;" onsubmit="return confirm('Delete this user?');"><input type="hidden" name="csrf_token" value="{{ csrf_token() }}"><input type="hidden" name="user_pass" value="{{ user['password'] }}"><button type="submit" class="btn-danger">🗑️</button></form></td></tr>{% endfor %}</table></div><div class="settings-grid" style="display:flex;flex-wrap:wrap;gap:20px;margin-top:30px;"><div class="settings-box" style="flex:1;min-width:300px;margin-top:0;"><h3 style="margin-top:0;color:#92400e;">⚙️ Change Admin Password</h3><form method="POST" action="/change_pass" style="display:flex;flex-wrap:wrap;gap:10px;"><input type="hidden" name="csrf_token" value="{{ csrf_token() }}"><input type="password" name="current_pass" placeholder="Current Password" required><input type="password" name="new_pass" placeholder="New Password" required><button type="submit" style="background:#d97706;">🔄 Update Password</button></form></div><div class="settings-box" style="flex:1;min-width:300px;margin-top:0;background:#eff6ff;border-color:#bfdbfe;"><h3 style="margin-top:0;color:#1e40af;">🏷️ Server Profile Tag Suffix</h3><form method="POST" action="/update_tag" style="display:flex;flex-wrap:wrap;gap:10px;"><input type="hidden" name="csrf_token" value="{{ csrf_token() }}"><input type="text" name="server_tag" value="{{ server_tag }}" placeholder="e.g. _Server01 or _SG" style="flex:1;min-width:150px;"><button type="submit" style="background:#2563eb;">💾 Save Tag</button></form><small style="color:#4b5563;display:block;margin-top:8px;">Appended to every Client Key name (e.g. <b>#User{{ server_tag or '_Server01' }}</b>)</small></div></div></div></body></html>
"""

@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        if verify_admin_pass(request.form.get("admin_pass", "")):
            session['logged_in'] = True
            return redirect(url_for("index"))
        else: error = "Invalid Admin Password!"
    return render_template_string(LOGIN_TEMPLATE, error=error)

@app.route("/logout")
def logout():
    session.pop('logged_in', None)
    return redirect(url_for("login"))

@app.route("/")
def index():
    if not session.get('logged_in'): return redirect(url_for("login"))
    conn = get_db()
    db_users = conn.execute("SELECT * FROM users").fetchall()
    domain = request.host.split(":")[0]
    stats = get_traffic_stats()
    online_map = get_online_clients()
    users_data = []
    now = datetime.datetime.now()
    now_str = now.strftime('%Y-%m-%d %H:%M:%S')
    users_to_update = []
    for u in db_users:
        user = dict(u)
        pwd = user['password']
        quoted_pwd = urllib.parse.quote(pwd, safe='')
        unquoted_pwd = urllib.parse.unquote(pwd)
        user_stat = stats.get(pwd) or stats.get(quoted_pwd) or stats.get(unquoted_pwd) or {}
        user['tx'] = user_stat.get('tx', 0)
        user['rx'] = user_stat.get('rx', 0)
        total_used = user['tx'] + user['rx']
        online_cnt = online_map.get(pwd, 0) or online_map.get(quoted_pwd, 0) or online_map.get(unquoted_pwd, 0)
        is_online = online_cnt > 0
        if is_online:
            user['status'] = 'Online'
            user['last_seen'] = now_str
            users_to_update.append(pwd)
        else:
            user['status'] = 'Offline'
        if user['expiry_date']:
            try:
                exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                left = (exp_date - now).days
                user['left_days'] = left if left >= 0 else 0
                if now > exp_date: user['status'] = 'Expired'
            except Exception: user['left_days'] = 'Error'
        else: user['left_days'] = 'Unlimited'
        if user['limit_gb'] and user['limit_gb'] > 0:
            if total_used >= (user['limit_gb'] * 1024 * 1024 * 1024): user['status'] = 'Data Full'
        users_data.append(user)
    if users_to_update:
        for p in users_to_update:
            conn.execute("UPDATE users SET last_seen = ? WHERE password = ?", (now_str, p))
        conn.commit()
    conn.close()
    return render_template_string(HTML_TEMPLATE, users=users_data, domain=domain, port=HYSTERIA_PORT, server_tag=get_server_tag())

@app.route("/update_tag", methods=["POST"])
def update_tag():
    if not session.get('logged_in'): return redirect(url_for("login"))
    tag = request.form.get("server_tag", "").strip()
    conn = get_db()
    conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('server_tag', ?)", (tag,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))

@app.route("/add", methods=["POST"])
def add_user():
    if not session.get('logged_in'): return redirect(url_for("login"))
    user_name = request.form.get("user_name", "Unknown").strip()
    user_pass = request.form.get("user_pass", "").strip()
    if not user_pass:
        chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
        user_pass = ''.join(secrets.choice(chars) for _ in range(16))
    try: limit_gb = float(request.form.get("limit_gb", 0))
    except: limit_gb = 0
    try: days = int(request.form.get("days", 0))
    except: days = 0
    expiry_date = None
    if days > 0:
        expiry_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')
    conn = get_db()
    try:
        conn.execute("INSERT INTO users (password, name, limit_gb, expiry_date, last_seen) VALUES (?, ?, ?, ?, NULL)",
                     (user_pass, user_name, limit_gb, expiry_date))
        conn.commit()
    except: pass
    conn.close()
    return redirect(url_for("index"))

@app.route("/delete", methods=["POST"])
def delete_user():
    if not session.get('logged_in'): return redirect(url_for("login"))
    conn = get_db()
    conn.execute("DELETE FROM users WHERE password = ?", (request.form.get("user_pass"),))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))

@app.route("/change_pass", methods=["POST"])
def change_pass():
    if not session.get('logged_in'): return redirect(url_for("login"))
    curr_pass = request.form.get("current_pass", "")
    new_pass = request.form.get("new_pass", "")
    if verify_admin_pass(curr_pass) and new_pass:
        hashed_new_pass = generate_password_hash(new_pass)
        conn = get_db()
        conn.execute("UPDATE settings SET value = ? WHERE key = 'admin_pass'", (hashed_new_pass,))
        conn.commit()
        conn.close()
        session.pop('logged_in', None)
        return redirect(url_for("login"))
    return redirect(url_for("index"))

@app.template_filter('urlencode')
def urlencode_filter(s):
    if not s: return "Hysteria2"
    return urllib.parse.quote_plus(str(s))

@app.template_filter('format_bytes')
def format_bytes(size):
    if not size: return "0 B"
    power = 1024
    n = 0
    power_labels = {0: 'B', 1: 'KB', 2: 'MB', 3: 'GB', 4: 'TB'}
    while size > power and n < 4:
        size /= power
        n += 1
    return f"{size:.2f} {power_labels[n]}"

@app.template_filter('last_seen')
def last_seen_filter(s):
    return format_last_seen(s)

@app.template_filter('urlencode_pass')
def urlencode_pass_filter(s):
    if not s: return ""
    return urllib.parse.quote(str(s), safe='')

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
EOF

# Inject the real stats/obfs values into app.py
# NOTE: Using | as delimiter instead of / to avoid breakage if value contains /
sed -i "s|STATS_SECRET_PLACEHOLDER|$STATS_SECRET|g" /opt/hysteria-panel/app.py
sed -i "s|OBFS_PASS_PLACEHOLDER|$OBFS_PASS|g" /opt/hysteria-panel/app.py
ok "Panel app.py created."

# -----------------------------------------------------------
# 4. Systemd for Python Panel
# -----------------------------------------------------------
cat << EOF > /etc/systemd/system/hysteria-panel.service
[Unit]
Description=Hysteria 2 Python Panel
After=network.target network-online.target
Wants=network-online.target

[Service]
User=root
WorkingDirectory=/opt/hysteria-panel
ExecStart=/opt/hysteria-panel/venv/bin/python /opt/hysteria-panel/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now hysteria-panel
ok "Panel service started."

# -----------------------------------------------------------
# 5. Nginx & SSL
# -----------------------------------------------------------
cat << EOF > /etc/nginx/sites-available/hysteria_panel
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/hysteria_panel
ln -sf /etc/nginx/sites-available/hysteria_panel /etc/nginx/sites-enabled/
# Clean up any stuck certbot locks or background instances
pkill -9 -f certbot 2>/dev/null || true
rm -f /var/lib/letsencrypt/*.lock /var/log/letsencrypt/*.lock /run/lock/certbot.lock 2>/dev/null || true

certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
chmod -R 755 /etc/letsencrypt/archive
chmod -R 755 /etc/letsencrypt/live
chown -R root:hysteria /etc/letsencrypt/live/ /etc/letsencrypt/archive/ 2>/dev/null || true
ok "Nginx + SSL configured."

# -----------------------------------------------------------
# 6. Hysteria 2 Install & Config (v4.0 - tuned)
# -----------------------------------------------------------
echo "net.core.rmem_max=33554432" >> /etc/sysctl.conf
echo "net.core.wmem_max=33554432" >> /etc/sysctl.conf
sysctl -p

bash <(curl -fsSL https://get.hy2.sh/)

cat << EOF > /etc/hysteria/config.yaml
listen: :$HY2_PORT

tls:
  cert: /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  key: /etc/letsencrypt/live/$DOMAIN/privkey.pem

# Ultra High-Speed Performance Tuning (16MB Stream / 32MB Conn Buffer)
quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
  maxIdleTimeout: 60s
  keepAlivePeriod: 5s

# Obfuscation (disabled by default for maximum app compatibility & light connections)
# To re-enable Salamander obfs, see docs/obfs-salamander-guide.md

# Masquerade - disguise probe traffic as normal HTTPS requests
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

auth:
  type: http
  http:
    url: http://127.0.0.1:5000/auth

# Block private ranges (IPv4 + IPv6) to prevent abuse
acl:
  inline:
    - reject(127.0.0.0/8)
    - reject(::1/128)
    - reject(10.0.0.0/8)
    - reject(172.16.0.0/12)
    - reject(192.168.0.0/16)
    - reject(fc00::/7)
    - reject(fe80::/10)
    - direct(all)

trafficStats:
  listen: 127.0.0.1:4000
  secret: $STATS_SECRET
EOF
ok "Hysteria config written."

# -----------------------------------------------------------
# 7. Cleanup & Single Port Firewall
# -----------------------------------------------------------
nft delete table ip hysteria_nat 2>/dev/null || true
rm -f /etc/nftables.d/hysteria.nft 2>/dev/null || true

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $HY2_PORT/udp
ufw delete allow 20000:50000/udp 2>/dev/null || true
sed -i '/20000:50000/d' /etc/ufw/before.rules 2>/dev/null || true
ufw reload
ok "Firewall configured for Single Port ($HY2_PORT/udp)."

# -----------------------------------------------------------
# 8. Start Hysteria
# -----------------------------------------------------------
systemctl enable --now hysteria-server
systemctl restart hysteria-server
ok "Hysteria server started."

echo ""
echo "============================================================="
echo -e "${GREEN}🎉 တပ်ဆင်ခြင်း အောင်မြင်စွာ ပြီးဆုံးပါပြီ! (v4.1 Single Port)${NC}"
echo "🌐 Web UI: https://$DOMAIN"
echo "🔑 Default Admin Password: admin123"
echo ""
echo -e "${YELLOW}🔌 Hysteria 2 Port:${NC} $HY2_PORT"
echo -e "${YELLOW}🔐 Traffic Stats Secret:${NC} $STATS_SECRET"
echo "============================================================="
echo ""
echo "⚠️  Panel မှ ထုတ်ပေးသော hy2:// URL များကို တိုက်ရိုက် အသုံးပြုနိုင်ပါသည်။"
echo "============================================================="
