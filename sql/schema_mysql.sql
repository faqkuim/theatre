-- ════════════════════════════════════════════════════════════
--  Salon — MySQL schema
-- ════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS salon
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE salon;

-- ── 1. roles ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS roles (
  id   INT          AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50)  NOT NULL,
  name VARCHAR(100) NOT NULL,
  UNIQUE uq_roles_code (code)
) ENGINE=InnoDB;

-- ── 2. users ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            BIGINT       AUTO_INCREMENT PRIMARY KEY,
  login         VARCHAR(64)  NOT NULL,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  full_name     VARCHAR(200) NOT NULL,
  phone         VARCHAR(20)  NOT NULL,
  role_id       INT          NOT NULL DEFAULT 4,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE uq_users_login (login),
  UNIQUE uq_users_email (email),
  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id) ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ── 3. categories ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id   INT         AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL,
  sort TINYINT     NOT NULL DEFAULT 0
) ENGINE=InnoDB;

-- ── 4. masters ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS masters (
  id             INT          AUTO_INCREMENT PRIMARY KEY,
  user_id        BIGINT,
  full_name      VARCHAR(200) NOT NULL,
  specialization VARCHAR(200) NOT NULL,
  bio            TEXT,
  photo_url      VARCHAR(255),
  experience_yrs TINYINT,
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_masters_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ── 5. services ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS services (
  id          INT           AUTO_INCREMENT PRIMARY KEY,
  category_id INT           NOT NULL,
  name        VARCHAR(200)  NOT NULL,
  description TEXT,
  price       DECIMAL(10,2) NOT NULL,
  duration    SMALLINT      NOT NULL COMMENT 'minutes',
  is_active   TINYINT(1)    NOT NULL DEFAULT 1,
  CONSTRAINT fk_services_cat FOREIGN KEY (category_id)
    REFERENCES categories(id) ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ── 6. master_services ───────────────────────────────────
CREATE TABLE IF NOT EXISTS master_services (
  master_id  INT NOT NULL,
  service_id INT NOT NULL,
  PRIMARY KEY (master_id, service_id),
  CONSTRAINT fk_ms_master  FOREIGN KEY (master_id)  REFERENCES masters(id)  ON DELETE CASCADE,
  CONSTRAINT fk_ms_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── 7. working_hours ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS working_hours (
  id          INT     AUTO_INCREMENT PRIMARY KEY,
  master_id   INT     NOT NULL,
  day_of_week TINYINT NOT NULL COMMENT '1=Mon … 7=Sun',
  start_time  TIME    NOT NULL,
  end_time    TIME    NOT NULL,
  CONSTRAINT fk_wh_master FOREIGN KEY (master_id)
    REFERENCES masters(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── 8. appointments ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS appointments (
  id         BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT NOT NULL,
  master_id  INT    NOT NULL,
  service_id INT    NOT NULL,
  appt_date  DATE   NOT NULL,
  appt_time  TIME   NOT NULL,
  status     ENUM('pending','confirmed','completed','cancelled') NOT NULL DEFAULT 'pending',
  comment    TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_appt_date (appt_date),
  INDEX idx_appt_status (status),
  CONSTRAINT fk_appt_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE RESTRICT,
  CONSTRAINT fk_appt_master  FOREIGN KEY (master_id)  REFERENCES masters(id)  ON DELETE RESTRICT,
  CONSTRAINT fk_appt_service FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ── 9. reviews ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reviews (
  id          BIGINT     AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT     NOT NULL,
  master_id   INT,
  service_id  INT,
  rating      TINYINT    NOT NULL,
  body        TEXT       NOT NULL,
  is_approved TINYINT(1) NOT NULL DEFAULT 0,
  created_at  DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT fk_rev_user    FOREIGN KEY (user_id)    REFERENCES users(id)     ON DELETE CASCADE,
  CONSTRAINT fk_rev_master  FOREIGN KEY (master_id)  REFERENCES masters(id)   ON DELETE SET NULL,
  CONSTRAINT fk_rev_service FOREIGN KEY (service_id) REFERENCES services(id)  ON DELETE SET NULL
) ENGINE=InnoDB;

-- ── 10. loyalty_points ───────────────────────────────────
CREATE TABLE IF NOT EXISTS loyalty_points (
  id         BIGINT   AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT   NOT NULL,
  points     INT      NOT NULL,
  reason     VARCHAR(255),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_lp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── 11. notifications ────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         BIGINT      AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT      NOT NULL,
  type       VARCHAR(64) NOT NULL,
  message    TEXT        NOT NULL,
  is_read    TINYINT(1)  NOT NULL DEFAULT 0,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── 12. auth_log ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS auth_log (
  id         BIGINT      AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT,
  action     VARCHAR(64) NOT NULL,
  ip         VARCHAR(64),
  user_agent VARCHAR(255),
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ── 13. salon_settings ───────────────────────────────────
CREATE TABLE IF NOT EXISTS salon_settings (
  id     INT          AUTO_INCREMENT PRIMARY KEY,
  skey   VARCHAR(100) NOT NULL,
  svalue TEXT,
  UNIQUE uq_settings_key (skey)
) ENGINE=InnoDB;
