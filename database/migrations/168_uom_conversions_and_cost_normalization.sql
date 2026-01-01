-- ====================================================
-- Migration: UOM Conversions and Cost Normalization
-- ====================================================
-- Implements multi-UOM costing support with normalization to canonical UOMs
-- Valid UOMs: mts, yd, ft (linear), m2, yd2 (area), und, pcs, ea, set, pack (pieces)
-- Canonical UOMs: 'm' (linear), 'ea' (pieces), 'm2' (area)
-- ====================================================

-- Ensure set_updated_at() function exists (used by trigger)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 1: Add cost_uom column to CatalogItems if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'cost_uom'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN cost_uom text;
        
        -- Set default cost_uom based on existing uom column (if exists)
        -- If uom exists, use it; otherwise default to 'ea'
        UPDATE "CatalogItems"
        SET cost_uom = COALESCE(uom, 'ea')
        WHERE cost_uom IS NULL;
        
        RAISE NOTICE '✅ Added cost_uom column to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  cost_uom column already exists in CatalogItems';
    END IF;
END $$;

-- Step 2: Create UomConversions table
CREATE TABLE IF NOT EXISTS "UomConversions" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    from_uom text NOT NULL,
    to_uom text NOT NULL,
    multiplier numeric NOT NULL,
    
    -- Audit fields
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    
    -- Constraints
    CONSTRAINT check_uom_conversions_multiplier_positive CHECK (multiplier > 0)
    -- Note: We allow identity conversions (from_uom = to_uom) for convenience
    -- Example: m -> m with multiplier 1.0 is valid
);

-- Remove the constraint that prevents identity conversions if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_uom_conversions_uoms_different'
        AND conrelid = 'public."UomConversions"'::regclass
    ) THEN
        ALTER TABLE "UomConversions" 
        DROP CONSTRAINT check_uom_conversions_uoms_different;
        RAISE NOTICE '✅ Removed constraint check_uom_conversions_uoms_different (allows identity conversions)';
    END IF;
END $$;

-- Unique index: one conversion per org per from_uom/to_uom pair (excluding deleted)
CREATE UNIQUE INDEX IF NOT EXISTS uq_uom_conversions_org_from_to 
ON "UomConversions"(organization_id, from_uom, to_uom) 
WHERE deleted = false;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_uom_conversions_org_from 
ON "UomConversions"(organization_id, from_uom) 
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_uom_conversions_org_to 
ON "UomConversions"(organization_id, to_uom) 
WHERE deleted = false;

-- Trigger for updated_at (use set_updated_at function that should exist)
DROP TRIGGER IF EXISTS trg_uom_conversions_updated_at ON "UomConversions";
CREATE TRIGGER trg_uom_conversions_updated_at
    BEFORE UPDATE ON "UomConversions"
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Step 3: Seed standard UOM conversions (global conversions, organization_id can be NULL or use a system org)
-- We'll use NULL organization_id for standard conversions that apply to all organizations
DO $$
DECLARE
    v_org_id uuid;
BEGIN
    -- Get first organization for seeding (or use NULL for global)
    SELECT id INTO v_org_id FROM "Organizations" WHERE deleted = false LIMIT 1;
    
    -- Standard conversions (seed for first org, can be duplicated for others if needed)
    
    -- Linear conversions to canonical 'm' (meters):
    -- mts -> m: identity (1:1) - meters to meters
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'mts', 'm', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- yd -> m: 1 yard = 0.9144 meters
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'yd', 'm', 0.9144, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- ft -> m: 1 foot = 0.3048 meters
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'ft', 'm', 0.3048, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- Area conversions to canonical 'm2' (square meters):
    -- m2 -> m2: identity (1:1)
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'm2', 'm2', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- yd2 -> m2: 1 square yard = 0.83612736 square meters
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'yd2', 'm2', 0.83612736, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- Piece conversions to canonical 'ea' (each):
    -- ea -> ea: identity (1:1)
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'ea', 'ea', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- pcs -> ea: pieces = each (1:1)
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'pcs', 'ea', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- und -> ea: unit = each (1:1)
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'und', 'ea', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- set -> ea: set = each (1:1) - Note: This treats 'set' as 1 unit
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'set', 'ea', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    -- pack -> ea: pack = each (1:1) - Note: This treats 'pack' as 1 unit
    INSERT INTO "UomConversions" (organization_id, from_uom, to_uom, multiplier, deleted)
    VALUES (v_org_id, 'pack', 'ea', 1.0, false)
    ON CONFLICT (organization_id, from_uom, to_uom) WHERE deleted = false
    DO UPDATE SET multiplier = EXCLUDED.multiplier, updated_at = now();
    
    RAISE NOTICE '✅ Seeded standard UOM conversions';
