CREATE TABLE IF NOT EXISTS chunk (
    id INTEGER PRIMARY KEY,
    world_id INTEGER,
    x INTEGER,
    y INTEGER,
    z INTEGER,
    script_id INTEGER,
    created_at DATETIME,
    updated_at DATETIME
);