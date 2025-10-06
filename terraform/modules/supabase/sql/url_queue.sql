CREATE TABLE IF NOT EXISTS 
url_queue (
  id            UUID      PRIMARY KEY     DEFAULT gen_random_uuid(),
  url           TEXT                                                  NOT NULL,
  created_at    TIMESTAMP WITH TIME ZONE  DEFAULT NOW(),
  processed_at  TIMESTAMP WITH TIME ZONE,
  status        TEXT                      DEFAULT 'pending'                     CHECK (
      status IN (
        'pending',
        'processing',
        'completed',
        'failed'
      )),
  error_message TEXT
);

CREATE INDEX IF NOT EXISTS
idx_url_queue_status
ON url_queue(
  status,
  created_at
);

ALTER TABLE IF     EXISTS
  url_queue
  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS
  deny_access
  ON public.url_queue;

CREATE POLICY
  deny_access
  ON url_queue 
  TO public
  USING (
    true
  );