END $$;

-- Step 4: Create function to get unit cost in target UOM
CREATE OR REPLACE FUNCTION public.get_unit_cost_in_uom(
    p_catalog_item_id uuid,
    p_target_uom text,
    p_organization_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_cost_exw numeric;
    v_cost_uom text;
    v_multiplier numeric;
    v_converted_cost numeric;
BEGIN
    -- Get cost_exw and cost_uom from CatalogItems
    SELECT ci.cost_exw, COALESCE(ci.cost_uom, 'ea') INTO v_cost_exw, v_cost_uom
    FROM "CatalogItems" ci
    WHERE ci.id = p_catalog_item_id
    AND ci.organization_id = p_organization_id
    AND ci.deleted = false;
    
    -- If item not found or cost_exw is NULL, return 0
    IF NOT FOUND OR v_cost_exw IS NULL THEN
        RETURN 0;
    END IF;
    
    -- If cost_uom is already the target_uom, return cost_exw directly
    IF v_cost_uom = p_target_uom THEN
        RETURN v_cost_exw;
    END IF;
    
    -- Find conversion multiplier from cost_uom to target_uom
    SELECT multiplier INTO v_multiplier
    FROM "UomConversions"
    WHERE organization_id = p_organization_id
    AND from_uom = v_cost_uom
    AND to_uom = p_target_uom
    AND deleted = false
    LIMIT 1;
    
    -- If no conversion found, try to find reverse conversion and invert
    IF v_multiplier IS NULL THEN
        SELECT (1.0 / multiplier) INTO v_multiplier
        FROM "UomConversions"
        WHERE organization_id = p_organization_id
        AND from_uom = p_target_uom
        AND to_uom = v_cost_uom
        AND deleted = false
        LIMIT 1;
    END IF;
    
    -- If still no conversion found, return original cost (can't convert)
    IF v_multiplier IS NULL THEN
        RAISE WARNING 'No UOM conversion found from % to % for catalog_item_id: %', v_cost_uom, p_target_uom, p_catalog_item_id;
        RETURN v_cost_exw; -- Return original cost as fallback
    END IF;
    
    -- Convert: if cost is per cost_uom, divide by multiplier to get per target_uom
    -- Example: cost_exw = $10/yd, target_uom = 'm', multiplier = 0.9144 (yd->m)
    -- Result: $10 / 0.9144 = $10.94/m
    v_converted_cost := v_cost_exw / v_multiplier;
    
    RETURN v_converted_cost;
END;
$$;

-- Add comment
COMMENT ON FUNCTION public.get_unit_cost_in_uom IS 
    'Converts unit cost from catalog_item cost_uom to target_uom using UomConversions table. Returns cost per 1 target_uom.';

-- Step 5: Create view for BOM lines with normalized costs
CREATE OR REPLACE VIEW public."BomLinesWithCosts" AS
SELECT 
    qlc.id as bom_line_id,
    qlc.organization_id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    qlc.qty as bom_qty,
    qlc.component_role,
    qlc.source,
    
    -- Catalog item info
    ci.sku,
    ci.item_name,
    ci.cost_exw as cost_exw_original,
    ci.cost_uom as cost_uom_original,
    ci.uom as item_uom,
    
    -- Determine canonical BOM UOM based on component_role and uom
    CASE 
        WHEN qlc.component_role LIKE '%tube%' OR 
             qlc.component_role LIKE '%rail%' OR 
             qlc.component_role LIKE '%profile%' OR 
             qlc.component_role LIKE '%cassette%' OR
             qlc.component_role LIKE '%channel%' OR
             ci.uom IN ('m', 'linear_m', 'meter', 'yd', 'yard') THEN 'm'
        WHEN qlc.component_role LIKE '%fabric%' OR
             ci.uom IN ('sqm', 'm2', 'area', 'yd2') THEN 'm2'
        ELSE 'ea'
    END as bom_uom_canonical,
    
    -- Get unit cost in canonical UOM
    public.get_unit_cost_in_uom(
        qlc.catalog_item_id,
        CASE 
            WHEN qlc.component_role LIKE '%tube%' OR 
                 qlc.component_role LIKE '%rail%' OR 
                 qlc.component_role LIKE '%profile%' OR 
                 qlc.component_role LIKE '%cassette%' OR
                 qlc.component_role LIKE '%channel%' OR
                 ci.uom IN ('m', 'linear_m', 'meter', 'yd', 'yard') THEN 'm'
            WHEN qlc.component_role LIKE '%fabric%' OR
                 ci.uom IN ('sqm', 'm2', 'area', 'yd2') THEN 'm2'
            ELSE 'ea'
        END,
        qlc.organization_id
    ) as unit_cost_exw_canonical,
    
    -- Calculate total cost: bom_qty * unit_cost_in_canonical_uom
    qlc.qty * public.get_unit_cost_in_uom(
        qlc.catalog_item_id,
        CASE 
            WHEN qlc.component_role LIKE '%tube%' OR 
                 qlc.component_role LIKE '%rail%' OR 
                 qlc.component_role LIKE '%profile%' OR 
                 qlc.component_role LIKE '%cassette%' OR
                 qlc.component_role LIKE '%channel%' OR
                 ci.uom IN ('m', 'linear_m', 'meter', 'yd', 'yard') THEN 'm'
            WHEN qlc.component_role LIKE '%fabric%' OR
                 ci.uom IN ('sqm', 'm2', 'area', 'yd2') THEN 'm2'
            ELSE 'ea'
        END,
        qlc.organization_id
    ) as total_cost_exw_line,
    
    qlc.created_at,
    qlc.updated_at
FROM "QuoteLineComponents" qlc
INNER JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
WHERE qlc.deleted = false
AND ci.deleted = false
AND qlc.source = 'configured_component';

-- Add comment
COMMENT ON VIEW public."BomLinesWithCosts" IS 
    'View that outputs BOM lines with unit_cost and total_cost normalized to canonical UOMs (m, ea, m2). All linear quantities are normalized to meters, pieces to ea, and area to m2.';

-- Step 6: Enable RLS on UomConversions
ALTER TABLE "UomConversions" ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can read UOM conversions for their organization
DROP POLICY IF EXISTS "uom_conversions_org_read" ON "UomConversions";
CREATE POLICY "uom_conversions_org_read"
ON "UomConversions" FOR SELECT
USING (
    organization_id IN (
        SELECT organization_id FROM "OrganizationUsers"
        WHERE user_id = auth.uid() AND deleted = false
    )
);

-- RLS Policy: Only admins can modify UOM conversions
DROP POLICY IF EXISTS "uom_conversions_org_write" ON "UomConversions";
CREATE POLICY "uom_conversions_org_write"
ON "UomConversions" FOR ALL
USING (
    organization_id IN (
        SELECT organization_id FROM "OrganizationUsers"
        WHERE user_id = auth.uid() 
        AND role IN ('admin', 'owner')
        AND deleted = false
    )
);

-- Final notice
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ UOM Conversions and Cost Normalization Migration Complete!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '   - Added cost_uom column to CatalogItems';
    RAISE NOTICE '   - Created UomConversions table with standard conversions';
    RAISE NOTICE '   - Created get_unit_cost_in_uom() function';
    RAISE NOTICE '   - Created BomLinesWithCosts view with normalized costs';
    RAISE NOTICE '   - Valid UOMs: mts, yd, ft (linear), m2, yd2 (area), und, pcs, ea, set, pack (pieces)';
    RAISE NOTICE '   - Canonical UOMs: m (linear), ea (pieces), m2 (area)';
    RAISE NOTICE '';
END $$;

