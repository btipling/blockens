CREATE TABLE IF NOT EXISTS texture_script (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    script TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);