CREATE TABLE IF NOT EXISTS block (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    texture BLOB NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);