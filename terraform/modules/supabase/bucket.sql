UPSERT INTO storage.buckets (
  id, name, public, allowed_mime_types
) VALUES (
  'listen_tab_podcast',
  'listen_tab_podcast',
  true,
  ARRAY['audio/mp3']
);