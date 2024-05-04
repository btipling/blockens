INSERT INTO
    player_position (
        world_id,
        world_pos_x,
        world_pos_y,
        world_pos_z,
        rot_w,
        rot_x,
        rot_y,
        rot_z,
        rot_angle,
        created_at,
        updated_at
    )
VALUES
    (
        :world_id,
        :world_pos_x,
        :world_pos_y,
        :world_pos_z,
        :rot_w,
        :rot_x,
        :rot_y,
        :rot_z,
        :rot_angle,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );