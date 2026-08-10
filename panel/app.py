"""
Hysteria 2 + Python Web Management Panel (v4.1 Patched)
========================================================
Flask-based web UI for managing Hysteria 2 VPN users with:
- Hashed Admin Password Security (werkzeug.security)
- CSRF Token Protection
- Robust 23:59:59 Expiry Cutoff Logic
- Persistent Session Secret Key
- Dynamic Custom Port & Server Tag Suffix
- Real-time traffic statistics & online status
"""

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
                        if port.isdigit():
                            return port
    except Exception:
        pass
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
    except Exception: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN limit_gb REAL DEFAULT 0")
    except Exception: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN expiry_date TEXT")
    except Exception: pass
    try: conn.execute("ALTER TABLE users ADD COLUMN last_seen TEXT")
    except Exception: pass

    # Initialize default admin password with secure hash
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
    if not row:
        return False
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
        if request.path == "/auth":
            return
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
    except Exception:
        return {}


def get_online_clients():
    try:
        req = urllib.request.Request(
            "http://127.0.0.1:4000/online",
            headers={"Authorization": STATS_SECRET}
        )
        with urllib.request.urlopen(req, timeout=2) as response:
            return json.loads(response.read().decode())
    except Exception:
        return {}


def format_last_seen(dt_str):
    if not dt_str:
        return "Never"
    try:
        dt = datetime.datetime.strptime(dt_str, '%Y-%m-%d %H:%M:%S')
        now = datetime.datetime.now()
        diff = now - dt
        seconds = int(diff.total_seconds())
        if seconds < 0 or seconds < 60:
            return "Just now"
        minutes = seconds // 60
        if minutes < 60:
            return f"{minutes}m ago"
        hours = minutes // 60
        if hours < 24:
            return f"{hours}h ago"
        days = hours // 24
        if days < 30:
            return f"{days}d ago"
        return dt.strftime('%Y-%m-%d')
    except Exception:
        return dt_str


