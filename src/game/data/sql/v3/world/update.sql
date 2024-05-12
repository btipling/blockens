UPDATE world SET name = :name, updated_at = CURRENT_TIMESTAMP, seed = :seed WHERE id = :id;
