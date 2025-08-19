CREATE TABLE IF NOT EXISTS listen (
    guid uuid PRIMARY KEY,
    title text,
    created_at timestamptz DEFAULT now(),
    last_download timestamptz,
    audio_url text
);