UPDATE
    block
SET
    name = :name,
    texture = :texture,
    light_level = :light_level,
    transparent = :transparent,
    updated_at = CURRENT_TIMESTAMP
WHERE
    id = :id;