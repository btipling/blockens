CREATE TABLE IF NOT EXISTS world_terrain (
    id INTEGER PRIMARY KEY,
    world_id INTEGER NOT NULL,
    terrain_gen_script_id INTEGER NOT NULL,
    created_at DATETIME,
    updated_at DATETIME
);