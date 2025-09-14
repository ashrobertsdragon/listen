CREATE TABLE IF NOT EXISTS 
character_count (
        char_count  INTEGER,
        month       INTEGER,
        year        INTEGER
    );

CREATE INDEX IF NOT EXISTS
    month_year_idx
    ON character_count (
        month,
        year
    );

 ALTER TABLE IF     EXISTS
    public.character_count
    ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS
    deny_access
    ON public.character_count;

CREATE POLICY
    deny_access
    ON public.character_count
    to public
        USING (
            false
        );

