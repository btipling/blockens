INSERT INTO
    terrain_gen_script (name, script, created_at, updated_at, color)
VALUES
    (
        :name,
        :script,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        :color
    );