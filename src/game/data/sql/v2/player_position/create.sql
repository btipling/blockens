CREATE TABLE IF NOT EXISTS player_position (
    id INTEGER PRIMARY KEY,
    world_id INTEGER,
    world_pos_x FLOAT,
    world_pos_y FLOAT,
    world_pos_z FLOAT,
    rot_w FLOAT,
    rot_x FLOAT,
    rot_y FLOAT,
    rot_z FLOAT,
    rot_angle FLOAT,
    created_at DATETIME,
    updated_at DATETIME
);