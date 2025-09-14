CREATE TABLE IF NOT EXISTS 
    listen (
        guid            UUID        PRIMARY KEY     DEFAULT gen_random_uuid(),
        title           VARCHAR,
        created_at      TIMESTAMP                   DEFAULT Now(),
        last_download   TIMESTAMP,
        audio_url       VARCHAR
    );

 ALTER TABLE IF      EXISTS
    public.listen
    ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS
    deny_listen_access
    ON public.listen;

CREATE POLICY
    deny_listen_access
    ON public.listen
    to public
        USING (
            false
        );