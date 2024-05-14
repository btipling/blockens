SELECT
    world_terrain.terrain_gen_script_id as id,
    terrain_gen_script.name,
    terrain_gen_script.color
FROM
    world_terrain
    INNER JOIN terrain_gen_script on world_terrain.terrain_gen_script_id = terrain_gen_script.id
WHERE
    world_id = :world_id;