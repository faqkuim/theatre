-- ════════════════════════════════════════════════════════════
--  Theatre database — sample data
-- ════════════════════════════════════════════════════════════

USE theatre;

-- Очистка перед вставкой (порядок важен из-за FK)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE email_queue;
TRUNCATE TABLE backup_log;
TRUNCATE TABLE auth_log;
TRUNCATE TABLE integration;
TRUNCATE TABLE admin_setting;
TRUNCATE TABLE ticket;
TRUNCATE TABLE payments;
TRUNCATE TABLE orders;
TRUNCATE TABLE seat;
TRUNCATE TABLE performance;
TRUNCATE TABLE seat_zone;
TRUNCATE TABLE role_permissions;
TRUNCATE TABLE users;
TRUNCATE TABLE hall;
TRUNCATE TABLE production;
TRUNCATE TABLE payment_method;
TRUNCATE TABLE permissions;
TRUNCATE TABLE roles;
SET FOREIGN_KEY_CHECKS = 1;

-- ────────────────────────────────────────────────────────────
--  ROLES & PERMISSIONS
-- ────────────────────────────────────────────────────────────

INSERT INTO roles (code, name) VALUES
    ('admin',    'Администратор'),
    ('manager',  'Менеджер'),
    ('cashier',  'Кассир'),
    ('customer', 'Покупатель');

INSERT INTO permissions (code, name) VALUES
    ('users.view',        'Просмотр пользователей'),
    ('users.edit',        'Редактирование пользователей'),
    ('productions.view',  'Просмотр постановок'),
    ('productions.edit',  'Редактирование постановок'),
    ('performances.view', 'Просмотр спектаклей'),
    ('performances.edit', 'Редактирование спектаклей'),
    ('orders.view',       'Просмотр заказов'),
    ('orders.edit',       'Редактирование заказов'),
    ('reports.view',      'Просмотр отчётов'),
    ('settings.edit',     'Редактирование настроек');

-- admin gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.code = 'admin';

-- manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
    ON p.code IN ('productions.view','productions.edit','performances.view','performances.edit','orders.view','reports.view')
WHERE r.code = 'manager';

-- cashier
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
    ON p.code IN ('performances.view','orders.view','orders.edit')
WHERE r.code = 'cashier';

-- ────────────────────────────────────────────────────────────
--  PAYMENT METHODS
-- ────────────────────────────────────────────────────────────

INSERT INTO payment_method (code, name) VALUES
    ('cash',   'Наличные'),
    ('card',   'Банковская карта'),
    ('online', 'Онлайн-оплата'),
    ('sbp',    'СБП');

-- ────────────────────────────────────────────────────────────
--  ADMIN SETTINGS
-- ────────────────────────────────────────────────────────────

INSERT INTO admin_setting (skey, svalue) VALUES
    ('site_name',          '"Городской театр"'),
    ('ticket_reserve_min', '30'),
    ('max_tickets_order',  '10'),
    ('email_sender',       '"noreply@theatre.ru"');

-- ────────────────────────────────────────────────────────────
--  HALLS
-- ────────────────────────────────────────────────────────────

INSERT INTO hall (name) VALUES
    ('Большой зал'),
    ('Малый зал'),
    ('Камерная сцена');

-- seat_zone: (hall_id, name, price_mult)
INSERT INTO seat_zone (hall_id, name, price_mult) VALUES
    (1, 'Партер',       1.50),
    (1, 'Амфитеатр',    1.20),
    (1, 'Балкон',       1.00),
    (2, 'Партер',       1.30),
    (2, 'Балкон',       1.00),
    (3, 'Единый зал',   1.00);

-- seats for Большой зал — партер rows 1-5 seats 1-10
INSERT INTO seat (hall_id, zone_id, row_number, seat_number)
SELECT 1, 1, r, s
FROM
    (SELECT 1 r UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) rows,
    (SELECT 1 s UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
     UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10) seats;

-- seats for Большой зал — амфитеатр rows 6-10 seats 1-12
INSERT INTO seat (hall_id, zone_id, row_number, seat_number)
SELECT 1, 2, r, s
FROM
    (SELECT 6 r UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10) rows,
    (SELECT 1 s UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6
     UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12) seats;

-- seats for Малый зал — партер rows 1-4 seats 1-8
INSERT INTO seat (hall_id, zone_id, row_number, seat_number)
SELECT 2, 4, r, s
FROM
    (SELECT 1 r UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) rows,
    (SELECT 1 s UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
     UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8) seats;

-- ────────────────────────────────────────────────────────────
--  PRODUCTIONS
-- ────────────────────────────────────────────────────────────

INSERT INTO production (title, genre, description, duration_min, age_rating) VALUES
    ('Жизель',               'Балет',   'Романтический балет А. Адана в двух действиях.',  120, '6+'),
    ('Дон Кихот',            'Балет',   'Балет Л. Минкуса по роману Сервантеса.',          130, '6+'),
    ('Спящая красавица',     'Балет',   'Балет П.И. Чайковского в трёх действиях.',        160, '0+'),
    ('Ревизор',              'Комедия', 'Комедия Н.В. Гоголя в пяти действиях.',           140, '12+'),
    ('Три сестры',           'Драма',   'Пьеса А.П. Чехова в четырёх действиях.',          170, '16+'),
    ('Риголетто',            'Опера',   'Опера Джузеппе Верди в трёх действиях.',          155, '12+');

-- ────────────────────────────────────────────────────────────
--  PERFORMANCES
-- ────────────────────────────────────────────────────────────

