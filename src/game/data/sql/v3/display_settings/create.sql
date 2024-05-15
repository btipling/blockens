CREATE TABLE IF NOT EXISTS display_settings (
    id INTEGER PRIMARY KEY,
    fullscreen INTEGER,
    maximized INTEGER,
    decorated INTEGER,
    width INTEGER,
    height INTEGER,
    created_at DATETIME,
    updated_at DATETIME
);