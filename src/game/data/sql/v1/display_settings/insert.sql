INSERT INTO
    display_settings (
        fullscreen,
        maximized,
        decorated,
        width,
        height,
        created_at,
        updated_at
    )
VALUES
    (
        :fullscreen,
        :maximized,
        :decorated,
        :width,
        :height,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );