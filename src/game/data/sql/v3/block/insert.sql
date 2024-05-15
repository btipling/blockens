INSERT INTO
    block (
        name,
        texture,
        light_level,
        transparent,
        created_at,
        updated_at
    )
VALUES
    (
        :name,
        :texture,
        :light_level,
        :transparent,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );