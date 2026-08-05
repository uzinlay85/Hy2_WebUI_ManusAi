"""
Hysteria 2 + Python Web Management Panel
========================================
Flask-based web UI for managing Hysteria 2 VPN users with:
- User add/delete management
- Data limits (GB)
- Expiry dates (days)
- Real-time traffic statistics
- Hysteria HTTP auth backend

Run (development):
    python app.py
    # listens on 127.0.0.1:5000

In production, this is served via Nginx reverse proxy and
managed by systemd (see config/hysteria-panel.service).

NOTE: OBFS_PASS and STATS_SECRET are injected by install_hysteria.sh
      via `sed` after this file is written to /opt/hysteria-panel/app.py.
      The placeholders below are replaced with real values at install time.
"""

from flask import Flask, request, jsonify, render_template_string, redirect, url_for, session
import sqlite3, urllib.parse, urllib.request, json, os, datetime

app = Flask(__name__)
app.secret_key = os.urandom(24)
DB_FILE = '/opt/hysteria-panel/users.db'
HYSTERIA_PORT = '10443'
# Anti-DPI obfuscation password (must match config.yaml obfs.salamander.password)
# Replaced by install_hysteria.sh: sed -i "s/OBFS_PASS_PLACEHOLDER/$OBFS_PASS/g"
OBFS_PASS = 'OBFS_PASS_PLACEHOLDER'
# Traffic stats secret (must match config.yaml trafficStats.secret)
# Replaced by install_hysteria.sh: sed -i "s/STATS_SECRET_PLACEHOLDER/$STATS_SECRET/g"
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


def get_traffic_stats():
    try:
        # Hysteria 2 trafficStats API expects `Authorization: <secret>` header directly (no Bearer prefix)
        req = urllib.request.Request(
            "http://127.0.0.1:4000/traffic",
            headers={"Authorization": STATS_SECRET}
        )
        with urllib.request.urlopen(req, timeout=2) as response:
            return json.loads(response.read().decode())
    except Exception:
        return {}


@app.route("/auth", methods=["POST"])
def auth():
    """Hysteria HTTP auth endpoint. Validates user password + limits."""
    data = request.json
    client_auth = data.get("auth")
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE password = ?", (client_auth,)).fetchone()
    conn.close()

    if user:
        # 1. Check Expiry Date
        if user['expiry_date']:
            exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d')
            if datetime.datetime.now() > exp_date:
                return jsonify({"ok": False}), 401

        # 2. Check Data Limit
        limit_gb = user['limit_gb']
        if limit_gb and limit_gb > 0:
            stats = get_traffic_stats()
            user_stat = stats.get(client_auth, {})
            total_used = user_stat.get('tx', 0) + user_stat.get('rx', 0)
            if total_used >= (limit_gb * 1024 * 1024 * 1024):
                return jsonify({"ok": False}), 401

        return jsonify({"ok": True, "id": client_auth}), 200

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
        .container { max-width: 1200px; margin: auto; background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
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
        .status-active { color: #15803d; font-weight: bold; }
        .status-error { color: #b91c1c; font-weight: bold; }
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
                    <th>Client URL</th>
                    <th>Action</th>
                </tr>
                {% for user in users %}
                <tr>
                    <td><b>{{ user['name'] or 'Unknown' }}</b></td>
                    <td>{{ user['password'] }}</td>
                    <td>
                        {% if user['status'] == 'Active' %}
                            <span class="status-active">🟢 Active</span>
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
                    <td>
                        <span class="code" id="url_{{ loop.index }}">hysteria2://{{ user['password'] }}@{{ domain }}:{{ port }}/?insecure=0&sni={{ domain }}&obfs=salamander&obfs-password={{ obfs_pass }}&mport=20000-50000#{{ user['name'] | urlencode }}</span>
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

        <div class="settings-box">
            <h3 style="margin-top: 0; color: #92400e;">⚙️ Change Admin Password</h3>
            <form method="POST" action="/change_pass" style="display: flex; flex-wrap: wrap; gap: 10px;">
                <input type="password" name="current_pass" placeholder="Current Password" required>
                <input type="password" name="new_pass" placeholder="New Password" required>
                <button type="submit" style="background: #d97706;">🔄 Update</button>
            </form>
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
    conn.close()

    domain = request.host.split(":")[0]
    stats = get_traffic_stats()

    users_data = []
    now = datetime.datetime.now()

    for u in db_users:
        user = dict(u)
        user_stat = stats.get(user['password'], {})
        user['tx'] = user_stat.get('tx', 0)
        user['rx'] = user_stat.get('rx', 0)
        total_used = user['tx'] + user['rx']

        user['status'] = 'Active'

        if user['expiry_date']:
            exp_date = datetime.datetime.strptime(user['expiry_date'], '%Y-%m-%d')
            left = (exp_date - now).days
            user['left_days'] = left if left >= 0 else 0
            if left < 0:
                user['status'] = 'Expired'
        else:
            user['left_days'] = 'Unlimited'

        if user['limit_gb'] and user['limit_gb'] > 0:
            if total_used >= (user['limit_gb'] * 1024 * 1024 * 1024):
                user['status'] = 'Data Full'

        users_data.append(user)

    return render_template_string(
        HTML_TEMPLATE,
        users=users_data,
        domain=domain,
        port=HYSTERIA_PORT,
        obfs_pass=OBFS_PASS,       # FIX: was missing — obfs URL param now shows correctly
    )


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
                "INSERT INTO users (password, name, limit_gb, expiry_date) VALUES (?, ?, ?, ?)",
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


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
