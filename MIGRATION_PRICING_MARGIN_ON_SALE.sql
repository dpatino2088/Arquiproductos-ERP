-- Migration: Pricing System - Margin-on-Sale with Customer Tier Discounts
-- Description: Adds fields for margin-on-sale pricing model with customer tier discounts
-- Date: 2024-12-24
-- 
-- Changes:
-- 1. Add min_margin_pct to CostSettings (guardrail for pricing)
-- 2. Add pricing snapshot fields to QuoteLines (total_unit_cost, discount_pct, customer_type, price_basis)
-- 3. Add msrp_manual flag to CatalogItems (to track manual MSRP edits)

-- ============================================
-- 1. CostSettings: Add min_margin_pct field
-- ============================================
ALTER TABLE "CostSettings" 
ADD COLUMN IF NOT EXISTS "min_margin_pct" numeric DEFAULT 35.0;

COMMENT ON COLUMN "CostSettings"."min_margin_pct" IS 'Minimum margin percentage (margin-on-sale) used as pricing floor. Default 35%.';

-- Update existing rows to have default value
UPDATE "CostSettings"
SET "min_margin_pct" = 35.0
WHERE "min_margin_pct" IS NULL;

-- ============================================
-- 2. CatalogItems: Add msrp_manual flag
-- ============================================
ALTER TABLE "CatalogItems"
ADD COLUMN IF NOT EXISTS "msrp_manual" boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN "CatalogItems"."msrp_manual" IS 'If true, MSRP was manually edited and should not be auto-recalculated.';

-- ============================================
-- 3. QuoteLines: Add pricing snapshot fields
-- ============================================

-- 3.1 total_unit_cost_snapshot (costo total completo usado)
ALTER TABLE "QuoteLines"
ADD COLUMN IF NOT EXISTS "total_unit_cost_snapshot" numeric;

COMMENT ON COLUMN "QuoteLines"."total_unit_cost_snapshot" IS 'Snapshot of total unit cost (cost_exw + labor + logistics) at quote line creation time.';

-- 3.2 discount_pct_used (descuento aplicado por customer type)
ALTER TABLE "QuoteLines"
ADD COLUMN IF NOT EXISTS "discount_pct_used" numeric DEFAULT 0;

COMMENT ON COLUMN "QuoteLines"."discount_pct_used" IS 'Discount percentage applied based on customer type at quote line creation.';

-- 3.3 customer_type_snapshot (customer type usado)
ALTER TABLE "QuoteLines"
ADD COLUMN IF NOT EXISTS "customer_type_snapshot" text;

COMMENT ON COLUMN "QuoteLines"."customer_type_snapshot" IS 'Customer type (VIP, Partner, Reseller, Distributor) at quote line creation time.';

-- 3.4 price_basis (origen del precio)
ALTER TABLE "QuoteLines"
ADD COLUMN IF NOT EXISTS "price_basis" text DEFAULT 'MSRP_TIER';

COMMENT ON COLUMN "QuoteLines"."price_basis" IS 'Source of unit price: MSRP_TIER (from customer tier discount) or MARGIN_GUARDRAIL (from minimum margin floor).';

-- 3.5 margin_pct_used (margen real logrado - opcional pero útil)
ALTER TABLE "QuoteLines"
ADD COLUMN IF NOT EXISTS "margin_pct_used" numeric;

COMMENT ON COLUMN "QuoteLines"."margin_pct_used" IS 'Actual margin percentage achieved (margin-on-sale) based on unit_price_snapshot and total_unit_cost_snapshot.';

-- ============================================
-- 4. Indexes for better query performance
-- ============================================
CREATE INDEX IF NOT EXISTS "idx_quotelines_customer_type_snapshot" 
ON "QuoteLines"("customer_type_snapshot");

CREATE INDEX IF NOT EXISTS "idx_quotelines_price_basis" 
ON "QuoteLines"("price_basis");

-- ============================================
-- 5. Backfill existing QuoteLines (optional)
-- ============================================
-- Note: This is optional and can be run separately if needed
-- For existing QuoteLines, we can backfill some fields if data is available

-- Backfill total_unit_cost_snapshot from unit_cost_snapshot (if available)
-- This is a best-effort backfill - new quotes will have complete data
UPDATE "QuoteLines" ql
SET "total_unit_cost_snapshot" = COALESCE(ql."unit_cost_snapshot", 0)
WHERE "total_unit_cost_snapshot" IS NULL 
  AND ql."unit_cost_snapshot" IS NOT NULL;

-- Set default price_basis for existing records
UPDATE "QuoteLines"
SET "price_basis" = 'MSRP_TIER'
WHERE "price_basis" IS NULL;

-- ============================================
-- Migration complete
-- ============================================




