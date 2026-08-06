"""
Hysteria 2 + Python Web Management Panel
========================================
Flask-based web UI for managing Hysteria 2 VPN users with:
- User add/delete management
- Data limits (GB)
- Expiry dates (days)
- Real-time traffic statistics & online status
- Hysteria HTTP auth backend

Run (development):
    python app.py
    # listens on 127.0.0.1:5000

In production, this is served via Nginx reverse proxy and
managed by systemd (see config/hysteria-panel.service).
"""

from flask import Flask, request, jsonify, render_template_string, redirect, url_for, session
import sqlite3, urllib.parse, urllib.request, json, os, datetime

app = Flask(__name__)
app.secret_key = os.urandom(24)
DB_FILE = '/opt/hysteria-panel/users.db'

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
# Anti-DPI obfuscation password (must match config.yaml obfs.salamander.password)
OBFS_PASS = 'OBFS_PASS_PLACEHOLDER'
# Traffic stats secret (must match config.yaml trafficStats.secret)
STATS_SECRET = 'STATS_SECRET_PLACEHOLDER'


def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute("CREATE TABLE IF NOT EXISTS users (password TEXT PRIMARY KEY, name TEXT)")
    conn.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
    try:
        conn.execute("ALTER TABLE users ADD COLUMN name TEXT")
    except Exception:
        pass
    try:
        conn.execute("ALTER TABLE users ADD COLUMN limit_gb REAL DEFAULT 0")
    except Exception:
        pass
    try:
        conn.execute("ALTER TABLE users ADD COLUMN expiry_date TEXT")
    except Exception:
        pass
    try:
        conn.execute("ALTER TABLE users ADD COLUMN last_seen TEXT")
    except Exception:
        pass
    if not conn.execute("SELECT value FROM settings WHERE key = 'admin_pass'").fetchone():
        conn.execute("INSERT INTO settings (key, value) VALUES ('admin_pass', 'admin123')")
    conn.commit()
    conn.close()


init_db()


def get_admin_pass():
    conn = get_db()
    row = conn.execute("SELECT value FROM settings WHERE key = 'admin_pass'").fetchone()
    conn.close()
    return row['value'] if row else 'admin123'


def get_server_tag():
    conn = get_db()
    row = conn.execute("SELECT value FROM settings WHERE key = 'server_tag'").fetchone()
    conn.close()
    return row['value'] if row else ''


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
    """Hysteria HTTP auth endpoint. Validates user password + limits."""
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
        now_str = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        conn.execute("UPDATE users SET last_seen = ? WHERE password = ?", (now_str, real_pass))
        conn.commit()
        conn.close()

        # 1. Check Expiry Date
        if user['expiry_date']:
            exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d')
            if datetime.datetime.now() > exp_date:
                return jsonify({"ok": False}), 401

        # 2. Check Data Limit
        limit_gb = user['limit_gb']
        if limit_gb and limit_gb > 0:
            stats = get_traffic_stats()
            user_stat = stats.get(real_pass) or stats.get(raw_auth, {})
            total_used = user_stat.get('tx', 0) + user_stat.get('rx', 0)
            if total_used >= (limit_gb * 1024 * 1024 * 1024):
                return jsonify({"ok": False}), 401

        return jsonify({"ok": True, "id": real_pass}), 200

    conn.close()
    return jsonify({"ok": False}), 401


