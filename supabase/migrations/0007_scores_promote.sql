-- Add promote column to scores table (used as tiebreaker: most promotes wins)
ALTER TABLE scores ADD COLUMN IF NOT EXISTS promote BOOLEAN NOT NULL DEFAULT false;
