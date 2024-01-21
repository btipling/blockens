CREATE TABLE IF NOT EXISTS chunk_script (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    script TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    color INTEGER DEFAULT 0
);