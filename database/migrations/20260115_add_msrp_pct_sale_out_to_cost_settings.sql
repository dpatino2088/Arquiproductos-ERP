-- Migration: Add default_msrp_pct_sale_out to CostSettings
-- This is the global MSRP markup percentage used to compute msrp_sale_out
-- MSRP Sale Out = Total Cost * (1 + default_msrp_pct_sale_out)
-- This is INDEPENDENT of customer discounts (distributor/reseller/partner/vip)

BEGIN;

-- Add default_msrp_pct_sale_out to CostSettings if it doesn't exist
ALTER TABLE public."CostSettings"
ADD COLUMN IF NOT EXISTS default_msrp_pct_sale_out numeric(7,4) DEFAULT 0.35 NOT NULL;

-- Backfill existing rows with 35% default (0.35)
UPDATE public."CostSettings"
SET default_msrp_pct_sale_out = 0.35
WHERE default_msrp_pct_sale_out IS NULL OR default_msrp_pct_sale_out = 0;

COMMIT;

-- Reload schema cache
SELECT pg_notify('pgrst', 'reload schema');
