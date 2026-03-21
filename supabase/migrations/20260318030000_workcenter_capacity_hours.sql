ALTER TABLE "WorkCenters"
  ADD COLUMN IF NOT EXISTS capacity_hours_per_day numeric NOT NULL DEFAULT 8;
