-- Add 'superseded' value to quote_status enum so an older version can be
-- marked as superseded whenever a newer version is created.

ALTER TYPE quote_status ADD VALUE IF NOT EXISTS 'superseded';
