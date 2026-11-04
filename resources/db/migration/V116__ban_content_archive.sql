CREATE TABLE IF NOT EXISTS ban_content_archive (
    id               VARCHAR(64)   NOT NULL,
    sanction_id      VARCHAR(64)   NOT NULL,
    user_id          VARCHAR(64)   NOT NULL,
    content_type     VARCHAR(32)   NOT NULL,
    content_id       VARCHAR(64)   NOT NULL,
    -- LONGTEXT (e não VARCHAR(65535)): no MariaDB com utf8mb4 o VARCHAR máximo é ~16k
    -- CARACTERES (65535 bytes na linha inteira) e o CREATE TABLE falhava no boot.
    content_snapshot LONGTEXT NOT NULL,
    archived_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_ban_archive_sanction ON ban_content_archive (sanction_id);
CREATE INDEX IF NOT EXISTS idx_ban_archive_user ON ban_content_archive (user_id);
