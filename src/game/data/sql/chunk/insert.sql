INSERT INTO
    chunk (
        world_id,
        x,
        y,
        z,
        script_id,
        voxels,
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
        0,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );