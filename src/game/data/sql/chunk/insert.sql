INSERT INTO
    chunk (
        world_id,
        x,
        y,
        z,
        script_id,
        created_at,
        updated_at
    )
VALUES
    (
        :world_id,
        :x,
        :y,
        :z,
        :script_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );