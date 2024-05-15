UPDATE terrain_gen_script SET name = :name, script = :script, updated_at = CURRENT_TIMESTAMP, color = :color WHERE id = :id;
