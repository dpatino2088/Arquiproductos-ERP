-- ====================================================
-- Migration: Complete Operational Flow Quote to BOM
-- ====================================================
-- This migration implements the complete operational traceability flow:
-- Quote -> SaleOrder -> SaleOrderLine -> BomInstance -> BomInstanceLines
-- 
-- When a Quote.status transitions to 'approved':
-- A) Creates SaleOrder if missing
-- B) Creates SaleOrderLines for each QuoteLine (missing only)
-- C) Creates exactly ONE BomInstance per SaleOrderLine (if missing)
-- D) Populates BomInstanceLines from QuoteLineComponents (frozen snapshot)
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Extend BomInstances table
-- ====================================================
DO $$
BEGIN
    -- Add sale_order_line_id FK (only if SaleOrderLines table exists)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'sale_order_line_id'
    ) THEN
        -- Check if SaleOrderLines table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'SaleOrderLines'
        ) THEN
            -- Add column with FK constraint
            ALTER TABLE "BomInstances"
            ADD COLUMN sale_order_line_id uuid REFERENCES "SaleOrderLines"(id) ON DELETE CASCADE;
            
            RAISE NOTICE '✅ Added sale_order_line_id to BomInstances with FK to SaleOrderLines';
        ELSE
            -- Add column without FK constraint (table doesn't exist yet)
            ALTER TABLE "BomInstances"
            ADD COLUMN sale_order_line_id uuid;
            
            RAISE NOTICE '✅ Added sale_order_line_id to BomInstances (FK will be added when SaleOrderLines table exists)';
        END IF;
    ELSE
        RAISE NOTICE '⏭️  sale_order_line_id already exists in BomInstances';
    END IF;
    
    -- Add quote_line_id FK
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'quote_line_id'
    ) THEN
        ALTER TABLE "BomInstances"
        ADD COLUMN quote_line_id uuid REFERENCES "QuoteLines"(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added quote_line_id to BomInstances';
    ELSE
        RAISE NOTICE '⏭️  quote_line_id already exists in BomInstances';
    END IF;
    
    -- Make configured_product_id nullable (drop NOT NULL if exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'configured_product_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE "BomInstances"
        ALTER COLUMN configured_product_id DROP NOT NULL;
        
        RAISE NOTICE '✅ Made configured_product_id nullable in BomInstances';
    ELSE
        RAISE NOTICE '⏭️  configured_product_id already nullable in BomInstances';
    END IF;
END $$;

COMMENT ON COLUMN "BomInstances".sale_order_line_id IS 
    'Reference to SaleOrderLine. One BomInstance per SaleOrderLine.';

COMMENT ON COLUMN "BomInstances".quote_line_id IS 
    'Reference to QuoteLine for traceability.';

-- Add FK constraint to sale_order_line_id if table exists but constraint is missing
DO $$
BEGIN
    -- Check if SaleOrderLines table exists and column exists but FK constraint is missing
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances' 
        AND column_name = 'sale_order_line_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_schema = 'public'
        AND tc.table_name = 'BomInstances'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'sale_order_line_id'
    ) THEN
        -- Add FK constraint
        ALTER TABLE "BomInstances"
        ADD CONSTRAINT fk_bom_instances_sale_order_line 
        FOREIGN KEY (sale_order_line_id) 
        REFERENCES "SaleOrderLines"(id) 
        ON DELETE CASCADE;
        
        RAISE NOTICE '✅ Added FK constraint to BomInstances.sale_order_line_id';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Extend BomInstanceLines table
-- ====================================================
DO $$
BEGIN
    -- Add description
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'description'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN description text;
        
        RAISE NOTICE '✅ Added description to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  description already exists in BomInstanceLines';
    END IF;
    
    -- Add unit_cost_exw
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'unit_cost_exw'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN unit_cost_exw numeric(12,4);
        
        RAISE NOTICE '✅ Added unit_cost_exw to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  unit_cost_exw already exists in BomInstanceLines';
    END IF;
    
    -- Add total_cost_exw
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'total_cost_exw'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN total_cost_exw numeric(12,4);
        
        RAISE NOTICE '✅ Added total_cost_exw to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  total_cost_exw already exists in BomInstanceLines';
    END IF;
    
    -- Add category_code
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'category_code'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN category_code text;
        
        -- Add constraint for valid category codes
        ALTER TABLE "BomInstanceLines"
        ADD CONSTRAINT check_bom_instance_lines_category_code_valid 
        CHECK (category_code IS NULL OR category_code IN (
            'fabric', 'tube', 'motor', 'bracket', 'cassette', 
            'side_channel', 'bottom_channel', 'accessory'
        ));
        
        RAISE NOTICE '✅ Added category_code to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  category_code already exists in BomInstanceLines';
    END IF;
    
    -- Add deleted column if missing (for consistency with other tables)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "BomInstanceLines"
        ADD COLUMN deleted boolean NOT NULL DEFAULT false;
        
        RAISE NOTICE '✅ Added deleted column to BomInstanceLines';
    ELSE
        RAISE NOTICE '⏭️  deleted column already exists in BomInstanceLines';
    END IF;
END $$;

COMMENT ON COLUMN "BomInstanceLines".description IS 
    'Item description (from CatalogItems.item_name) frozen at approval time.';

COMMENT ON COLUMN "BomInstanceLines".unit_cost_exw IS 
    'Unit cost in canonical UOM, frozen at approval time.';

COMMENT ON COLUMN "BomInstanceLines".total_cost_exw IS 
    'Total cost (qty * unit_cost_exw), frozen at approval time.';

COMMENT ON COLUMN "BomInstanceLines".category_code IS 
    'Category derived from component_role: fabric, tube, motor, bracket, cassette, side_channel, bottom_channel, accessory.';

-- ====================================================
-- STEP 3: Add UNIQUE constraints and indexes
-- ====================================================
DO $$
BEGIN
    -- UNIQUE BomInstances(sale_order_line_id) WHERE deleted=false
    -- Only create if SaleOrderLines table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'BomInstances' 
            AND indexname = 'uq_bom_instances_sale_order_line_id'
        ) THEN
            CREATE UNIQUE INDEX uq_bom_instances_sale_order_line_id 
            ON "BomInstances"(sale_order_line_id) 
            WHERE deleted = false AND sale_order_line_id IS NOT NULL;
            
            RAISE NOTICE '✅ Created unique index on BomInstances(sale_order_line_id)';
        ELSE
            RAISE NOTICE '⏭️  Unique index on BomInstances(sale_order_line_id) already exists';
        END IF;
    ELSE
        RAISE NOTICE '⏭️  SaleOrderLines table does not exist, skipping unique index on sale_order_line_id';
    END IF;
    
    -- UNIQUE ConfiguredProducts(quote_line_id) WHERE deleted=false
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'ConfiguredProducts' 
        AND indexname = 'uq_configured_products_quote_line_id'
    ) THEN
        CREATE UNIQUE INDEX uq_configured_products_quote_line_id 
        ON "ConfiguredProducts"(quote_line_id) 
        WHERE deleted = false AND quote_line_id IS NOT NULL;
        
        RAISE NOTICE '✅ Created unique index on ConfiguredProducts(quote_line_id)';
    ELSE
        RAISE NOTICE '⏭️  Unique index on ConfiguredProducts(quote_line_id) already exists';
    END IF;
    
    -- UNIQUE BomInstanceLines(bom_instance_id, resolved_part_id, part_role, uom) WHERE deleted=false
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'BomInstanceLines' 
        AND indexname = 'uq_bom_instance_lines_dedup'
    ) THEN
        CREATE UNIQUE INDEX uq_bom_instance_lines_dedup 
        ON "BomInstanceLines"(bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
        WHERE deleted = false;
        
        RAISE NOTICE '✅ Created unique index on BomInstanceLines for deduplication';
    ELSE
        RAISE NOTICE '⏭️  Unique index on BomInstanceLines for deduplication already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Add helpful indexes for lookups
-- ====================================================
-- Only create indexes if the tables exist
DO $$
BEGIN
    -- Index on BomInstances.sale_order_line_id (only if SaleOrderLines exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'BomInstances' 
            AND indexname = 'idx_bom_instances_sale_order_line_id'
        ) THEN
            CREATE INDEX idx_bom_instances_sale_order_line_id 
            ON "BomInstances"(sale_order_line_id) 
            WHERE deleted = false;
            
            RAISE NOTICE '✅ Created index idx_bom_instances_sale_order_line_id';
        END IF;
    END IF;
    
    -- Index on BomInstances.quote_line_id
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'BomInstances' 
        AND indexname = 'idx_bom_instances_quote_line_id'
    ) THEN
        CREATE INDEX idx_bom_instances_quote_line_id 
        ON "BomInstances"(quote_line_id) 
        WHERE deleted = false;
        
        RAISE NOTICE '✅ Created index idx_bom_instances_quote_line_id';
    END IF;
    
    -- Index on SaleOrders.quote_id (only if SaleOrders exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'SaleOrders' 
            AND indexname = 'idx_sale_orders_quote_id'
        ) THEN
            CREATE INDEX idx_sale_orders_quote_id 
            ON "SaleOrders"(quote_id) 
            WHERE deleted = false;
            
            RAISE NOTICE '✅ Created index idx_sale_orders_quote_id';
        END IF;
    END IF;
    
    -- Index on SaleOrderLines.quote_line_id (only if SaleOrderLines exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND tablename = 'SaleOrderLines' 
            AND indexname = 'idx_sale_order_lines_quote_line_id'
        ) THEN
            CREATE INDEX idx_sale_order_lines_quote_line_id 
            ON "SaleOrderLines"(quote_line_id) 
            WHERE deleted = false;
            
            RAISE NOTICE '✅ Created index idx_sale_order_lines_quote_line_id';
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 5: Create OrganizationCounters table (Safe Sale Order Numbering)
-- ====================================================

