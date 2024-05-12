INSERT INTO
    world_terrain (
        world_id,
        terrain_gen_script_id,
        created_at,
        updated_at
    )
VALUES
    (
        :world_id,
        :terrain_gen_script_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );