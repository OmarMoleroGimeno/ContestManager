-- Required for Supabase Realtime to deliver UPDATE events through row-level filters.
-- Without REPLICA IDENTITY FULL, only INSERT events are reliably forwarded.
ALTER TABLE scores REPLICA IDENTITY FULL;

-- Ensure scores is in the realtime publication (safe to run even if already added)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'scores'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE scores;
  END IF;
END $$;
