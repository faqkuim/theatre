-- ════════════════════════════════════════════════════════════
--  Theatre database — MySQL schema
--  Based on ER diagram (diagram.plantuml)
-- ════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS theatre
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE theatre;

-- ────────────────────────────────────────────────────────────
--  REFERENCE / LOOKUP TABLES  (no foreign keys)
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS roles (
    id    INT          NOT NULL AUTO_INCREMENT,
    code  VARCHAR(50)  NOT NULL,
    name  VARCHAR(100) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS permissions (
    id    INT          NOT NULL AUTO_INCREMENT,
    code  VARCHAR(64)  NOT NULL,
    name  VARCHAR(128) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_permissions_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS payment_method (
    id    INT         NOT NULL AUTO_INCREMENT,
    code  VARCHAR(32) NOT NULL,
    name  VARCHAR(64) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_payment_method_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS hall (
    id    INT          NOT NULL AUTO_INCREMENT,
    name  VARCHAR(120) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS production (
    id            INT          NOT NULL AUTO_INCREMENT,
    title         VARCHAR(200) NOT NULL,
    genre         VARCHAR(80)  NOT NULL,
    description   TEXT,
    duration_min  INT          NOT NULL DEFAULT 0,
    age_rating    VARCHAR(16)  NOT NULL DEFAULT '0+',
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
--  SETTINGS / SYSTEM TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_setting (
    id      INT          NOT NULL AUTO_INCREMENT,
    skey    VARCHAR(100) NOT NULL,
    svalue  TEXT,
    PRIMARY KEY (id),
    UNIQUE KEY uq_admin_setting_key (skey)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS integration (
    id        INT         NOT NULL AUTO_INCREMENT,
    provider  VARCHAR(64) NOT NULL,
    config    TEXT        COMMENT 'JSON with keys/URL',
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS email_queue (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    to_email   VARCHAR(255) NOT NULL,
    subject    VARCHAR(255) NOT NULL,
    body       TEXT         NOT NULL,
    sent_at    DATETIME     DEFAULT NULL,
    is_sent    TINYINT(1)   NOT NULL DEFAULT 0,
    error_msg  VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_email_queue_is_sent (is_sent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS backup_log (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    started_at   DATETIME     NOT NULL,
    finished_at  DATETIME     DEFAULT NULL,
    status       VARCHAR(32)  NOT NULL DEFAULT 'running',
    location     VARCHAR(255) DEFAULT NULL,
    message      VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_backup_log_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
--  USER / RBAC TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    login          VARCHAR(64)  NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    full_name      VARCHAR(200) NOT NULL,
    phone          VARCHAR(20)  DEFAULT NULL,
    email          VARCHAR(255) NOT NULL,
    role_id        INT          NOT NULL,
    is_active      TINYINT(1)   NOT NULL DEFAULT 1,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_login (login),
    KEY idx_users_email   (email),
    KEY idx_users_role_id (role_id),
    CONSTRAINT fk_users_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id        INT NOT NULL,
    permission_id  INT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id)
        REFERENCES permissions (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS auth_log (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    user_id          BIGINT       DEFAULT NULL,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attempted_login  VARCHAR(64)  DEFAULT NULL,
    ip               VARCHAR(64)  DEFAULT NULL,
    user_agent       VARCHAR(255) DEFAULT NULL,
    is_success       TINYINT(1)   NOT NULL DEFAULT 0,
    reason           VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_auth_log_user_id    (user_id),
    KEY idx_auth_log_created_at (created_at),
    CONSTRAINT fk_auth_log_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
--  VENUE TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS seat_zone (
    id          INT          NOT NULL AUTO_INCREMENT,
    hall_id     INT          NOT NULL,
    name        VARCHAR(80)  NOT NULL,
    price_mult  DECIMAL(6,2) NOT NULL DEFAULT 1.00,
    PRIMARY KEY (id),
    KEY idx_seat_zone_hall_id (hall_id),
    CONSTRAINT fk_seat_zone_hall FOREIGN KEY (hall_id)
        REFERENCES hall (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS seat (
    id           INT NOT NULL AUTO_INCREMENT,
    hall_id      INT NOT NULL,
    zone_id      INT NOT NULL,
    row_number   INT NOT NULL,
    seat_number  INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_seat (hall_id, row_number, seat_number),
    KEY idx_seat_zone_id (zone_id),
    CONSTRAINT fk_seat_hall FOREIGN KEY (hall_id)
        REFERENCES hall (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_seat_zone FOREIGN KEY (zone_id)
        REFERENCES seat_zone (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS performance (
    id             INT           NOT NULL AUTO_INCREMENT,
    production_id  INT           NOT NULL,
    hall_id        INT           NOT NULL,
    starts_at      DATETIME      NOT NULL,
    base_price     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status         VARCHAR(24)   NOT NULL DEFAULT 'scheduled',
    PRIMARY KEY (id),
    KEY idx_performance_production_id (production_id),
    KEY idx_performance_hall_id       (hall_id),
    KEY idx_performance_starts_at     (starts_at),
    CONSTRAINT fk_performance_production FOREIGN KEY (production_id)
        REFERENCES production (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_performance_hall FOREIGN KEY (hall_id)
        REFERENCES hall (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────
--  BOOKING / FINANCE TABLES
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS orders (
    id                 BIGINT        NOT NULL AUTO_INCREMENT,
    buyer_user_id      BIGINT        NOT NULL,
    payment_method_id  INT           NOT NULL,
    created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at            DATETIME      DEFAULT NULL,
    email_to           VARCHAR(255)  NOT NULL,
    payment_status     ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
    total_amount       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (id),
    KEY idx_orders_buyer_user_id     (buyer_user_id),
    KEY idx_orders_payment_method_id (payment_method_id),
    KEY idx_orders_payment_status    (payment_status),
    CONSTRAINT fk_orders_user FOREIGN KEY (buyer_user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orders_payment_method FOREIGN KEY (payment_method_id)
        REFERENCES payment_method (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS payments (
    id               BIGINT        NOT NULL AUTO_INCREMENT,
    order_id         BIGINT        NOT NULL,
    method_id        INT           NOT NULL,
    created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status           ENUM('initiated','authorized','captured','failed','refunded') NOT NULL DEFAULT 'initiated',
    transaction_ref  VARCHAR(128)  DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_payments_order_id  (order_id),
    KEY idx_payments_method_id (method_id),
    KEY idx_payments_status    (status),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id)
        REFERENCES orders (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_payments_method FOREIGN KEY (method_id)
        REFERENCES payment_method (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ticket (
    id              BIGINT        NOT NULL AUTO_INCREMENT,
    performance_id  INT           NOT NULL,
    seat_id         INT           NOT NULL,
    order_id        BIGINT        NOT NULL,
    reserved_until  DATETIME      DEFAULT NULL,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status          ENUM('reserved','sold','returned','blocked') NOT NULL DEFAULT 'reserved',
    price           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ticket_perf_seat (performance_id, seat_id),
    KEY idx_ticket_order_id (order_id),
    KEY idx_ticket_status   (status),
    CONSTRAINT fk_ticket_performance FOREIGN KEY (performance_id)
        REFERENCES performance (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_seat FOREIGN KEY (seat_id)
        REFERENCES seat (id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_order FOREIGN KEY (order_id)
        REFERENCES orders (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
