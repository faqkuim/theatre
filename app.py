import os
import sqlite3
from datetime import date
from functools import wraps

from flask import Flask, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

BASE_DIR = os.path.dirname(__file__)
DB_PATH  = os.path.join(BASE_DIR, 'beauty.db')

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret')


# ── DB helpers ────────────────────────────────────────────

def get_db():
    if 'db' not in g:
        g.db = sqlite3.connect(DB_PATH, detect_types=sqlite3.PARSE_DECLTYPES)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(error=None):
    db = g.pop('db', None)
    if db is not None:
        db.close()


def run_script(filename):
    db = get_db()
    path = os.path.join(BASE_DIR, 'sql', filename)
    with open(path, 'r', encoding='utf-8') as f:
        db.executescript(f.read())
    db.commit()


def ensure_user(email, login, password, full_name, phone, is_admin=0):
    db = get_db()
    if db.execute('SELECT id FROM users WHERE email=?', (email,)).fetchone():
        return
    db.execute(
        'INSERT INTO users(email,login,password_hash,full_name,phone,is_admin) VALUES(?,?,?,?,?,?)',
        (email, login, generate_password_hash(password), full_name, phone, is_admin),
    )


def ensure_db():
    if not os.path.exists(DB_PATH):
        run_script('schema.sql')
        run_script('seed.sql')
        ensure_user('client@example.com', 'client1', 'password123',
                    'Ирина Смирнова', '+7-999-111-22-33', 0)
        ensure_user('admin@example.com', 'admin', 'admin12345',
                    'Администратор', '+7-999-000-00-00', 1)
        get_db().commit()


def log_action(user_id, action):
    db = get_db()
    db.execute(
        'INSERT INTO auth_log(user_id,action,ip,user_agent) VALUES(?,?,?,?)',
        (user_id, action, request.remote_addr, request.headers.get('User-Agent', '')),
    )
    db.commit()


def current_user():
    uid = session.get('user_id')
    if not uid:
        return None
    return get_db().execute('SELECT * FROM users WHERE id=?', (uid,)).fetchone()


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = current_user()
        if not user:
            return redirect(url_for('login'))
        return view(user, *args, **kwargs)
    return wrapped


def admin_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = current_user()
        if not (user and user['is_admin']):
            return redirect(url_for('login'))
        return view(user, *args, **kwargs)
    return wrapped


# ── Public routes ─────────────────────────────────────────

@app.route('/')
def index():
    ensure_db()
    db = get_db()
    services = db.execute(
        'SELECT * FROM services WHERE is_active=1 ORDER BY category, name'
    ).fetchall()
    masters = db.execute(
        'SELECT * FROM masters WHERE is_active=1'
    ).fetchall()
    reviews = db.execute(
        '''SELECT r.rating, r.body, r.created_at, u.full_name,
                  m.full_name AS master_name, s.name AS service_name
           FROM reviews r
           JOIN users u ON u.id=r.user_id
           LEFT JOIN masters m ON m.id=r.master_id
           LEFT JOIN services s ON s.id=r.service_id
           WHERE r.is_approved=1
           ORDER BY r.created_at DESC LIMIT 6'''
    ).fetchall()
    return render_template('index.html', services=services,
                           masters=masters, reviews=reviews)


@app.route('/register', methods=['GET', 'POST'])
def register():
    ensure_db()
    if request.method != 'POST':
        return render_template('register.html')

    login_name = request.form.get('login', '').strip()
    full_name  = request.form.get('full_name', '').strip()
    phone      = request.form.get('phone', '').strip()
    email      = request.form.get('email', '').strip().lower()
    password   = request.form.get('password', '')

    if not (login_name and full_name and phone and email and password):
        return render_template('register.html', error='Заполните все поля')
    if len(password) < 8:
        return render_template('register.html', error='Пароль должен быть не менее 8 символов')

    db = get_db()
    if db.execute('SELECT 1 FROM users WHERE login=? OR email=?',
                  (login_name, email)).fetchone():
        return render_template('register.html', error='Логин или email уже заняты')

    db.execute(
        'INSERT INTO users(email,login,password_hash,full_name,phone,is_admin) VALUES(?,?,?,?,?,0)',
        (email, login_name, generate_password_hash(password), full_name, phone),
    )
    db.commit()
    user_id = db.execute('SELECT id FROM users WHERE email=?', (email,)).fetchone()['id']
    log_action(user_id, 'register')
    session['user_id'] = user_id
    session['is_admin'] = 0
    return redirect(url_for('dashboard'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    ensure_db()
    if request.method != 'POST':
        return render_template('login.html')

    email    = request.form.get('email', '').strip().lower()
    password = request.form.get('password', '')
    db       = get_db()
    user     = db.execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
    if not user or not check_password_hash(user['password_hash'], password):
        return render_template('login.html', error='Неверный email или пароль')

    session['user_id'] = user['id']
    session['is_admin'] = bool(user['is_admin'])
    log_action(user['id'], 'login')
    return redirect(url_for('dashboard'))


@app.route('/logout')
def logout():
    uid = session.get('user_id')
    session.clear()
    if uid:
        log_action(uid, 'logout')
    return redirect(url_for('index'))


# ── Client cabinet ────────────────────────────────────────

@app.route('/dashboard')
@login_required
def dashboard(user):
    ensure_db()
    db       = get_db()
    masters  = db.execute('SELECT * FROM masters WHERE is_active=1').fetchall()
    services = db.execute(
        'SELECT * FROM services WHERE is_active=1 ORDER BY category, name'
    ).fetchall()
    sm_rows = db.execute(
        '''SELECT ms.service_id, m.id, m.full_name, m.specialization
           FROM master_services ms
           JOIN masters m ON m.id = ms.master_id
           WHERE m.is_active = 1
           ORDER BY ms.service_id, m.full_name'''
    ).fetchall()
    service_masters = {}
    for row in sm_rows:
        sid = str(row['service_id'])
        service_masters.setdefault(sid, []).append(
            {'id': row['id'], 'name': row['full_name'], 'spec': row['specialization']}
        )
    my_appointments = db.execute(
        '''SELECT a.id, a.appt_date, a.appt_time, a.status, a.comment,
                  m.full_name AS master_name,
                  s.name AS service_name, s.price
           FROM appointments a
           JOIN masters m  ON m.id=a.master_id
           JOIN services s ON s.id=a.service_id
           WHERE a.user_id=?
           ORDER BY a.appt_date DESC, a.appt_time DESC''',
        (user['id'],),
    ).fetchall()
    my_reviews = db.execute(
        '''SELECT r.id, r.rating, r.body, r.is_approved, r.created_at,
                  m.full_name AS master_name, s.name AS service_name
           FROM reviews r
           LEFT JOIN masters m  ON m.id=r.master_id
           LEFT JOIN services s ON s.id=r.service_id
           WHERE r.user_id=?
           ORDER BY r.created_at DESC''',
        (user['id'],),
    ).fetchall()
    today = date.today()
    years = [today.year + i for i in range(2)]
    return render_template('dashboard.html',
                           user=user,
                           masters=masters,
                           services=services,
                           service_masters=service_masters,
                           appointments=my_appointments,
                           reviews=my_reviews,
                           today=today.isoformat(),
                           years=years)


@app.route('/book', methods=['POST'])
@login_required
def book(user):
    master_id  = request.form.get('master_id')
    service_id = request.form.get('service_id')
    appt_day   = request.form.get('appt_day', '').strip()
    appt_month = request.form.get('appt_month', '').strip()
    appt_year  = request.form.get('appt_year', '').strip()
    appt_date  = f"{appt_year}-{appt_month}-{appt_day}" if (appt_day and appt_month and appt_year) else ''
    appt_time  = request.form.get('appt_time', '').strip()
    comment    = request.form.get('comment', '').strip()
    if not (master_id and service_id and appt_date and appt_time):
        return redirect(url_for('dashboard'))
    db = get_db()
    db.execute(
        '''INSERT INTO appointments(user_id,master_id,service_id,appt_date,appt_time,comment)
           VALUES(?,?,?,?,?,?)''',
        (user['id'], master_id, service_id, appt_date, appt_time, comment or None),
    )
    db.commit()
    return redirect(url_for('dashboard'))


@app.route('/review', methods=['POST'])
@login_required
def review(user):
    master_id  = request.form.get('master_id') or None
    service_id = request.form.get('service_id') or None
    rating     = request.form.get('rating', type=int)
    body       = request.form.get('body', '').strip()
    if not (rating and body and 1 <= rating <= 5):
        return redirect(url_for('dashboard'))
    db = get_db()
    db.execute(
        'INSERT INTO reviews(user_id,master_id,service_id,rating,body) VALUES(?,?,?,?,?)',
        (user['id'], master_id, service_id, rating, body),
    )
    db.commit()
    return redirect(url_for('dashboard'))


# ── Admin panel ───────────────────────────────────────────

@app.route('/admin')
@admin_required
def admin(user):
    db            = get_db()
    status_filter = request.args.get('status') or ''
    master_filter = request.args.get('master_id', type=int) or 0
    where_parts, params = [], []

    if status_filter:
        where_parts.append('a.status=?')
        params.append(status_filter)
    if master_filter:
        where_parts.append('a.master_id=?')
        params.append(master_filter)

    where = ('WHERE ' + ' AND '.join(where_parts)) if where_parts else ''

    per_page = 10
    page     = max(1, request.args.get('page', 1, type=int))
    total    = db.execute(
        f'SELECT COUNT(*) FROM appointments a {where}', params
    ).fetchone()[0]
    total_pages = max(1, (total + per_page - 1) // per_page)
    page        = min(page, total_pages)

    rows = db.execute(
        f'''SELECT a.id, a.appt_date, a.appt_time, a.status, a.comment,
                   u.full_name AS client_name, u.phone, u.email,
                   m.full_name AS master_name, s.name AS service_name, s.price
            FROM appointments a
            JOIN users u    ON u.id=a.user_id
            JOIN masters m  ON m.id=a.master_id
            JOIN services s ON s.id=a.service_id
            {where}
            ORDER BY a.appt_date DESC, a.appt_time DESC
            LIMIT ? OFFSET ?''',
        params + [per_page, (page - 1) * per_page],
    ).fetchall()

    masters = db.execute('SELECT * FROM masters WHERE is_active=1').fetchall()

    pending_reviews = db.execute(
        '''SELECT r.id, r.rating, r.body, r.created_at,
                  u.full_name, m.full_name AS master_name, s.name AS service_name
           FROM reviews r
           JOIN users u ON u.id=r.user_id
           LEFT JOIN masters m  ON m.id=r.master_id
           LEFT JOIN services s ON s.id=r.service_id
           WHERE r.is_approved=0
           ORDER BY r.created_at ASC LIMIT 20'''
    ).fetchall()

    return render_template('admin.html',
                           rows=rows,
                           masters=masters,
                           pending_reviews=pending_reviews,
                           page=page,
                           total_pages=total_pages,
                           total=total,
                           status_filter=status_filter,
                           master_filter=master_filter)


@app.route('/admin/set-status/<int:appt_id>', methods=['POST'])
@admin_required
def set_status(user, appt_id):
    new_status = request.form.get('status')
    if new_status not in ('pending', 'confirmed', 'completed', 'cancelled'):
        return redirect(url_for('admin'))
    db = get_db()
    db.execute('UPDATE appointments SET status=? WHERE id=?', (new_status, appt_id))
    db.commit()
    return redirect(request.form.get('from') or url_for('admin'))


@app.route('/admin/review/<int:rev_id>/approve', methods=['POST'])
@admin_required
def approve_review(user, rev_id):
    db = get_db()
    db.execute('UPDATE reviews SET is_approved=1 WHERE id=?', (rev_id,))
    db.commit()
    return redirect(url_for('admin'))


@app.route('/admin/review/<int:rev_id>/delete', methods=['POST'])
@admin_required
def delete_review(user, rev_id):
    db = get_db()
    db.execute('DELETE FROM reviews WHERE id=?', (rev_id,))
    db.commit()
    return redirect(url_for('admin'))


if __name__ == '__main__':
    with app.app_context():
        ensure_db()
    app.run(debug=True)
