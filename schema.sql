CREATE DATABASE IF NOT EXISTS reminders_mac DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE reminders_mac;

CREATE TABLE IF NOT EXISTS reminders (
    id CHAR(36) NOT NULL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    scheduled_at DATETIME NOT NULL,
    is_completed TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_is_completed (is_completed),
    INDEX idx_scheduled_at (scheduled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