LOGIN_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Hysteria 2 Manager</title>
    <style>
        body { font-family: sans-serif; background: #f3f4f6; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .login-box { background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); text-align: center; width: 100%; max-width: 350px; }
        input { width: 90%; padding: 12px; margin: 15px 0; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; font-size: 16px; }
        button { width: 100%; padding: 12px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; font-size: 16px; }
        .error { color: #ef4444; margin-bottom: 10px; font-size: 14px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="login-box">
        <h2>⚡ Hysteria 2 Panel</h2>
        {% if error %}<div class="error">{{ error }}</div>{% endif %}
        <form method="POST">
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
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hysteria 2 Manager</title>
    <style>
        body { font-family: sans-serif; background: #f3f4f6; padding: 20px; margin: 0; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 10px; }
        .container { max-width: 1250px; margin: auto; background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        input, button { padding: 10px; margin: 5px; border-radius: 4px; border: 1px solid #ccc; }
        button { background: #3b82f6; color: white; border: none; cursor: pointer; font-weight: bold; }
        .btn-copy { background: #10b981; padding: 6px 12px; font-size: 12px; margin-top: 5px; }
        .btn-danger { background: #ef4444; }
        .btn-logout { background: #6b7280; text-decoration: none; padding: 8px 15px; color: white; border-radius: 4px; font-size: 14px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 14px; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        th { background: #f9fafb; }
        .code { background: #1f2937; color: #10b981; padding: 8px; display: block; word-break: break-all; font-family: monospace; border-radius: 4px; }
        .settings-box { background: #fffbeb; padding: 15px; border-radius: 8px; border: 1px solid #fde68a; margin-top: 30px; }
        .usage-badge { background: #e0e7ff; color: #b45309; padding: 4px 8px; border-radius: 4px; font-weight: bold; font-size: 13px; display: inline-block; margin-bottom: 2px; }
        .status-online { color: #16a34a; font-weight: bold; background: #dcfce7; padding: 4px 10px; border-radius: 12px; font-size: 13px; display: inline-block; }
        .status-offline { color: #4b5563; font-weight: bold; background: #f3f4f6; padding: 4px 10px; border-radius: 12px; font-size: 13px; display: inline-block; }
        .status-error { color: #dc2626; font-weight: bold; background: #fee2e2; padding: 4px 10px; border-radius: 12px; font-size: 13px; display: inline-block; }
    </style>
    <script>
        function copyToClipboard(elementId) {
            var text = document.getElementById(elementId).innerText;
            navigator.clipboard.writeText(text).then(function() { alert('✅ URL Copied!'); });
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2 style="margin: 0;">⚡ Hysteria 2 User Management</h2>
            <a href="/logout" class="btn-logout">🚪 Logout</a>
        </div>

        <form method="POST" action="/add" style="display: flex; flex-wrap: wrap; gap: 10px; align-items: center; background: #f9fafb; padding: 15px; border-radius: 8px;">
            <input type="text" name="user_name" placeholder="📝 Name" required style="flex: 1; min-width: 100px;">
            <input type="text" name="user_pass" placeholder="👤 Password" required style="flex: 1; min-width: 100px;">
            <input type="number" step="0.1" name="limit_gb" placeholder="Data Limit (GB) [0=Unl]" required style="flex: 1; min-width: 120px;" value="0">
            <input type="number" name="days" placeholder="Days [0=Unl]" required style="flex: 1; min-width: 100px;" value="0">
            <button type="submit">➕ Add User</button>
        </form>

        <div style="overflow-x: auto;">
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
                    <td>{{ user['password'] }}</td>
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
                        <span class="usage-badge" style="background: #dcfce7; color: #4338ca;">⬆️ {{ user['rx'] | format_bytes }}</span><br>
                        <small style="color: #6b7280; font-weight: bold;">
                            Total: {{ (user['tx'] + user['rx']) | format_bytes }} /
                            {% if user['limit_gb'] > 0 %}{{ user['limit_gb'] }} GB{% else %}Unlimited{% endif %}
                        </small>
                    </td>
                    <td>
                        {% if user['expiry_date'] %}
                            <b>{{ user['left_days'] }} Days</b><br>
                            <small style="color: #6b7280;">(Exp: {{ user['expiry_date'] }})</small>
                        {% else %}
                            <b>Unlimited</b>
                        {% endif %}
                    </td>
                    <td style="min-width: 110px;">
                        <b>{{ user['last_seen'] | last_seen }}</b><br>
                        <small style="color: #6b7280;">{{ user['last_seen'] or 'Never' }}</small>
                    </td>
                    <td>
                        <span class="code" id="url_{{ loop.index }}">hy2://{{ user['password'] | urlencode_pass }}@{{ domain }}:{{ port }}/?insecure=0&sni={{ domain }}&mport=20000-50000#{{ (user['name'] + server_tag) | urlencode }}</span>
                        <button class="btn-copy" onclick="copyToClipboard('url_{{ loop.index }}')">📋 Copy URL</button>
                    </td>
                    <td>
                        <form method="POST" action="/delete" style="margin:0;" onsubmit="return confirm('Delete this user?');">
                            <input type="hidden" name="user_pass" value="{{ user['password'] }}">
                            <button type="submit" class="btn-danger">🗑️</button>
                        </form>
                    </td>
                </tr>
                {% endfor %}
            </table>
        </div>

        <div style="display: flex; flex-wrap: wrap; gap: 20px; margin-top: 30px;">
            <div class="settings-box" style="flex: 1; min-width: 300px; margin-top: 0;">
                <h3 style="margin-top: 0; color: #92400e;">⚙️ Change Admin Password</h3>
                <form method="POST" action="/change_pass" style="display: flex; flex-wrap: wrap; gap: 10px;">
                    <input type="password" name="current_pass" placeholder="Current Password" required>
                    <input type="password" name="new_pass" placeholder="New Password" required>
                    <button type="submit" style="background: #d97706;">🔄 Update Password</button>
                </form>
            </div>
            <div class="settings-box" style="flex: 1; min-width: 300px; margin-top: 0; background: #eff6ff; border-color: #bfdbfe;">
                <h3 style="margin-top: 0; color: #1e40af;">🏷️ Server Profile Tag Suffix</h3>
                <form method="POST" action="/update_tag" style="display: flex; flex-wrap: wrap; gap: 10px;">
                    <input type="text" name="server_tag" value="{{ server_tag }}" placeholder="e.g. _Server01 or _SG" style="flex: 1; min-width: 150px;">
                    <button type="submit" style="background: #2563eb;">💾 Save Tag</button>
                </form>
                <small style="color: #4b5563; display: block; margin-top: 8px;">Appended to the end of every Client Key name (e.g. <b>#User{{ server_tag or '_Server01' }}</b>)</small>
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
        if request.form.get("admin_pass") == get_admin_pass():
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

        # Check online status from Hysteria /online API
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

        # Check expiry date
        if user['expiry_date']:
            exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d')
            left = (exp_date - now).days
            user['left_days'] = left if left >= 0 else 0
            if left < 0:
                user['status'] = 'Expired'
        else:
            user['left_days'] = 'Unlimited'

        # Check data limit
        if user['limit_gb'] and user['limit_gb'] > 0:
            if total_used >= (user['limit_gb'] * 1024 * 1024 * 1024):
                user['status'] = 'Data Full'

        users_data.append(user)

    # Batch update last_seen for currently online users
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
        return redirect(url_for("login"))
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

    user_name = request.form.get("user_name", "Unknown")
    user_pass = request.form.get("user_pass")
    limit_gb = float(request.form.get("limit_gb", 0))
    days = int(request.form.get("days", 0))

    expiry_date = None
    if days > 0:
        expiry_date = (datetime.datetime.now() + datetime.timedelta(days=days)).strftime('%Y-%m-%d')

    if user_pass:
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
    if request.form.get("current_pass") == get_admin_pass() and request.form.get("new_pass"):
        conn = get_db()
        conn.execute("UPDATE settings SET value = ? WHERE key = 'admin_pass'", (request.form.get("new_pass"),))
        conn.commit()
        conn.close()
        session.pop('logged_in', None)
        return redirect(url_for("login"))
    return redirect(url_for("index"))


@app.template_filter('urlencode')
def urlencode_filter(s):
    if not s:
        return "Hysteria2"
    if type(s) == 'Markup':
        s = s.unescape()
    return urllib.parse.quote_plus(s.encode('utf8'))


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
