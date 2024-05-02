UPDATE
    player_position
SET
    world_pos_x = :world_pos_x,
    world_pos_y = :world_pos_y,
    world_pos_z = :world_pos_z,
    rot_w = :rot_w,
    rot_x = :rot_x,
    rot_y = :rot_y,
    rot_z = :rot_z,
    rot_angle = :rot_angle,
    updated_at = CURRENT_TIMESTAMP
WHERE
    world_id = :world_id;