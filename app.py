import os
import sqlite3
from functools import wraps

from flask import Flask, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

BASE_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(BASE_DIR, 'theatre.db')

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret')


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
        '''INSERT INTO users(email,login,password_hash,full_name,phone,is_admin)
           VALUES(?,?,?,?,?,?)''',
        (email, login, generate_password_hash(password), full_name, phone, is_admin),
    )


def init_db():
    run_script('schema.sql')


def seed_db():
    run_script('seed.sql')
    ensure_user('user1@example.com', 'user1', 'password123', 'Иван Петров', '+7-999-111-22-33', 0)
    ensure_user('admin@example.com', 'admin', 'admin12345', 'Администратор Театра', '+7-999-000-00-00', 1)
    get_db().commit()


def ensure_db():
    if not os.path.exists(DB_PATH):
        init_db()
        seed_db()


def log_action(user_id, action):
    db = get_db()
    db.execute(
        'INSERT INTO auth_log(user_id, action, ip, user_agent) VALUES(?,?,?,?)',
        (user_id, action, request.remote_addr, request.headers.get('User-Agent', '')),
    )
    db.commit()


def current_user():
    uid = session.get('user_id')
    if not uid:
        return None
    db = get_db()
    return db.execute('SELECT * FROM users WHERE id=?', (uid,)).fetchone()


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


@app.route('/')
def index():
    ensure_db()
    return render_template('index.html', title='Главная')


@app.route('/register', methods=['GET', 'POST'])
def register():
    ensure_db()
    if request.method != 'POST':
        return render_template('register.html')

    login_name = request.form.get('login', '').strip()
    full_name = request.form.get('full_name', '').strip()
    phone = request.form.get('phone', '').strip()
    email = request.form.get('email', '').strip().lower()
    password = request.form.get('password', '')

    if not (login_name and full_name and phone and email and password):
        return render_template('register.html', error='Заполните все поля')
    if len(password) < 8:
        return render_template('register.html', error='Пароль должен быть не менее 8 символов')

    db = get_db()
    if db.execute('SELECT 1 FROM users WHERE login=? OR email=?', (login_name, email)).fetchone():
        return render_template('register.html', error='Логин или email уже заняты')

    db.execute(
        '''INSERT INTO users(email,login,password_hash,full_name,phone,is_admin)
           VALUES(?,?,?,?,?,0)''',
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

    email = request.form.get('email', '').strip().lower()
    password = request.form.get('password', '')
    db = get_db()
    user = db.execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
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


@app.route('/dashboard')
@login_required
def dashboard(user):
    ensure_db()
    db = get_db()
    performances = db.execute(
        '''SELECT performances.id, productions.title, performances.starts_at, performances.hall
           FROM performances
           JOIN productions ON productions.id=performances.production_id
           ORDER BY performances.starts_at ASC'''
    ).fetchall()
    my_requests = db.execute(
        '''SELECT r.id, p.title, pf.starts_at, r.qty, r.payment_method, r.status
           FROM requests r
           JOIN performances pf ON pf.id=r.performance_id
           JOIN productions p ON p.id=pf.production_id
           WHERE r.user_id=?
           ORDER BY r.created_at DESC''',
        (user['id'],),
    ).fetchall()
    return render_template('dashboard.html', user=user, performances=performances, requests=my_requests)


@app.route('/create-request', methods=['POST'])
@login_required
def create_request(user):
    performance_id = request.form.get('performance_id')
    qty = request.form.get('qty', type=int)
    payment_method = request.form.get('payment_method', '')
    if not (performance_id and qty and payment_method):
        return redirect(url_for('dashboard'))
    db = get_db()
    db.execute(
        '''INSERT INTO requests(user_id, performance_id, qty, payment_method, status)
           VALUES(?,?,?,?, 'new')''',
        (user['id'], performance_id, qty, payment_method),
    )
    db.commit()
    return redirect(url_for('dashboard'))


@app.route('/admin')
@admin_required
def admin(user):
    db = get_db()
    where = ''
    params = []
    status = request.args.get('status')
    if status:
        where = 'WHERE r.status=?'
        params.append(status)
    rows = db.execute(
        '''SELECT r.id, r.qty, r.payment_method, r.status,
                  u.full_name, u.email,
                  p.title, pf.starts_at
           FROM requests r
           JOIN users u ON u.id=r.user_id
           JOIN performances pf ON pf.id=r.performance_id
           JOIN productions p ON p.id=pf.production_id
           ''' + where + '''
           ORDER BY r.created_at DESC''',
        params,
    ).fetchall()
    return render_template('admin.html', rows=rows)


@app.route('/admin/set-status/<int:req_id>', methods=['POST'])
@admin_required
def set_status(user, req_id):
    new_status = request.form.get('status')
    if new_status not in ('new', 'confirmed', 'cancelled'):
        return redirect(url_for('admin'))
    db = get_db()
    db.execute('UPDATE requests SET status=? WHERE id=?', (new_status, req_id))
    db.commit()
    ref = request.form.get('from') or url_for('admin')
    return redirect(ref)


if __name__ == '__main__':
    with app.app_context():
        ensure_db()
    app.run(debug=True)
