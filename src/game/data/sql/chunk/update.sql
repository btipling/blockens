UPDATE chunk SET script_id = :script_id, voxels = :voxels, updated_at = CURRENT_TIMESTAMP WHERE id = :id;
