UPSERT INTO storage.buckets (
  id, name, public, allowed_mime_types
) VALUES (
  'listen_tab_podcast',
  'listen_tab_podcast',
  true,
  ARRAY['audio/mp3']
);

CREATE TABLE IF NOT EXISTS listen (
    guid uuid PRIMARY KEY,
    title text,
    created_at timestamptz DEFAULT now(),
    last_download timestamptz,
    audio_url text
);

CREATE TABLE IF NOT EXISTS character_count (
    count int,
    month int,
    year int
);

CREATE INDEX IF NOT EXISTS month_year_idx ON character_count (month, year);
