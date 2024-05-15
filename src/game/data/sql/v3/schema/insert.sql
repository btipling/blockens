INSERT INTO
    schema (
        version,
        created_at,
        updated_at
    )
VALUES
    (
        :version,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );