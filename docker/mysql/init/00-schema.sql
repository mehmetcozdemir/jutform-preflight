CREATE TABLE IF NOT EXISTS preflight_check (
    id INT AUTO_INCREMENT PRIMARY KEY,
    check_name VARCHAR(64) NOT NULL,
    checked_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO preflight_check (check_name, checked_at) VALUES ('init', NOW());
