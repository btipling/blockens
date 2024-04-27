UPDATE
    block
SET
    fullscreen = :fullscreen,
    maximized = :maximized,
    decorated = :decorated,
    width = :width,
    height = :height,
    updated_at = CURRENT_TIMESTAMP
WHERE
    id = :id;