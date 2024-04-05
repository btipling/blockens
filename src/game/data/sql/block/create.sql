CREATE TABLE IF NOT EXISTS block (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    texture BLOB NOT NULL,
    light_level INTEGER,
    transparent INTEGER,
    created_at DATETIME,
    updated_at DATETIME
);