CREATE TABLE IF NOT EXISTS world (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    seed INTEGER NOT NULL
);