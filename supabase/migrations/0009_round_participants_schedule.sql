-- Add rehearsal and performance scheduling fields to round_participants
ALTER TABLE round_participants
  ADD COLUMN IF NOT EXISTS rehearsal_room TEXT,
  ADD COLUMN IF NOT EXISTS rehearsal_time TEXT,
  ADD COLUMN IF NOT EXISTS rehearsal_accompanist TEXT,
  ADD COLUMN IF NOT EXISTS performance_time TEXT;
