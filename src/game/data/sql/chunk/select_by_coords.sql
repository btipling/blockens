SELECT id, world_id, x, y, z, script_id, voxels FROM chunk WHERE x = :x and y = :y and z = :z and world_id = :world_id;