@app.route("/auth", methods=["POST"])
def auth():
    """Hysteria HTTP auth backend endpoint."""
    data = request.json or {}
    raw_auth = data.get("auth", "")
    unquoted_auth = urllib.parse.unquote(raw_auth)
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE password = ? OR password = ?",
        (unquoted_auth, raw_auth)
    ).fetchone()

    if user:
        real_pass = user['password']
        now = datetime.datetime.now()
        now_str = now.strftime('%Y-%m-%d %H:%M:%S')
        conn.execute("UPDATE users SET last_seen = ? WHERE password = ?", (now_str, real_pass))
        conn.commit()

        # 1. Check Expiry Date (valid until 23:59:59 of expiry date)
        if user['expiry_date']:
            try:
                exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                if now > exp_date:
                    conn.close()
                    return jsonify({"ok": False}), 401
            except Exception:
                pass

        # 2. Check Data Limit
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
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Hysteria 2 Panel</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f1f5f9; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; padding: 15px; box-sizing: border-box; }
        .login-box { background: #fff; padding: 35px 25px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.06); text-align: center; width: 100%; max-width: 360px; box-sizing: border-box; }
        h2 { margin-top: 0; color: #0f172a; font-size: 24px; font-weight: 700; }
        input { width: 100%; padding: 12px 14px; margin: 15px 0 20px 0; border: 1px solid #cbd5e1; border-radius: 8px; box-sizing: border-box; font-size: 16px; outline: none; }
        input:focus { border-color: #2563eb; ring: 2px #bfdbfe; }
        button { width: 100%; padding: 14px; background: #2563eb; color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 16px; transition: background 0.2s; }
        button:hover { background: #1d4ed8; }
        .error { color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; padding: 10px; border-radius: 8px; margin-bottom: 15px; font-size: 14px; font-weight: 500; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>⚡ Hysteria 2 Panel</h2>
        {% if error %}
            <div class="error">{{ error }}</div>
        {% endif %}
        <form method="POST">
            <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
            <input type="password" name="admin_pass" placeholder="Enter Admin Password" required autofocus>
            <button type="submit">Login</button>
        </form>
    </div>
</body>
</html>
"""

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Hysteria 2 Manager</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; padding: 20px; margin: 0; color: #334155; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 10px; }
        .container { max-width: 1250px; margin: auto; background: #fff; padding: 25px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.04); }
        input, button { padding: 10px 14px; margin: 5px; border-radius: 8px; border: 1px solid #cbd5e1; font-size: 14px; outline: none; }
        input:focus { border-color: #2563eb; }
        button { background: #2563eb; color: white; border: none; cursor: pointer; font-weight: 600; transition: opacity 0.2s; }
        button:hover { opacity: 0.9; }
        .btn-copy { background: #059669; padding: 8px 12px; font-size: 12px; margin-top: 5px; width: 100%; border-radius: 6px; }
        .btn-danger { background: #dc2626; padding: 8px 12px; border-radius: 6px; }
        .btn-logout { background: #64748b; text-decoration: none; padding: 10px 18px; color: white; border-radius: 8px; font-size: 14px; font-weight: 600; }
        .table-wrapper { overflow-x: auto; -webkit-overflow-scrolling: touch; margin-top: 20px; border-radius: 10px; border: 1px solid #e2e8f0; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; white-space: nowrap; }
        th, td { padding: 12px 14px; border-bottom: 1px solid #e2e8f0; text-align: left; }
        th { background: #f8fafc; color: #475569; font-weight: 600; }
        .code { background: #0f172a; color: #34d399; padding: 8px 12px; display: block; word-break: break-all; font-family: monospace; border-radius: 6px; font-size: 12px; white-space: normal; max-width: 280px; }
        .settings-box { background: #fffbeb; padding: 20px; border-radius: 12px; border: 1px solid #fde68a; box-sizing: border-box; }
        .usage-badge { background: #e0e7ff; color: #3730a3; padding: 4px 8px; border-radius: 4px; font-weight: 600; font-size: 12px; display: inline-block; margin-bottom: 2px; }
        .status-online { color: #15803d; font-weight: 600; background: #dcfce7; padding: 4px 10px; border-radius: 12px; font-size: 12px; display: inline-block; }
        .status-offline { color: #64748b; font-weight: 600; background: #f1f5f9; padding: 4px 10px; border-radius: 12px; font-size: 12px; display: inline-block; }
        .status-error { color: #b91c1c; font-weight: 600; background: #fee2e2; padding: 4px 10px; border-radius: 12px; font-size: 12px; display: inline-block; }

        /* Responsive Mobile Layout Fixes */
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { padding: 15px; border-radius: 12px; }
            .header { flex-direction: column; align-items: stretch; gap: 12px; text-align: center; }
            .header h2 { font-size: 20px; }
            .btn-logout { width: 100%; box-sizing: border-box; text-align: center; }
            
            .add-form { flex-direction: column; align-items: stretch !important; padding: 15px !important; }
            .add-form input, .add-form button, .add-form .input-group { width: 100% !important; margin: 4px 0 !important; box-sizing: border-box; }
            .add-form button[type="submit"] { padding: 14px; font-size: 15px; margin-top: 8px !important; }
            
            .settings-grid { flex-direction: column !important; gap: 15px !important; margin-top: 20px !important; }
            .settings-box { width: 100% !important; min-width: 100% !important; padding: 15px !important; }
            .settings-box input, .settings-box button { width: 100% !important; margin: 4px 0 !important; box-sizing: border-box; }
            .settings-box button { padding: 12px; }
        }
    </style>
    <script>
        function copyToClipboard(id) {
            const text = document.getElementById(id).innerText;
            navigator.clipboard.writeText(text).then(() => {
                showToast('✅ Client URL Copied!');
            }).catch(() => {
                showToast('✅ Copied!');
            });
        }
        function genPass() {
            const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
            let res = '';
            for (let i = 0; i < 16; i++) {
                res += chars.charAt(Math.floor(Math.random() * chars.length));
            }
            document.getElementById('user_pass_input').value = res;
            showToast('🎲 Random Password Generated');
        }
        function showToast(msg) {
            let t = document.getElementById('toast');
            if (!t) {
                t = document.createElement('div');
                t.id = 'toast';
                t.style.cssText = 'position:fixed;bottom:25px;left:50%;transform:translateX(-50%);background:#0f172a;color:#34d399;padding:12px 24px;border-radius:30px;font-weight:600;font-size:14px;box-shadow:0 10px 25px rgba(0,0,0,0.25);z-index:9999;transition:opacity 0.3s;opacity:0;pointer-events:none;';
                document.body.appendChild(t);
            }
            t.innerText = msg;
            t.style.opacity = '1';
            setTimeout(() => { t.style.opacity = '0'; }, 2000);
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2 style="margin:0; color:#0f172a;">⚡ Hysteria 2 User Management</h2>
            <a href="/logout" class="btn-logout">🚪 Logout</a>
        </div>

        <form method="POST" action="/add" class="add-form" style="display: flex; flex-wrap: wrap; gap: 10px; align-items: center; background: #f8fafc; padding: 18px; border-radius: 12px; border: 1px solid #e2e8f0;">
            <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
            <input type="text" name="user_name" placeholder="📝 Name" required style="flex: 1; min-width: 120px;">
            <div class="input-group" style="display: flex; flex: 1.2; min-width: 180px; gap: 4px;">
                <input type="text" name="user_pass" id="user_pass_input" placeholder="👤 Password (Blank = Auto)" style="flex: 1; margin: 0;">
                <button type="button" onclick="genPass()" style="background: #64748b; margin: 0; padding: 10px 12px;" title="Generate Random Password">🎲 Auto</button>
            </div>
            <input type="number" step="0.1" name="limit_gb" placeholder="Data Limit (GB) [0=Unl]" required style="flex: 1; min-width: 130px;" value="0">
            <input type="number" name="days" placeholder="Days [0=Unl]" required style="flex: 1; min-width: 100px;" value="0">
            <button type="submit">➕ Add User</button>
        </form>

        <div class="table-wrapper">
            <table>
                <tr>
                    <th>Name</th>
                    <th>Password</th>
                    <th>Status</th>
                    <th>Data Usage / Limit</th>
                    <th>Left Days</th>
                    <th>Last Seen</th>
                    <th>Client URL</th>
                    <th>Action</th>
                </tr>
                {% for user in users %}
                <tr>
                    <td><b>{{ user['name'] or 'Unknown' }}</b></td>
                    <td><code>{{ user['password'] }}</code></td>
                    <td>
                        {% if user['status'] == 'Online' %}
                            <span class="status-online">🟢 Online</span>
                        {% elif user['status'] == 'Offline' %}
                            <span class="status-offline">⚪ Offline</span>
                        {% else %}
                            <span class="status-error">🔴 {{ user['status'] }}</span>
                        {% endif %}
                    </td>
                    <td style="min-width: 140px;">
                        <span class="usage-badge">⬇️ {{ user['tx'] | format_bytes }}</span><br>
                        <span class="usage-badge" style="background:#dcfce7;color:#15803d;">⬆️ {{ user['rx'] | format_bytes }}</span><br>
                        <small style="color: #64748b; font-weight: 600;">Total: {{ (user['tx'] + user['rx']) | format_bytes }} / {% if user['limit_gb'] > 0 %}{{ user['limit_gb'] }} GB{% else %}Unlimited{% endif %}</small>
                    </td>
                    <td>
                        {% if user['expiry_date'] %}
                            <b>{{ user['left_days'] }} Days</b><br>
                            <small style="color: #64748b;">(Exp: {{ user['expiry_date'] }})</small>
                        {% else %}
                            <b>Unlimited</b>
                        {% endif %}
                    </td>
                    <td style="min-width: 110px;">
                        <b>{{ user['last_seen'] | last_seen }}</b><br>
                        <small style="color: #64748b;">{{ user['last_seen'] or 'Never' }}</small>
                    </td>
                    <td>
                        <span class="code" id="url_{{ loop.index }}">hy2://{{ user['password'] | urlencode_pass }}@{{ domain }}:{{ port }}/?security=tls&insecure=1&sni={{ domain }}#{{ (user['name'] + server_tag) | urlencode }}</span>
                        <button class="btn-copy" onclick="copyToClipboard('url_{{ loop.index }}')">📋 Copy URL</button>
                    </td>
                    <td>
                        <form method="POST" action="/delete" style="margin:0;" onsubmit="return confirm('Delete this user?');">
                            <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
                            <input type="hidden" name="user_pass" value="{{ user['password'] }}">
                            <button type="submit" class="btn-danger">🗑️</button>
                        </form>
                    </td>
                </tr>
                {% endfor %}
            </table>
        </div>

        <div class="settings-grid" style="display: flex; flex-wrap: wrap; gap: 20px; margin-top: 30px;">
            <div class="settings-box" style="flex: 1; min-width: 300px; margin-top: 0;">
                <h3 style="margin-top: 0; color: #92400e;">⚙️ Change Admin Password</h3>
                <form method="POST" action="/change_pass" style="display: flex; flex-wrap: wrap; gap: 10px;">
                    <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
                    <input type="password" name="current_pass" placeholder="Current Password" required style="flex: 1;">
                    <input type="password" name="new_pass" placeholder="New Password" required style="flex: 1;">
                    <button type="submit" style="background: #d97706;">🔄 Update Password</button>
                </form>
            </div>
            <div class="settings-box" style="flex: 1; min-width: 300px; margin-top: 0; background: #eff6ff; border-color: #bfdbfe;">
                <h3 style="margin-top: 0; color: #1e40af;">🏷️ Server Profile Tag Suffix</h3>
                <form method="POST" action="/update_tag" style="display: flex; flex-wrap: wrap; gap: 10px;">
                    <input type="hidden" name="csrf_token" value="{{ csrf_token() }}">
                    <input type="text" name="server_tag" value="{{ server_tag }}" placeholder="e.g. _Server01 or _SG" style="flex: 1; min-width: 150px;">
                    <button type="submit" style="background: #2563eb;">💾 Save Tag</button>
                </form>
                <small style="color: #4b5563; display: block; margin-top: 8px;">Appended to every Client Key name (e.g. <b>#User{{ server_tag or '_Server01' }}</b>)</small>
            </div>
        </div>
    </div>
</body>
</html>
"""


@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        if verify_admin_pass(request.form.get("admin_pass", "")):
            session['logged_in'] = True
            return redirect(url_for("index"))
        else:
            error = "Invalid Admin Password!"
    return render_template_string(LOGIN_TEMPLATE, error=error)


@app.route("/logout")
def logout():
    session.pop('logged_in', None)
    return redirect(url_for("login"))


@app.route("/")
def index():
    if not session.get('logged_in'):
        return redirect(url_for("login"))
    conn = get_db()
    db_users = conn.execute("SELECT * FROM users").fetchall()
    domain = request.host.split(":")[0]
    stats = get_traffic_stats()
    online_map = get_online_clients()
    users_data = []
    now = datetime.datetime.now()
    now_str = now.strftime('%Y-%m-%d %H:%M:%S')
    users_to_update_last_seen = []

    for u in db_users:
        user = dict(u)
        pwd = user['password']
        quoted_pwd = urllib.parse.quote(pwd, safe='')
        unquoted_pwd = urllib.parse.unquote(pwd)

        user_stat = (
            stats.get(pwd) or
            stats.get(quoted_pwd) or
            stats.get(unquoted_pwd) or
            {}
        )
        user['tx'] = user_stat.get('tx', 0)
        user['rx'] = user_stat.get('rx', 0)
        total_used = user['tx'] + user['rx']

        online_cnt = (
            online_map.get(pwd, 0) or
            online_map.get(quoted_pwd, 0) or
            online_map.get(unquoted_pwd, 0)
        )
        is_online = online_cnt > 0
        if is_online:
            user['status'] = 'Online'
            user['last_seen'] = now_str
            users_to_update_last_seen.append(pwd)
        else:
            user['status'] = 'Offline'

        # Check expiry date (valid until 23:59:59 of expiry day)
        if user['expiry_date']:
            try:
                exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                left = (exp_date - now).days
                user['left_days'] = left if left >= 0 else 0
                if now > exp_date:
                    user['status'] = 'Expired'
            except Exception:
                user['left_days'] = 'Error'
        else:
            user['left_days'] = 'Unlimited'

        # Check data limit
        if user['limit_gb'] and user['limit_gb'] > 0:
            if total_used >= (user['limit_gb'] * 1024 * 1024 * 1024):
                user['status'] = 'Data Full'

        users_data.append(user)

    if users_to_update_last_seen:
        for pass_val in users_to_update_last_seen:
            conn.execute("UPDATE users SET last_seen = ? WHERE password = ?", (now_str, pass_val))
        conn.commit()

    conn.close()

    return render_template_string(
        HTML_TEMPLATE,
        users=users_data,
        domain=domain,
        port=HYSTERIA_PORT,
        server_tag=get_server_tag(),
    )


@app.route("/update_tag", methods=["POST"])
def update_tag():
    if not session.get('logged_in'):
        return redirect(url_for("index"))
    tag = request.form.get("server_tag", "").strip()
    conn = get_db()
    conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('server_tag', ?)", (tag,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))


@app.route("/add", methods=["POST"])
def add_user():
    if not session.get('logged_in'):
        return redirect(url_for("login"))

    user_name = request.form.get("user_name", "Unknown").strip()
    user_pass = request.form.get("user_pass", "").strip()
    if not user_pass:
        chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
        user_pass = ''.join(secrets.choice(chars) for _ in range(16))

    try: limit_gb = float(request.form.get("limit_gb", 0))
    except Exception: limit_gb = 0
    try: days = int(request.form.get("days", 0))
    except Exception: days = 0

    expiry_date = None
    if days > 0:
        expiry_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')

    conn = get_db()
    try:
        conn.execute(
            "INSERT INTO users (password, name, limit_gb, expiry_date, last_seen) VALUES (?, ?, ?, ?, NULL)",
            (user_pass, user_name, limit_gb, expiry_date),
        )
        conn.commit()
    except Exception:
        pass
    conn.close()
    return redirect(url_for("index"))


@app.route("/delete", methods=["POST"])
def delete_user():
    if not session.get('logged_in'):
        return redirect(url_for("login"))
    conn = get_db()
    conn.execute("DELETE FROM users WHERE password = ?", (request.form.get("user_pass"),))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))


@app.route("/change_pass", methods=["POST"])
def change_pass():
    if not session.get('logged_in'):
        return redirect(url_for("login"))
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
    if not s:
        return "Hysteria2"
    return urllib.parse.quote_plus(str(s))


@app.template_filter('format_bytes')
def format_bytes(size):
    if not size:
        return "0 B"
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
    if not s:
        return ""
    return urllib.parse.quote(str(s), safe='')


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
