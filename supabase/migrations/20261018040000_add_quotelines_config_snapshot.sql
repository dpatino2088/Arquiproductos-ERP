ALTER TABLE public."QuoteLines" ADD COLUMN IF NOT EXISTS config_snapshot jsonb DEFAULT NULL;
