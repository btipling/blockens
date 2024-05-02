SELECT
    id,
    world_id,
    world_pos_x,
    world_pos_y,
    world_pos_z,
    rot_w,
    rot_x,
    rot_y,
    rot_z,
    rot_angle
FROM
    player_position
WHERE
    world_id = :world_id;