CREATE TABLE IF NOT EXISTS "OrganizationCounters" (
    organization_id uuid NOT NULL,
    key text NOT NULL,
    last_value integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    
    PRIMARY KEY (organization_id, key),
    
    CONSTRAINT fk_organization_counters_organization 
        FOREIGN KEY (organization_id) 
        REFERENCES "Organizations"(id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_organization_counters_org_key 
    ON "OrganizationCounters"(organization_id, key);

COMMENT ON TABLE "OrganizationCounters" IS 
    'Safe counter table for generating sequential numbers (e.g., sale order numbers) per organization';

-- ====================================================
-- STEP 6: Create helper functions
-- ====================================================

-- Function to get next counter value (thread-safe)
CREATE OR REPLACE FUNCTION public.get_next_counter_value(
    p_organization_id uuid,
    p_key text
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_value integer;
BEGIN
    -- Insert or update counter with SELECT FOR UPDATE to ensure thread safety
    INSERT INTO "OrganizationCounters" (organization_id, key, last_value)
    VALUES (p_organization_id, p_key, 0)
    ON CONFLICT (organization_id, key) 
    DO UPDATE SET 
        last_value = "OrganizationCounters".last_value + 1,
        updated_at = now()
    RETURNING last_value INTO v_next_value;
    
    -- If insert happened, we need to increment
    IF v_next_value = 0 THEN
        UPDATE "OrganizationCounters"
        SET last_value = 1, updated_at = now()
        WHERE organization_id = p_organization_id AND key = p_key
        RETURNING last_value INTO v_next_value;
    END IF;
    
    RETURN v_next_value;
END;
$$;

COMMENT ON FUNCTION public.get_next_counter_value IS 
    'Thread-safe function to get and increment a counter value for an organization';

-- Function to normalize UOM to canonical form
CREATE OR REPLACE FUNCTION public.normalize_uom_to_canonical(
    p_uom text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Canonical UOM: 'm' for length, 'ea' for everything else
    IF UPPER(TRIM(COALESCE(p_uom, ''))) IN ('MTS', 'M', 'METER', 'METERS', 'YD', 'YARD', 'YARDS', 'FT', 'FEET') THEN
        RETURN 'm';
    ELSE
        RETURN 'ea';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.normalize_uom_to_canonical IS 
    'Normalizes UOM to canonical form: length units -> ''m'', everything else -> ''ea''';

-- Function to derive category_code from component_role
CREATE OR REPLACE FUNCTION public.derive_category_code_from_role(
    p_component_role text
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_component_role IS NULL THEN
        RETURN 'accessory';
    END IF;
    
    -- Case-insensitive matching
    IF LOWER(p_component_role) LIKE '%fabric%' THEN
        RETURN 'fabric';
    ELSIF LOWER(p_component_role) LIKE '%tube%' THEN
        RETURN 'tube';
    ELSIF LOWER(p_component_role) LIKE '%motor%' OR LOWER(p_component_role) LIKE '%drive%' THEN
        RETURN 'motor';
    ELSIF LOWER(p_component_role) LIKE '%bracket%' THEN
        RETURN 'bracket';
    ELSIF LOWER(p_component_role) LIKE '%cassette%' THEN
        RETURN 'cassette';
    ELSIF LOWER(p_component_role) LIKE '%side_channel%' OR LOWER(p_component_role) LIKE '%side channel%' THEN
        RETURN 'side_channel';
    ELSIF LOWER(p_component_role) LIKE '%bottom_channel%' OR LOWER(p_component_role) LIKE '%bottom channel%' THEN
        RETURN 'bottom_channel';
    ELSE
        RETURN 'accessory';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.derive_category_code_from_role IS 
    'Derives category_code from component_role using pattern matching';

-- Ensure get_unit_cost_in_uom exists (reuse if available, create minimal version if not)
-- Note: We use CREATE OR REPLACE which is idempotent, so we don't need DO block
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
    
    -- Try to find conversion multiplier from UomConversions table if it exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'UomConversions') THEN
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
        
        -- If conversion found, use it
        IF v_multiplier IS NOT NULL THEN
            RETURN v_cost_exw / v_multiplier;
        END IF;
    END IF;
    
    -- Simple conversions for length units (fallback if UomConversions doesn't exist)
    IF p_target_uom = 'm' THEN
        IF v_cost_uom = 'yd' THEN
            RETURN v_cost_exw / 0.9144;
        ELSIF v_cost_uom = 'ft' THEN
            RETURN v_cost_exw / 3.28084;
        ELSIF v_cost_uom IN ('m', 'mts') THEN
            RETURN v_cost_exw;
        END IF;
    END IF;
    
    -- For 'ea' or other cases, just return cost_exw
    RETURN v_cost_exw;
END;
$$;

COMMENT ON FUNCTION public.get_unit_cost_in_uom IS 
    'Converts unit cost from catalog_item cost_uom to target_uom. Uses UomConversions table if available, otherwise uses simple conversions.';

-- ====================================================
-- STEP 7: Create main workflow function
-- ====================================================

CREATE OR REPLACE FUNCTION public.on_quote_approved_create_operational_docs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_sale_order_line_id uuid;
    v_bom_instance_id uuid;
    v_quote_line_record RECORD;
    v_component_record RECORD;
    v_line_number integer;
    v_subtotal numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
    v_next_counter integer;
    v_canonical_uom text;
    v_unit_cost_exw numeric(12,4);
    v_total_cost_exw numeric(12,4);
    v_category_code text;
    v_item_name text;
    v_validated_side_channel_type text;
BEGIN
    -- Only process when status transitions to 'approved'
    IF NEW.status != 'approved' THEN
        RETURN NEW;
    END IF;
    
    -- Log trigger execution
    RAISE NOTICE '🔔 Trigger fired: Quote % status changed to approved', NEW.id;
    
    -- Check if required tables exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        -- Tables don't exist yet, skip processing
        RAISE WARNING '⚠️ SaleOrders or SaleOrderLines tables do not exist, skipping operational docs creation';
        RETURN NEW;
    END IF;
    
    -- Load quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = NEW.id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ Quote % not found or deleted, skipping operational docs creation', NEW.id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '✅ Quote % loaded, organization_id: %', NEW.id, v_quote_record.organization_id;
    
    -- Step A: Find or create SaleOrder for this quote
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE quote_id = NEW.id
    AND organization_id = v_quote_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Generate sale order number
        v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
        v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
        
        -- Extract totals from JSONB
        v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
        v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
        v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
        
        -- Create SaleOrder
        INSERT INTO "SaleOrders" (
            organization_id,
            quote_id,
            customer_id,
            sale_order_no,
            status,
            currency,
            subtotal,
            tax,
            total,
            notes,
            order_date,
            created_by,
            updated_by
        ) VALUES (
            v_quote_record.organization_id,
            NEW.id,
            v_quote_record.customer_id,
            v_sale_order_no,
            'draft',
            COALESCE(v_quote_record.currency, 'USD'),
            v_subtotal,
            v_tax,
            v_total,
            v_quote_record.notes,
            CURRENT_DATE,
            NEW.created_by,
            NEW.updated_by
        ) RETURNING id INTO v_sale_order_id;
    END IF;
    
    -- Step B: For each QuoteLine, find or create SaleOrderLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = NEW.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Find existing SaleOrderLine for this quote_line_id
        SELECT id INTO v_sale_order_line_id
        FROM "SaleOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            -- Get next line number
            SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
            FROM "SaleOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND deleted = false;
            
            -- Validate and normalize side_channel_type to match constraint
            -- Constraint allows: NULL, 'side_only', 'side_and_bottom'
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_only%' OR 
                  LOWER(v_quote_line_record.side_channel_type) = 'side' THEN
                v_validated_side_channel_type := 'side_only';
            ELSIF LOWER(v_quote_line_record.side_channel_type) LIKE '%side_and_bottom%' OR
                  LOWER(v_quote_line_record.side_channel_type) LIKE '%both%' OR
                  LOWER(v_quote_line_record.side_channel_type) = 'side_and_bottom' THEN
                v_validated_side_channel_type := 'side_and_bottom';
            ELSE
                -- Invalid value, set to NULL
                v_validated_side_channel_type := NULL;
                RAISE NOTICE 'Invalid side_channel_type value "%" for QuoteLine %, setting to NULL', 
                    v_quote_line_record.side_channel_type, v_quote_line_record.id;
            END IF;
            
            -- Create SaleOrderLine
            INSERT INTO "SaleOrderLines" (
                organization_id,
                sale_order_id,
                quote_line_id,
                catalog_item_id,
                line_number,
                qty,
                unit_price,
                line_total,
                width_m,
                height_m,
                area,
                position,
                collection_name,
                variant_name,
                product_type,
                product_type_id,
                drive_type,
                bottom_rail_type,
                cassette,
                cassette_type,
                side_channel,
                side_channel_type,
                hardware_color,
                created_by,
                updated_by
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
                v_quote_line_record.qty,
                COALESCE(v_quote_line_record.unit_price_snapshot, 0),
                COALESCE(v_quote_line_record.line_total, 0),
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_quote_line_record.area,
                v_quote_line_record.position,
                v_quote_line_record.collection_name,
                v_quote_line_record.variant_name,
                v_quote_line_record.product_type,
                v_quote_line_record.product_type_id,
                v_quote_line_record.drive_type,
                v_quote_line_record.bottom_rail_type,
                COALESCE(v_quote_line_record.cassette, false),
                v_quote_line_record.cassette_type,
                COALESCE(v_quote_line_record.side_channel, false),
                v_validated_side_channel_type,
                v_quote_line_record.hardware_color,
                NEW.created_by,
                NEW.updated_by
            ) RETURNING id INTO v_sale_order_line_id;
        END IF;
        
        -- Step C: Find or create BomInstance for this sale_order_line_id
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sale_order_line_id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                configured_product_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_line_id,
                v_quote_line_record.id,
                NULL, -- Can be NULL now
                'locked', -- Locked because quote is approved
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
        END IF;
        
        -- Step D: Populate BomInstanceLines from QuoteLineComponents (frozen snapshot)
        FOR v_component_record IN
            SELECT 
                qlc.*,
                ci.item_name
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_quote_line_record.id
            AND qlc.source = 'configured_component'
            AND qlc.deleted = false
            AND ci.deleted = false
        LOOP
            -- Compute canonical UOM
            v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
            
            -- Compute unit_cost_exw using get_unit_cost_in_uom
            v_unit_cost_exw := public.get_unit_cost_in_uom(
                v_component_record.catalog_item_id,
                v_canonical_uom,
                v_quote_record.organization_id
            );
            
            -- If unit_cost_exw is NULL or 0, try to use the stored unit_cost_exw from QuoteLineComponents
            IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
            END IF;
            
            -- Calculate total_cost_exw
            v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
            
            -- Derive category_code from component_role
            v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
            
            -- Insert BomInstanceLine with ON CONFLICT DO NOTHING (frozen first insert)
            INSERT INTO "BomInstanceLines" (
                bom_instance_id,
                source_template_line_id,
                resolved_part_id,
                resolved_sku,
                part_role,
                qty,
                uom,
                description,
                unit_cost_exw,
                total_cost_exw,
                category_code,
                created_at,
                updated_at,
                deleted
            ) VALUES (
                v_bom_instance_id,
                NULL, -- source_template_line_id (optional)
                v_component_record.catalog_item_id,
                NULL, -- resolved_sku (can be populated later if needed)
                v_component_record.component_role,
                v_component_record.qty,
                v_canonical_uom,
                v_component_record.item_name,
                v_unit_cost_exw,
                v_total_cost_exw,
                v_category_code,
                now(),
                now(),
                false
            )
            ON CONFLICT (bom_instance_id, resolved_part_id, COALESCE(part_role, ''), uom) 
            WHERE deleted = false
            DO NOTHING; -- Frozen snapshot: don't update if exists
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Operational docs creation completed for Quote %', NEW.id;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_quote_approved_create_operational_docs for Quote %: %', NEW.id, SQLERRM;
        -- Return NEW to allow the quote update to succeed even if operational docs creation fails
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.on_quote_approved_create_operational_docs IS 
    'Trigger function that creates SaleOrder, SaleOrderLines, BomInstances, and BomInstanceLines when a Quote is approved. Re-entrant: creates only missing pieces.';

-- ====================================================
-- STEP 8: Create trigger
-- ====================================================

DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";

CREATE TRIGGER trg_on_quote_approved_create_operational_docs
    AFTER UPDATE OF status ON "Quotes"
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
    EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();

-- ====================================================
-- STEP 9: Create views
-- ====================================================

-- View: SaleOrderMaterialList (only if SaleOrders and SaleOrderLines tables exist)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrders'
    ) AND EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'SaleOrderLines'
    ) THEN
        EXECUTE '
        CREATE OR REPLACE VIEW "SaleOrderMaterialList" AS
        SELECT 
            so.id AS sale_order_id,
            so.sale_order_no,
            bil.category_code,
            bil.resolved_part_id AS catalog_item_id,
            ci.sku,
            ci.item_name,
            bil.uom,
            SUM(bil.qty) AS total_qty,
            AVG(bil.unit_cost_exw) AS avg_unit_cost_exw,
            SUM(bil.total_cost_exw) AS total_cost_exw
        FROM "SaleOrders" so
        INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
        INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
        INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
        LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
        WHERE so.deleted = false
        GROUP BY 
            so.id,
            so.sale_order_no,
            bil.category_code,
            bil.resolved_part_id,
            ci.sku,
            ci.item_name,
            bil.uom
        ORDER BY 
            so.sale_order_no,
            bil.category_code,
            ci.sku';
        
        EXECUTE 'COMMENT ON VIEW "SaleOrderMaterialList" IS 
            ''Material list aggregated by sale order, category, and catalog item. Works immediately after quote approval without ManufacturingOrders.''';
        
        RAISE NOTICE '✅ Created SaleOrderMaterialList view';
    ELSE
        RAISE NOTICE '⏭️  SaleOrders or SaleOrderLines tables do not exist, skipping SaleOrderMaterialList view';
    END IF;
END $$;

-- View: ManufacturingMaterialList (only if ManufacturingOrders table exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'ManufacturingOrders'
    ) THEN
        CREATE OR REPLACE VIEW "ManufacturingMaterialList" AS
        SELECT 
            mo.id AS manufacturing_order_id,
            mo.manufacturing_order_no,
            bil.category_code,
            bil.resolved_part_id AS catalog_item_id,
            ci.sku,
            ci.item_name,
            bil.uom,
            SUM(bil.qty) AS total_qty,
            AVG(bil.unit_cost_exw) AS avg_unit_cost_exw,
            SUM(bil.total_cost_exw) AS total_cost_exw
        FROM "ManufacturingOrders" mo
        INNER JOIN "BomInstances" bi ON bi.manufacturing_order_id = mo.id AND bi.deleted = false
        INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
        LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
        WHERE mo.deleted = false
        GROUP BY 
            mo.id,
            mo.manufacturing_order_no,
            bil.category_code,
            bil.resolved_part_id,
            ci.sku,
            ci.item_name,
            bil.uom
        ORDER BY 
            mo.manufacturing_order_no,
            bil.category_code,
            ci.sku;
        
        COMMENT ON VIEW "ManufacturingMaterialList" IS 
            'Material list aggregated by manufacturing order, category, and catalog item.';
        
        RAISE NOTICE '✅ Created ManufacturingMaterialList view';
    ELSE
        RAISE NOTICE '⏭️  ManufacturingOrders table does not exist, skipping ManufacturingMaterialList view';
    END IF;
END $$;

-- ====================================================
-- STEP 10: Enable RLS for OrganizationCounters
-- ====================================================

ALTER TABLE "OrganizationCounters" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "organization_counters_select_own_org" ON "OrganizationCounters";
CREATE POLICY "organization_counters_select_own_org"
    ON "OrganizationCounters"
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
        )
    );

DROP POLICY IF EXISTS "organization_counters_insert_own_org" ON "OrganizationCounters";
CREATE POLICY "organization_counters_insert_own_org"
    ON "OrganizationCounters"
    FOR INSERT
    WITH CHECK (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
            AND role IN ('owner', 'admin', 'super_admin')
        )
    );

DROP POLICY IF EXISTS "organization_counters_update_own_org" ON "OrganizationCounters";
CREATE POLICY "organization_counters_update_own_org"
    ON "OrganizationCounters"
    FOR UPDATE
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM "OrganizationUsers" 
            WHERE user_id = auth.uid() 
            AND deleted = false
            AND role IN ('owner', 'admin', 'super_admin')
        )
    );

-- ====================================================
-- STEP 11: Test queries (in comments)
-- ====================================================

/*
-- TEST 1: Approve a quote and verify SaleOrder is created
-- First, find a quote that is not approved:
SELECT id, quote_no, status, organization_id 
FROM "Quotes" 
WHERE status != 'approved' AND deleted = false 
LIMIT 1;

-- Then update it to approved (this will trigger the function):
UPDATE "Quotes" 
SET status = 'approved' 
WHERE id = '<quote_id>';

-- Verify SaleOrder was created:
SELECT so.*, q.quote_no 
FROM "SaleOrders" so
INNER JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.quote_id = '<quote_id>';

-- TEST 2: Re-approving does not duplicate
-- Update the same quote to 'draft' then back to 'approved':
UPDATE "Quotes" SET status = 'draft' WHERE id = '<quote_id>';
UPDATE "Quotes" SET status = 'approved' WHERE id = '<quote_id>';

-- Verify only one SaleOrder exists:
SELECT COUNT(*) FROM "SaleOrders" WHERE quote_id = '<quote_id>' AND deleted = false;
-- Should return 1

-- TEST 3: Partial data recovery (delete some bom lines, then re-approve)
-- Delete some BomInstanceLines:
DELETE FROM "BomInstanceLines" 
WHERE bom_instance_id IN (
    SELECT bi.id 
    FROM "BomInstances" bi
    INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.quote_id = '<quote_id>'
)
LIMIT 5;

-- Re-run the function manually (or re-approve):
SELECT public.on_quote_approved_create_operational_docs();

-- Or trigger by updating quote status:
UPDATE "Quotes" SET status = 'draft' WHERE id = '<quote_id>';
UPDATE "Quotes" SET status = 'approved' WHERE id = '<quote_id>';

-- Verify missing lines were restored:
SELECT COUNT(*) 
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>' AND bil.deleted = false;

-- TEST 4: Verify material list view works
SELECT * FROM "SaleOrderMaterialList" 
WHERE sale_order_id = '<sale_order_id>'
ORDER BY category_code, sku;
*/

-- ====================================================
-- STEP 12: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Extended BomInstances: sale_order_line_id, quote_line_id, nullable configured_product_id';
    RAISE NOTICE '   - Extended BomInstanceLines: description, unit_cost_exw, total_cost_exw, category_code';
    RAISE NOTICE '   - Table: OrganizationCounters';
    RAISE NOTICE '   - Function: get_next_counter_value()';
    RAISE NOTICE '   - Function: normalize_uom_to_canonical()';
    RAISE NOTICE '   - Function: derive_category_code_from_role()';
    RAISE NOTICE '   - Function: on_quote_approved_create_operational_docs()';
    RAISE NOTICE '   - Trigger: trg_on_quote_approved_create_operational_docs';
    RAISE NOTICE '   - View: SaleOrderMaterialList';
    RAISE NOTICE '   - Indexes: 4 unique constraints, 4 lookup indexes';
    RAISE NOTICE '   - RLS Policies: 3 for OrganizationCounters';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Operational Flow:';
    RAISE NOTICE '   Quote (approved) → SaleOrder → SaleOrderLines → BomInstances → BomInstanceLines';
    RAISE NOTICE '';
    RAISE NOTICE '✨ Features:';
    RAISE NOTICE '   - Re-entrant: creates only missing pieces';
    RAISE NOTICE '   - Frozen snapshots: costs and descriptions locked at approval time';
    RAISE NOTICE '   - Safe numbering: thread-safe sale order number generation';
    RAISE NOTICE '   - Canonical UOM: length units → ''m'', everything else → ''ea''';
    RAISE NOTICE '';
END $$;