INSERT INTO performance (production_id, hall_id, starts_at, base_price, status) VALUES
    (1, 1, '2026-07-10 19:00:00', 1400.00, 'scheduled'),
    (2, 1, '2026-07-15 19:00:00', 1500.00, 'scheduled'),
    (3, 1, '2026-07-22 19:00:00', 1600.00, 'scheduled'),
    (4, 2, '2026-07-18 18:30:00',  900.00, 'scheduled'),
    (5, 3, '2026-07-25 19:00:00',  800.00, 'scheduled'),
    (6, 1, '2026-08-05 19:00:00', 2000.00, 'scheduled');

-- ────────────────────────────────────────────────────────────
--  USERS
-- ────────────────────────────────────────────────────────────

INSERT INTO users (login, password_hash, full_name, phone, email, role_id, is_active) VALUES
    ('admin',
     '$2b$12$examplehashADMIN111111111111111111111111111111111111111',
     'Иванов Иван Иванович',     '+79001112233', 'admin@theatre.ru',    1, 1),
    ('manager1',
     '$2b$12$examplehashMGR1111111111111111111111111111111111111111',
     'Петрова Мария Сергеевна',  '+79002223344', 'manager@theatre.ru',  2, 1),
    ('cashier1',
     '$2b$12$examplehashCSH1111111111111111111111111111111111111111',
     'Сидоров Алексей Петрович', '+79003334455', 'cashier@theatre.ru',  3, 1),
    ('ivanov_k',
     '$2b$12$examplehashUSR1111111111111111111111111111111111111111',
     'Козлов Дмитрий Андреевич', '+79004445566', 'kozlov@example.com',  4, 1),
    ('smirnova_a',
     '$2b$12$examplehashUSR2222222222222222222222222222222222222222',
     'Смирнова Анна Викторовна', '+79005556677', 'smirnova@example.com',4, 1);

-- ────────────────────────────────────────────────────────────
--  ORDERS & TICKETS
-- ────────────────────────────────────────────────────────────

-- Order 1: kozlov buys 2 tickets for Лебединое озеро (performance 1, seats 1 and 2 row 1)
INSERT INTO orders (buyer_user_id, payment_method_id, paid_at, email_to, payment_status, total_amount) VALUES
    (4, 2, '2026-06-25 14:30:00', 'kozlov@example.com', 'paid', 3000.00);

INSERT INTO payments (order_id, method_id, status, transaction_ref) VALUES
    (1, 2, 'captured', 'TXN-2026-001');

INSERT INTO ticket (performance_id, seat_id, order_id, reserved_until, status, price) VALUES
    (1, 1, 1, NULL, 'sold', 1500.00),
    (1, 2, 1, NULL, 'sold', 1500.00);

-- Order 2: smirnova reserves 1 ticket for Щелкунчик (performance 3, seat in Малый зал)
INSERT INTO orders (buyer_user_id, payment_method_id, email_to, payment_status, total_amount) VALUES
    (5, 3, 'smirnova@example.com', 'pending', 1200.00);

INSERT INTO payments (order_id, method_id, status) VALUES
    (2, 3, 'initiated');

INSERT INTO ticket (performance_id, seat_id, order_id, reserved_until, status, price) VALUES
    (3, 101, 2, '2026-07-04 20:00:00', 'reserved', 1200.00);

-- ────────────────────────────────────────────────────────────
--  AUTH LOG
-- ────────────────────────────────────────────────────────────

INSERT INTO auth_log (user_id, attempted_login, ip, user_agent, is_success, reason) VALUES
    (1,    'admin',      '192.168.1.1',  'Mozilla/5.0 (Windows NT 10.0)',  1, NULL),
    (NULL, 'hacker',     '10.0.0.99',    'curl/7.68.0',                    0, 'User not found'),
    (4,    'ivanov_k',   '192.168.1.55', 'Mozilla/5.0 (Windows NT 10.0)',  1, NULL),
    (5,    'smirnova_a', '192.168.1.72', 'Mozilla/5.0 (Macintosh)',        1, NULL);

-- ────────────────────────────────────────────────────────────
--  EMAIL QUEUE
-- ────────────────────────────────────────────────────────────

INSERT INTO email_queue (to_email, subject, body, sent_at, is_sent) VALUES
    ('kozlov@example.com',   'Ваши билеты на Лебединое озеро',
     'Здравствуйте! Ваш заказ №1 подтверждён. Билеты прикреплены к письму.',
     '2026-06-25 14:31:00', 1),
    ('smirnova@example.com', 'Бронирование билета на Щелкунчик',
     'Здравствуйте! Ваш билет на Щелкунчик забронирован до 2026-07-04 20:00.',
     NULL, 0);

-- ────────────────────────────────────────────────────────────
--  BACKUP LOG
-- ────────────────────────────────────────────────────────────

INSERT INTO backup_log (started_at, finished_at, status, location, message) VALUES
    ('2026-06-28 03:00:00', '2026-06-28 03:04:22', 'success',
     '/backups/theatre_2026-06-28.sql.gz', NULL),
    ('2026-06-29 03:00:00', '2026-06-29 03:05:01', 'success',
     '/backups/theatre_2026-06-29.sql.gz', NULL),
    ('2026-06-30 03:00:00', NULL, 'running', NULL, NULL);

-- ────────────────────────────────────────────────────────────
--  INTEGRATION
-- ────────────────────────────────────────────────────────────

INSERT INTO integration (provider, config) VALUES
    ('smtp_mail', '{"host":"smtp.theatre.ru","port":587,"user":"noreply@theatre.ru"}'),
    ('sms_gate',  '{"url":"https://sms.example.ru/api","api_key":"SECRET"}');
