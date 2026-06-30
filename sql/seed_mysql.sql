-- ════════════════════════════════════════════════════════════
--  Salon Beauty — sample data (MySQL)
-- ════════════════════════════════════════════════════════════

USE beauty;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE auth_log;
TRUNCATE TABLE notifications;
TRUNCATE TABLE loyalty_points;
TRUNCATE TABLE reviews;
TRUNCATE TABLE appointments;
TRUNCATE TABLE working_hours;
TRUNCATE TABLE master_services;
TRUNCATE TABLE services;
TRUNCATE TABLE masters;
TRUNCATE TABLE categories;
TRUNCATE TABLE users;
TRUNCATE TABLE roles;
TRUNCATE TABLE salon_settings;
SET FOREIGN_KEY_CHECKS = 1;

-- ── Roles ─────────────────────────────────────────────────
INSERT INTO roles (code, name) VALUES
    ('admin',    'Администратор'),
    ('manager',  'Менеджер'),
    ('master',   'Мастер'),
    ('client',   'Клиент');

-- ── Salon settings ────────────────────────────────────────
INSERT INTO salon_settings (skey, svalue) VALUES
    ('salon_name',    '"Студия красоты"'),
    ('working_from',  '"09:00"'),
    ('working_to',    '"20:00"'),
    ('slot_minutes',  '30'),
    ('phone',         '"+7 (999) 000-00-00"'),
    ('address',       '"ул. Цветочная, д. 5"');

-- ── Categories ────────────────────────────────────────────
INSERT INTO categories (name, sort) VALUES
    ('Волосы', 1),
    ('Ногти',  2),
    ('Лицо',   3),
    ('Брови',  4);

-- ── Masters ───────────────────────────────────────────────
INSERT INTO masters (full_name, specialization, bio, experience_yrs) VALUES
    ('Анна Соколова',   'Парикмахер-стилист', 'Специалист по стрижкам и окрашиванию',       8),
    ('Мария Петрова',   'Мастер маникюра',    'Классический и гелевый маникюр, педикюр',     5),
    ('Елена Кузнецова', 'Косметолог',         'Аппаратная и ручная чистка, омолаживающие процедуры', 10),
    ('Ольга Новикова',  'Бровист',            'Коррекция, окрашивание, ламинирование бровей', 4);

-- ── Services ──────────────────────────────────────────────
INSERT INTO services (category_id, name, description, price, duration) VALUES
    (1, 'Женская стрижка',      'Модельная стрижка с укладкой феном',           1200, 60),
    (1, 'Мужская стрижка',      'Классическая или модельная стрижка',            700, 45),
    (1, 'Окрашивание волос',    'Однотонное окрашивание с уходом',              2500, 120),
    (2, 'Маникюр классический', 'Обработка ногтевой пластины + покрытие лаком',  900, 60),
    (2, 'Маникюр гелевый',      'Стойкое гелевое покрытие до 3 недель',         1300, 75),
    (2, 'Педикюр',              'Уход за стопами + покрытие лаком',             1100, 75),
    (3, 'Чистка лица',          'Аппаратная или ручная чистка кожи',            1800, 90),
    (3, 'Увлажняющая маска',    'Интенсивное увлажнение и питание кожи',          900, 45),
    (4, 'Коррекция бровей',     'Придание формы воском или пинцетом',             500, 30),
    (4, 'Ламинирование бровей', 'Ламинирование + окрашивание хной',             1200, 60);

-- ── Master-service mapping ────────────────────────────────
-- master 1 (Анна): услуги волосы
INSERT INTO master_services VALUES (1,1),(1,2),(1,3);
-- master 2 (Мария): ногти
INSERT INTO master_services VALUES (2,4),(2,5),(2,6);
-- master 3 (Елена): лицо
INSERT INTO master_services VALUES (3,7),(3,8);
-- master 4 (Ольга): брови
INSERT INTO master_services VALUES (4,9),(4,10);

-- ── Working hours (Mon-Sat, 9-20) ────────────────────────
INSERT INTO working_hours (master_id, day_of_week, start_time, end_time)
SELECT m.id, d.n, '09:00:00', '20:00:00'
FROM masters m,
     (SELECT 1 n UNION SELECT 2 UNION SELECT 3
      UNION SELECT 4 UNION SELECT 5 UNION SELECT 6) d
WHERE m.is_active = 1;

-- ── Users ─────────────────────────────────────────────────
INSERT INTO users (login, email, password_hash, full_name, phone, role_id) VALUES
    ('admin',    'admin@salon.ru',   '$2b$12$exADMINhash111111111111111111111111111111111111111111', 'Администратор',     '+79000000000', 1),
    ('manager1', 'manager@salon.ru', '$2b$12$exMGRhash1111111111111111111111111111111111111111111', 'Менеджер Салона',   '+79001000000', 2),
    ('anna_s',   'anna@salon.ru',    '$2b$12$exMSTRhash111111111111111111111111111111111111111111', 'Анна Соколова',     '+79001111111', 3),
    ('ivanova_p','ivanova@mail.ru',  '$2b$12$exUSRhash1111111111111111111111111111111111111111111', 'Иванова Полина',    '+79002222222', 4),
    ('smirnov_d','smirnov@mail.ru',  '$2b$12$exUSRhash2222222222222222222222222222222222222222222', 'Смирнов Дмитрий',   '+79003333333', 4);

-- ── Demo appointments ─────────────────────────────────────
INSERT INTO appointments (user_id, master_id, service_id, appt_date, appt_time, status) VALUES
    (4, 1, 1, '2026-07-10', '10:00:00', 'confirmed'),
    (4, 2, 5, '2026-07-12', '12:00:00', 'pending'),
    (5, 3, 7, '2026-07-11', '14:00:00', 'confirmed'),
    (5, 4, 10,'2026-07-15', '11:00:00', 'pending');

-- ── Demo reviews ──────────────────────────────────────────
INSERT INTO reviews (user_id, master_id, service_id, rating, body, is_approved) VALUES
    (4, 1, 1, 5, 'Анна — просто волшебница! Стрижка именно такая, как хотела. Обязательно вернусь!', 1),
    (4, 2, 5, 5, 'Гелевый маникюр держится уже три недели. Мария — профессионал высшего класса.',    1),
    (5, 3, 7, 4, 'Чистка лица прошла комфортно, кожа сияет. Елена всё объяснила и дала рекомендации.', 1),
    (5, 4, 10,5, 'Ламинирование бровей — лучшее, что я делала! Теперь не нужна косметика.',          1);

-- ── Auth log ──────────────────────────────────────────────
INSERT INTO auth_log (user_id, action, ip) VALUES
    (1, 'login',    '127.0.0.1'),
    (4, 'register', '192.168.1.55'),
    (4, 'login',    '192.168.1.55'),
    (5, 'register', '192.168.1.72');

-- ── Loyalty points ────────────────────────────────────────
INSERT INTO loyalty_points (user_id, points, reason) VALUES
    (4, 120, 'Бонус за первый визит'),
    (4,  90, 'Маникюр 2026-07-12'),
    (5, 180, 'Чистка лица 2026-07-11');

-- ── Notifications ─────────────────────────────────────────
INSERT INTO notifications (user_id, type, message) VALUES
    (4, 'appointment_confirmed', 'Ваша запись на 10 июля в 10:00 подтверждена.'),
    (5, 'appointment_confirmed', 'Ваша запись на 11 июля в 14:00 подтверждена.');
