-- ====================================================
-- Migration: Enhanced BOM Architecture
-- ====================================================
-- This extends the existing BOM system with:
-- 1) Products (base product definitions)
-- 2) ProductOptions (normalized option definitions)
-- 3) ConfiguredProducts (structured configurations)
-- 4) CompatibilityRules (explicit motor/tube/cassette rules)
-- 5) BomInstances (traceability for generated BOMs)
-- 
-- NOTE: This does NOT replace existing BOMTemplates/BOMComponents
-- It adds new tables that work alongside them
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Creating Enhanced BOM Architecture...';
  RAISE NOTICE '';
END $$;

-- ====================================================
-- PART 1: ENUMS
-- ====================================================

-- Option input types
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'product_option_input_type') THEN
    CREATE TYPE product_option_input_type AS ENUM (
      'select',      -- Dropdown with predefined values
      'boolean',     -- Checkbox (true/false)
      'number',      -- Numeric input
      'text'         -- Text input
    );
    RAISE NOTICE '  ✅ Created enum: product_option_input_type';
  ELSE
    RAISE NOTICE '  ℹ️  Enum product_option_input_type already exists';
  END IF;
END $$;

-- Quantity types for BOM lines
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bom_qty_type') THEN
    CREATE TYPE bom_qty_type AS ENUM (
      'fixed',       -- Fixed count (e.g., 2 brackets)
      'per_width',   -- Linear: qty = width_m * qty_value
      'per_area',    -- Area: qty = width_m * height_m * qty_value
      'by_option'    -- Selected by option value (e.g., motor family)
    );
    RAISE NOTICE '  ✅ Created enum: bom_qty_type';
  ELSE
    RAISE NOTICE '  ℹ️  Enum bom_qty_type already exists';
  END IF;
END $$;

-- BOM Instance status
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bom_instance_status') THEN
    CREATE TYPE bom_instance_status AS ENUM (
      'draft',       -- Being configured
      'locked'       -- Approved/sent to production
    );
    RAISE NOTICE '  ✅ Created enum: bom_instance_status';
  ELSE
    RAISE NOTICE '  ℹ️  Enum bom_instance_status already exists';
  END IF;
END $$;

-- ====================================================
-- PART 2: CORE TABLES
-- ====================================================

-- 1) Products (base product definitions)
CREATE TABLE IF NOT EXISTS public."Products" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  code text NOT NULL, -- e.g., 'ABSOLUTE_ROLLER', 'ABSOLUTE_ROLLER_CASSETTE'
  name text NOT NULL,
  description text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_products_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT check_products_code_not_empty 
    CHECK (length(trim(code)) > 0),
  CONSTRAINT check_products_name_not_empty 
    CHECK (length(trim(name)) > 0)
);

COMMENT ON TABLE public."Products" IS 
  'Base product definitions (e.g., ABSOLUTE_ROLLER). These are the foundation for BOM templates.';
COMMENT ON COLUMN public."Products".code IS 
  'Unique product code within organization (e.g., ABSOLUTE_ROLLER)';
COMMENT ON COLUMN public."Products".name IS 
  'Display name (e.g., "Absolute Roller Shade")';

-- 2) ProductOptions (option definitions)
CREATE TABLE IF NOT EXISTS public."ProductOptions" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  option_code text NOT NULL, -- e.g., 'operation_type', 'cassette_shape', 'tube_type'
  name text NOT NULL, -- Display name
  description text,
  input_type product_option_input_type NOT NULL DEFAULT 'select',
  is_required boolean NOT NULL DEFAULT false,
  default_value text, -- JSON string for default
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_product_options_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT check_product_options_code_not_empty 
    CHECK (length(trim(option_code)) > 0),
  CONSTRAINT check_product_options_name_not_empty 
    CHECK (length(trim(name)) > 0)
);

COMMENT ON TABLE public."ProductOptions" IS 
  'Option definitions for products (e.g., operation_type, cassette_shape, tube_type)';
COMMENT ON COLUMN public."ProductOptions".option_code IS 
  'Unique option code (e.g., operation_type, cassette_shape)';
COMMENT ON COLUMN public."ProductOptions".input_type IS 
  'Type of input: select, boolean, number, text';

-- 3) ProductOptionValues (allowed values for select options)
CREATE TABLE IF NOT EXISTS public."ProductOptionValues" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  option_id uuid NOT NULL,
  value_code text NOT NULL, -- e.g., 'manual', 'motor', 'L', 'round', 'RTU-65'
  label text NOT NULL, -- Display label
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_product_option_values_option 
    FOREIGN KEY (option_id) 
    REFERENCES public."ProductOptions"(id) 
    ON DELETE CASCADE,
  CONSTRAINT check_product_option_values_code_not_empty 
    CHECK (length(trim(value_code)) > 0),
  CONSTRAINT check_product_option_values_label_not_empty 
    CHECK (length(trim(label)) > 0)
);

COMMENT ON TABLE public."ProductOptionValues" IS 
  'Allowed values for select-type ProductOptions';
COMMENT ON COLUMN public."ProductOptionValues".value_code IS 
  'Code value (e.g., manual, motor, L, round, RTU-65)';
COMMENT ON COLUMN public."ProductOptionValues".label IS 
  'Display label (e.g., "Manual", "Motorized", "L-Shape", "Round", "RTU-65")';

-- 4) ConfiguredProducts (structured product configurations)
CREATE TABLE IF NOT EXISTS public."ConfiguredProducts" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  product_id uuid, -- FK to Products (optional - can be NULL if using ProductTypes)
  product_type_id uuid, -- FK to ProductTypes (for compatibility with existing system)
  quote_line_id uuid, -- FK to QuoteLines
  -- Dimensions
  width_mm numeric,
  height_mm numeric,
  qty integer NOT NULL DEFAULT 1,
  -- Fabric reference
  fabric_catalog_item_id uuid, -- FK to CatalogItems
  -- Metadata
  configuration_code text, -- Generated code like "RC-xxxx" (optional)
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_configured_products_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_configured_products_product 
    FOREIGN KEY (product_id) 
    REFERENCES public."Products"(id) 
    ON DELETE SET NULL,
  CONSTRAINT fk_configured_products_product_type 
    FOREIGN KEY (product_type_id) 
    REFERENCES public."ProductTypes"(id) 
    ON DELETE RESTRICT,
  CONSTRAINT fk_configured_products_quote_line 
    FOREIGN KEY (quote_line_id) 
    REFERENCES public."QuoteLines"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_configured_products_fabric 
    FOREIGN KEY (fabric_catalog_item_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE SET NULL,
  CONSTRAINT check_configured_products_qty_positive 
    CHECK (qty > 0),
  CONSTRAINT check_configured_products_width_positive 
    CHECK (width_mm IS NULL OR width_mm > 0),
  CONSTRAINT check_configured_products_height_positive 
    CHECK (height_mm IS NULL OR height_mm > 0)
);

COMMENT ON TABLE public."ConfiguredProducts" IS 
  'Structured product configurations linked to QuoteLines';
COMMENT ON COLUMN public."ConfiguredProducts".product_id IS 
  'Reference to Products table (new system)';
COMMENT ON COLUMN public."ConfiguredProducts".product_type_id IS 
  'Reference to ProductTypes table (existing system - for compatibility)';
COMMENT ON COLUMN public."ConfiguredProducts".configuration_code IS 
  'Generated configuration code (e.g., RC-xxxx) - optional';

-- 5) ConfiguredProductOptions (selected option values)
CREATE TABLE IF NOT EXISTS public."ConfiguredProductOptions" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  configured_product_id uuid NOT NULL,
  option_code text NOT NULL, -- e.g., 'operation_type', 'cassette_shape'
  option_value text NOT NULL, -- e.g., 'motor', 'L', 'RTU-65'
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  -- Constraints
  CONSTRAINT fk_configured_product_options_configured_product 
    FOREIGN KEY (configured_product_id) 
    REFERENCES public."ConfiguredProducts"(id) 
    ON DELETE CASCADE,
  CONSTRAINT uq_configured_product_options_option 
    UNIQUE (configured_product_id, option_code),
  CONSTRAINT check_configured_product_options_value_not_empty 
    CHECK (length(trim(option_value)) > 0)
);

COMMENT ON TABLE public."ConfiguredProductOptions" IS 
  'Selected option values for a ConfiguredProduct';
COMMENT ON COLUMN public."ConfiguredProductOptions".option_code IS 
  'Option code (e.g., operation_type, cassette_shape)';
COMMENT ON COLUMN public."ConfiguredProductOptions".option_value IS 
  'Selected value (e.g., motor, L, RTU-65)';

-- ====================================================
-- PART 3: COMPATIBILITY RULES
-- ====================================================

-- 6) MotorTubeCompatibility (motor/tube compatibility rules)
CREATE TABLE IF NOT EXISTS public."MotorTubeCompatibility" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  tube_type text NOT NULL, -- e.g., 'RTU-42', 'RTU-50', 'RTU-65', 'RTU-80'
  motor_family text NOT NULL, -- e.g., 'CM-05', 'CM-06', 'CM-09', 'CM-10'
  required_crown_item_id uuid, -- FK to CatalogItems (motor crown/adapter)
  required_drive_item_id uuid, -- FK to CatalogItems (drive mechanism)
  required_accessory_item_id uuid, -- FK to CatalogItems (optional accessory)
  notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_motor_tube_compatibility_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_motor_tube_compatibility_crown 
    FOREIGN KEY (required_crown_item_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE SET NULL,
  CONSTRAINT fk_motor_tube_compatibility_drive 
    FOREIGN KEY (required_drive_item_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE SET NULL,
  CONSTRAINT fk_motor_tube_compatibility_accessory 
    FOREIGN KEY (required_accessory_item_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE SET NULL,
  CONSTRAINT check_motor_tube_compatibility_tube_not_empty 
    CHECK (length(trim(tube_type)) > 0),
  CONSTRAINT check_motor_tube_compatibility_motor_not_empty 
    CHECK (length(trim(motor_family)) > 0)
);

COMMENT ON TABLE public."MotorTubeCompatibility" IS 
  'Compatibility rules between motor families and tube types';
COMMENT ON COLUMN public."MotorTubeCompatibility".tube_type IS 
  'Tube type code (e.g., RTU-42, RTU-50, RTU-65, RTU-80)';
COMMENT ON COLUMN public."MotorTubeCompatibility".motor_family IS 
  'Motor family code (e.g., CM-05, CM-06, CM-09, CM-10)';

-- 7) CassettePartsMapping (cassette shape to parts mapping)
CREATE TABLE IF NOT EXISTS public."CassettePartsMapping" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  cassette_shape text NOT NULL, -- 'none', 'L', 'round', 'square'
  part_role text NOT NULL, -- 'profile', 'endcap_left', 'endcap_right', 'clip', etc.
  catalog_item_id uuid NOT NULL, -- FK to CatalogItems
  qty_per_unit integer NOT NULL DEFAULT 1,
  notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_cassette_parts_mapping_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_cassette_parts_mapping_catalog_item 
    FOREIGN KEY (catalog_item_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE RESTRICT,
  CONSTRAINT check_cassette_parts_mapping_shape_not_empty 
    CHECK (length(trim(cassette_shape)) > 0),
  CONSTRAINT check_cassette_parts_mapping_role_not_empty 
    CHECK (length(trim(part_role)) > 0),
  CONSTRAINT check_cassette_parts_mapping_qty_positive 
    CHECK (qty_per_unit > 0),
  CONSTRAINT check_cassette_parts_mapping_shape_valid 
    CHECK (cassette_shape IN ('none', 'L', 'round', 'square'))
);

COMMENT ON TABLE public."CassettePartsMapping" IS 
  'Mapping of cassette shapes to required parts';
COMMENT ON COLUMN public."CassettePartsMapping".cassette_shape IS 
  'Cassette shape: none, L, round, square';
COMMENT ON COLUMN public."CassettePartsMapping".part_role IS 
  'Part role: profile, endcap_left, endcap_right, clip, etc.';

-- 8) HardwareColorMapping (hardware color to part mapping)
CREATE TABLE IF NOT EXISTS public."HardwareColorMapping" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  base_part_id uuid NOT NULL, -- FK to CatalogItems (base SKU)
  hardware_color text NOT NULL, -- 'white', 'black', 'silver', 'bronze'
  mapped_part_id uuid NOT NULL, -- FK to CatalogItems (colored variant)
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_hardware_color_mapping_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_hardware_color_mapping_base_part 
    FOREIGN KEY (base_part_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_hardware_color_mapping_mapped_part 
    FOREIGN KEY (mapped_part_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE RESTRICT,
  CONSTRAINT check_hardware_color_mapping_color_valid 
    CHECK (hardware_color IN ('white', 'black', 'silver', 'bronze')),
  CONSTRAINT check_hardware_color_mapping_different_parts 
    CHECK (base_part_id != mapped_part_id)
);

COMMENT ON TABLE public."HardwareColorMapping" IS 
  'Mapping of base parts to colored variants based on hardware color selection';
COMMENT ON COLUMN public."HardwareColorMapping".base_part_id IS 
  'Base SKU (e.g., RC4004)';
COMMENT ON COLUMN public."HardwareColorMapping".hardware_color IS 
  'Hardware color: white, black, silver, bronze';
COMMENT ON COLUMN public."HardwareColorMapping".mapped_part_id IS 
  'Colored variant SKU (e.g., RC4004-WH for white)';

-- ====================================================
-- PART 4: ENHANCED BOM TEMPLATES (extends existing)
-- ====================================================

-- 9) BomTemplateLines (enhanced BOM template lines)
-- NOTE: This extends the existing BOMComponents table
-- We add this as a new table that can reference BOMComponents
-- OR we can add columns to BOMComponents (preferred to avoid duplication)

-- Add qty_type column to BOMComponents if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents' 
    AND column_name = 'qty_type'
  ) THEN
    ALTER TABLE public."BOMComponents" 
    ADD COLUMN qty_type bom_qty_type DEFAULT 'fixed';
    RAISE NOTICE '  ✅ Added qty_type column to BOMComponents';
  ELSE
    RAISE NOTICE '  ℹ️  qty_type column already exists in BOMComponents';
  END IF;
END $$;

-- Add qty_value column to BOMComponents if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents' 
    AND column_name = 'qty_value'
  ) THEN
    ALTER TABLE public."BOMComponents" 
    ADD COLUMN qty_value numeric;
    RAISE NOTICE '  ✅ Added qty_value column to BOMComponents';
  ELSE
    RAISE NOTICE '  ℹ️  qty_value column already exists in BOMComponents';
  END IF;
END $$;

-- Add select_rule column to BOMComponents if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents' 
    AND column_name = 'select_rule'
  ) THEN
    ALTER TABLE public."BOMComponents" 
    ADD COLUMN select_rule jsonb;
    RAISE NOTICE '  ✅ Added select_rule column to BOMComponents';
  ELSE
    RAISE NOTICE '  ℹ️  qty_value column already exists in BOMComponents';
  END IF;
END $$;

COMMENT ON COLUMN public."BOMComponents".qty_type IS 
  'Quantity type: fixed, per_width, per_area, by_option';
COMMENT ON COLUMN public."BOMComponents".qty_value IS 
  'Quantity value (for fixed: count, for per_width/per_area: multiplier)';
COMMENT ON COLUMN public."BOMComponents".select_rule IS 
  'JSONB rule for selecting part: {"type": "by_option", "option_code": "motor_family"}, {"type": "by_mapping", "mapping_table": "HardwareColorMapping"}';

-- ====================================================
-- PART 5: BOM INSTANCES (traceability)
-- ====================================================

-- 10) BomInstances (generated BOM instances for traceability)
CREATE TABLE IF NOT EXISTS public."BomInstances" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  configured_product_id uuid NOT NULL, -- FK to ConfiguredProducts
  bom_template_id uuid, -- FK to BOMTemplates (optional - for reference)
  status bom_instance_status NOT NULL DEFAULT 'draft',
  generated_at timestamptz NOT NULL DEFAULT now(),
  locked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  
  -- Constraints
  CONSTRAINT fk_bom_instances_organization 
    FOREIGN KEY (organization_id) 
    REFERENCES public."Organizations"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_bom_instances_configured_product 
    FOREIGN KEY (configured_product_id) 
    REFERENCES public."ConfiguredProducts"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_bom_instances_bom_template 
    FOREIGN KEY (bom_template_id) 
    REFERENCES public."BOMTemplates"(id) 
    ON DELETE SET NULL
);

COMMENT ON TABLE public."BomInstances" IS 
  'BOM instances generated from configurations (for traceability)';
COMMENT ON COLUMN public."BomInstances".configured_product_id IS 
  'Reference to ConfiguredProduct that generated this BOM';
COMMENT ON COLUMN public."BomInstances".status IS 
  'Status: draft (being configured) or locked (approved/sent to production)';

-- 11) BomInstanceLines (resolved BOM lines)
CREATE TABLE IF NOT EXISTS public."BomInstanceLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bom_instance_id uuid NOT NULL,
  source_template_line_id uuid, -- FK to BOMComponents (optional - for reference)
  resolved_part_id uuid NOT NULL, -- FK to CatalogItems
  resolved_sku text, -- Cached SKU (for performance)
  part_role text, -- e.g., 'tube', 'bracket_left', 'motor', 'cassette_profile'
  qty numeric NOT NULL,
  uom text NOT NULL DEFAULT 'unit',
  rule_applied text, -- Human-readable reason (e.g., "Selected by motor_family=CM-09")
  inputs_snapshot jsonb, -- Store key config inputs used (e.g., {"width_m": 2.5, "motor_family": "CM-09"})
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  -- Constraints
  CONSTRAINT fk_bom_instance_lines_bom_instance 
    FOREIGN KEY (bom_instance_id) 
    REFERENCES public."BomInstances"(id) 
    ON DELETE CASCADE,
  CONSTRAINT fk_bom_instance_lines_source_template 
    FOREIGN KEY (source_template_line_id) 
    REFERENCES public."BOMComponents"(id) 
    ON DELETE SET NULL,
  CONSTRAINT fk_bom_instance_lines_resolved_part 
    FOREIGN KEY (resolved_part_id) 
    REFERENCES public."CatalogItems"(id) 
    ON DELETE RESTRICT,
  CONSTRAINT check_bom_instance_lines_qty_positive 
    CHECK (qty > 0),
  CONSTRAINT check_bom_instance_lines_uom_not_empty 
    CHECK (length(trim(uom)) > 0)
);

COMMENT ON TABLE public."BomInstanceLines" IS 
  'Resolved BOM lines for a BomInstance (traceability)';
COMMENT ON COLUMN public."BomInstanceLines".source_template_line_id IS 
  'Reference to BOMComponents line that generated this (optional)';
COMMENT ON COLUMN public."BomInstanceLines".resolved_part_id IS 
  'Final resolved CatalogItem SKU';
COMMENT ON COLUMN public."BomInstanceLines".rule_applied IS 
  'Human-readable reason for part selection';
COMMENT ON COLUMN public."BomInstanceLines".inputs_snapshot IS 
  'JSONB snapshot of configuration inputs used (for debugging/audit)';

-- ====================================================
-- PART 6: INDEXES
-- ====================================================

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_organization_id 
  ON public."Products"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_products_code 
  ON public."Products"(organization_id, code) 
  WHERE deleted = false AND active = true;
-- Unique index for Products (organization_id, code) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_products_org_code 
  ON public."Products"(organization_id, code) 
  WHERE deleted = false;

-- ProductOptions indexes
CREATE INDEX IF NOT EXISTS idx_product_options_organization_id 
  ON public."ProductOptions"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_product_options_code 
  ON public."ProductOptions"(organization_id, option_code) 
  WHERE deleted = false AND active = true;
-- Unique index for ProductOptions (organization_id, option_code) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_product_options_org_code 
  ON public."ProductOptions"(organization_id, option_code) 
  WHERE deleted = false;

-- ProductOptionValues indexes
CREATE INDEX IF NOT EXISTS idx_product_option_values_option_id 
  ON public."ProductOptionValues"(option_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_product_option_values_code 
  ON public."ProductOptionValues"(option_id, value_code) 
  WHERE deleted = false AND active = true;
-- Unique index for ProductOptionValues (option_id, value_code) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_product_option_values_code 
  ON public."ProductOptionValues"(option_id, value_code) 
  WHERE deleted = false;

-- ConfiguredProducts indexes
CREATE INDEX IF NOT EXISTS idx_configured_products_organization_id 
  ON public."ConfiguredProducts"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_configured_products_quote_line_id 
  ON public."ConfiguredProducts"(quote_line_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_configured_products_product_id 
  ON public."ConfiguredProducts"(product_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_configured_products_product_type_id 
  ON public."ConfiguredProducts"(product_type_id) 
  WHERE deleted = false;

-- ConfiguredProductOptions indexes
CREATE INDEX IF NOT EXISTS idx_configured_product_options_configured_product_id 
  ON public."ConfiguredProductOptions"(configured_product_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_options_option_code 
  ON public."ConfiguredProductOptions"(configured_product_id, option_code);

-- MotorTubeCompatibility indexes
CREATE INDEX IF NOT EXISTS idx_motor_tube_compatibility_organization_id 
  ON public."MotorTubeCompatibility"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_motor_tube_compatibility_tube_motor 
  ON public."MotorTubeCompatibility"(organization_id, tube_type, motor_family) 
  WHERE deleted = false AND active = true;
-- Unique index for MotorTubeCompatibility (organization_id, tube_type, motor_family) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_motor_tube_compatibility 
  ON public."MotorTubeCompatibility"(organization_id, tube_type, motor_family) 
  WHERE deleted = false;

-- CassettePartsMapping indexes
CREATE INDEX IF NOT EXISTS idx_cassette_parts_mapping_organization_id 
  ON public."CassettePartsMapping"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_cassette_parts_mapping_shape_role 
  ON public."CassettePartsMapping"(organization_id, cassette_shape, part_role) 
  WHERE deleted = false AND active = true;
-- Unique index for CassettePartsMapping (organization_id, cassette_shape, part_role) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_cassette_parts_mapping 
  ON public."CassettePartsMapping"(organization_id, cassette_shape, part_role) 
  WHERE deleted = false;

-- HardwareColorMapping indexes
CREATE INDEX IF NOT EXISTS idx_hardware_color_mapping_organization_id 
  ON public."HardwareColorMapping"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_hardware_color_mapping_base_color 
  ON public."HardwareColorMapping"(organization_id, base_part_id, hardware_color) 
  WHERE deleted = false AND active = true;
-- Unique index for HardwareColorMapping (organization_id, base_part_id, hardware_color) where not deleted
CREATE UNIQUE INDEX IF NOT EXISTS uq_hardware_color_mapping 
  ON public."HardwareColorMapping"(organization_id, base_part_id, hardware_color) 
  WHERE deleted = false;

-- BomInstances indexes
CREATE INDEX IF NOT EXISTS idx_bom_instances_organization_id 
  ON public."BomInstances"(organization_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_bom_instances_configured_product_id 
  ON public."BomInstances"(configured_product_id) 
  WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_bom_instances_status 
  ON public."BomInstances"(organization_id, status) 
  WHERE deleted = false;

-- BomInstanceLines indexes
CREATE INDEX IF NOT EXISTS idx_bom_instance_lines_bom_instance_id 
  ON public."BomInstanceLines"(bom_instance_id);
CREATE INDEX IF NOT EXISTS idx_bom_instance_lines_resolved_part_id 
  ON public."BomInstanceLines"(resolved_part_id);

-- ====================================================
-- PART 7: RLS (Row Level Security)
-- ====================================================

-- Enable RLS on all new tables
ALTER TABLE public."Products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ProductOptions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ProductOptionValues" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ConfiguredProductOptions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."MotorTubeCompatibility" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."CassettePartsMapping" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."HardwareColorMapping" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BomInstances" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."BomInstanceLines" ENABLE ROW LEVEL SECURITY;

-- RLS Policies (using same pattern as existing tables)
-- Products
DROP POLICY IF EXISTS "Users can view Products for their organization" ON public."Products";
CREATE POLICY "Users can view Products for their organization"
  ON public."Products" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert Products for their organization" ON public."Products";
CREATE POLICY "Users can insert Products for their organization"
  ON public."Products" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

DROP POLICY IF EXISTS "Users can update Products for their organization" ON public."Products";
CREATE POLICY "Users can update Products for their organization"
  ON public."Products" FOR UPDATE
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

-- ProductOptions (same pattern)
DROP POLICY IF EXISTS "Users can view ProductOptions for their organization" ON public."ProductOptions";
CREATE POLICY "Users can view ProductOptions for their organization"
  ON public."ProductOptions" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert ProductOptions for their organization" ON public."ProductOptions";
CREATE POLICY "Users can insert ProductOptions for their organization"
  ON public."ProductOptions" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

DROP POLICY IF EXISTS "Users can update ProductOptions for their organization" ON public."ProductOptions";
CREATE POLICY "Users can update ProductOptions for their organization"
  ON public."ProductOptions" FOR UPDATE
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

-- ProductOptionValues (same pattern)
DROP POLICY IF EXISTS "Users can view ProductOptionValues for their organization" ON public."ProductOptionValues";
CREATE POLICY "Users can view ProductOptionValues for their organization"
  ON public."ProductOptionValues" FOR SELECT
  USING (
    option_id IN (
      SELECT po.id FROM public."ProductOptions" po
      INNER JOIN public."OrganizationUsers" ou ON po.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() AND ou.deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert ProductOptionValues for their organization" ON public."ProductOptionValues";
CREATE POLICY "Users can insert ProductOptionValues for their organization"
  ON public."ProductOptionValues" FOR INSERT
  WITH CHECK (
    option_id IN (
      SELECT po.id FROM public."ProductOptions" po
      INNER JOIN public."OrganizationUsers" ou ON po.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() 
      AND ou.deleted = false
      AND ou.role IN ('owner', 'admin', 'super_admin')
    )
  );

-- ConfiguredProducts (same pattern)
DROP POLICY IF EXISTS "Users can view ConfiguredProducts for their organization" ON public."ConfiguredProducts";
CREATE POLICY "Users can view ConfiguredProducts for their organization"
  ON public."ConfiguredProducts" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert ConfiguredProducts for their organization" ON public."ConfiguredProducts";
CREATE POLICY "Users can insert ConfiguredProducts for their organization"
  ON public."ConfiguredProducts" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin', 'sales')
    )
  );

-- ConfiguredProductOptions (inherits from ConfiguredProducts)
DROP POLICY IF EXISTS "Users can view ConfiguredProductOptions for their organization" ON public."ConfiguredProductOptions";
CREATE POLICY "Users can view ConfiguredProductOptions for their organization"
  ON public."ConfiguredProductOptions" FOR SELECT
  USING (
    configured_product_id IN (
      SELECT cp.id FROM public."ConfiguredProducts" cp
      INNER JOIN public."OrganizationUsers" ou ON cp.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() AND ou.deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert ConfiguredProductOptions for their organization" ON public."ConfiguredProductOptions";
CREATE POLICY "Users can insert ConfiguredProductOptions for their organization"
  ON public."ConfiguredProductOptions" FOR INSERT
  WITH CHECK (
    configured_product_id IN (
      SELECT cp.id FROM public."ConfiguredProducts" cp
      INNER JOIN public."OrganizationUsers" ou ON cp.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() 
      AND ou.deleted = false
      AND ou.role IN ('owner', 'admin', 'super_admin', 'sales')
    )
  );

-- MotorTubeCompatibility (same pattern)
DROP POLICY IF EXISTS "Users can view MotorTubeCompatibility for their organization" ON public."MotorTubeCompatibility";
CREATE POLICY "Users can view MotorTubeCompatibility for their organization"
  ON public."MotorTubeCompatibility" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert MotorTubeCompatibility for their organization" ON public."MotorTubeCompatibility";
CREATE POLICY "Users can insert MotorTubeCompatibility for their organization"
  ON public."MotorTubeCompatibility" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

-- CassettePartsMapping (same pattern)
DROP POLICY IF EXISTS "Users can view CassettePartsMapping for their organization" ON public."CassettePartsMapping";
CREATE POLICY "Users can view CassettePartsMapping for their organization"
  ON public."CassettePartsMapping" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert CassettePartsMapping for their organization" ON public."CassettePartsMapping";
CREATE POLICY "Users can insert CassettePartsMapping for their organization"
  ON public."CassettePartsMapping" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

-- HardwareColorMapping (same pattern)
DROP POLICY IF EXISTS "Users can view HardwareColorMapping for their organization" ON public."HardwareColorMapping";
CREATE POLICY "Users can view HardwareColorMapping for their organization"
  ON public."HardwareColorMapping" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert HardwareColorMapping for their organization" ON public."HardwareColorMapping";
CREATE POLICY "Users can insert HardwareColorMapping for their organization"
  ON public."HardwareColorMapping" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin')
    )
  );

-- BomInstances (same pattern)
DROP POLICY IF EXISTS "Users can view BomInstances for their organization" ON public."BomInstances";
CREATE POLICY "Users can view BomInstances for their organization"
  ON public."BomInstances" FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() AND deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert BomInstances for their organization" ON public."BomInstances";
CREATE POLICY "Users can insert BomInstances for their organization"
  ON public."BomInstances" FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public."OrganizationUsers"
      WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin', 'super_admin', 'sales')
    )
  );

-- BomInstanceLines (inherits from BomInstances)
DROP POLICY IF EXISTS "Users can view BomInstanceLines for their organization" ON public."BomInstanceLines";
CREATE POLICY "Users can view BomInstanceLines for their organization"
  ON public."BomInstanceLines" FOR SELECT
  USING (
    bom_instance_id IN (
      SELECT bi.id FROM public."BomInstances" bi
      INNER JOIN public."OrganizationUsers" ou ON bi.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() AND ou.deleted = false
    )
  );

DROP POLICY IF EXISTS "Users can insert BomInstanceLines for their organization" ON public."BomInstanceLines";
CREATE POLICY "Users can insert BomInstanceLines for their organization"
  ON public."BomInstanceLines" FOR INSERT
  WITH CHECK (
    bom_instance_id IN (
      SELECT bi.id FROM public."BomInstances" bi
      INNER JOIN public."OrganizationUsers" ou ON bi.organization_id = ou.organization_id
      WHERE ou.user_id = auth.uid() 
      AND ou.deleted = false
      AND ou.role IN ('owner', 'admin', 'super_admin', 'sales')
    )
  );

-- ====================================================
-- PART 8: SEED DATA
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_product_absolute_roller_id uuid;
  v_option_operation_type_id uuid;
  v_option_cassette_shape_id uuid;
  v_option_tube_type_id uuid;
  v_option_motor_family_id uuid;
  v_option_bottom_bar_finish_id uuid;
  v_option_drop_type_id uuid;
  v_option_hardware_color_id uuid;
BEGIN
  -- Get first active organization
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE NOTICE '  ⚠️  No active organization found - skipping seed data';
    RETURN;
  END IF;

  RAISE NOTICE '  📦 Seeding data for organization: %', v_org_id;

  -- 1) Create base product: ABSOLUTE_ROLLER
  INSERT INTO public."Products" (
    organization_id,
    code,
    name,
    description,
    active
  )
  VALUES (
    v_org_id,
    'ABSOLUTE_ROLLER',
    'Absolute Roller Shade',
    'Base product for Absolute Roller Shades',
    true
  )
  ON CONFLICT (organization_id, code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    active = EXCLUDED.active
  RETURNING id INTO v_product_absolute_roller_id;

  RAISE NOTICE '    ✅ Created/updated product: ABSOLUTE_ROLLER';

  -- 2) Create ProductOptions
  -- operation_type
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'operation_type',
    'Operation Type',
    'Manual or Motorized operation',
    'select',
    true,
    1
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_operation_type_id;

  -- cassette_shape
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'cassette_shape',
    'Cassette Shape',
    'Cassette shape: None, L, Round, or Square',
    'select',
    false,
    2
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_cassette_shape_id;

  -- tube_type
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'tube_type',
    'Tube Type',
    'Tube type: RTU-38, RTU-42, RTU-50, RTU-65, RTU-80',
    'select',
    true,
    3
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_tube_type_id;

  -- motor_family
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'motor_family',
    'Motor Family',
    'Motor family: CM-05, CM-06, CM-09, CM-10 (only when motor)',
    'select',
    false,
    4
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_motor_family_id;

  -- bottom_bar_finish
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'bottom_bar_finish',
    'Bottom Bar Finish',
    'Bottom bar finish: White, Black, or Wrapped',
    'select',
    false,
    5
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_bottom_bar_finish_id;

  -- drop_type
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'drop_type',
    'Drop Type',
    'Drop type: Standard or L',
    'select',
    false,
    6
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_drop_type_id;

  -- hardware_color
  INSERT INTO public."ProductOptions" (
    organization_id,
    option_code,
    name,
    description,
    input_type,
    is_required,
    sort_order
  )
  VALUES (
    v_org_id,
    'hardware_color',
    'Hardware Color',
    'Hardware color: White, Black, Silver, or Bronze',
    'select',
    false,
    7
  )
  ON CONFLICT (organization_id, option_code) WHERE deleted = false
  DO UPDATE SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description
  RETURNING id INTO v_option_hardware_color_id;

  RAISE NOTICE '    ✅ Created/updated ProductOptions';

  -- 3) Create ProductOptionValues
  -- operation_type values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_operation_type_id, 'manual', 'Manual', 1),
    (v_option_operation_type_id, 'motor', 'Motorized', 2)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- cassette_shape values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_cassette_shape_id, 'none', 'None', 1),
    (v_option_cassette_shape_id, 'L', 'L-Shape', 2),
    (v_option_cassette_shape_id, 'round', 'Round', 3),
    (v_option_cassette_shape_id, 'square', 'Square', 4)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- tube_type values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_tube_type_id, 'RTU-38', 'RTU-38', 1),
    (v_option_tube_type_id, 'RTU-38-2C', 'RTU-38-2C', 2),
    (v_option_tube_type_id, 'RTU-42', 'RTU-42', 3),
    (v_option_tube_type_id, 'RTU-50', 'RTU-50', 4),
    (v_option_tube_type_id, 'RTU-65', 'RTU-65', 5),
    (v_option_tube_type_id, 'RTU-80', 'RTU-80', 6)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- motor_family values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_motor_family_id, 'CM-05', 'CM-05', 1),
    (v_option_motor_family_id, 'CM-06', 'CM-06', 2),
    (v_option_motor_family_id, 'CM-09', 'CM-09', 3),
    (v_option_motor_family_id, 'CM-10', 'CM-10', 4)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- bottom_bar_finish values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_bottom_bar_finish_id, 'white', 'White', 1),
    (v_option_bottom_bar_finish_id, 'black', 'Black', 2),
    (v_option_bottom_bar_finish_id, 'wrapped', 'Wrapped', 3)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- drop_type values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_drop_type_id, 'standard', 'Standard', 1),
    (v_option_drop_type_id, 'L', 'L-Drop', 2)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  -- hardware_color values
  INSERT INTO public."ProductOptionValues" (option_id, value_code, label, sort_order)
  VALUES 
    (v_option_hardware_color_id, 'white', 'White', 1),
    (v_option_hardware_color_id, 'black', 'Black', 2),
    (v_option_hardware_color_id, 'silver', 'Silver', 3),
    (v_option_hardware_color_id, 'bronze', 'Bronze', 4)
  ON CONFLICT (option_id, value_code) WHERE deleted = false
  DO UPDATE SET label = EXCLUDED.label;

  RAISE NOTICE '    ✅ Created/updated ProductOptionValues';

  -- 4) Sample MotorTubeCompatibility (placeholder - you'll need actual CatalogItem IDs)
  -- Example: CM-09 compatible with RTU-65
  INSERT INTO public."MotorTubeCompatibility" (
    organization_id,
    tube_type,
    motor_family,
    notes
  )
  VALUES (
    v_org_id,
    'RTU-65',
    'CM-09',
    'CM-09 motor compatible with RTU-65 tube (example - requires actual part IDs)'
  )
  ON CONFLICT (organization_id, tube_type, motor_family) WHERE deleted = false
  DO NOTHING;

  RAISE NOTICE '    ✅ Created sample MotorTubeCompatibility (placeholder)';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Seed data completed!';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '   1. Populate CatalogItems with actual SKUs (RC4004, RCA-04, etc.)';
  RAISE NOTICE '   2. Create HardwareColorMapping entries (base_part_id -> colored variants)';
  RAISE NOTICE '   3. Create CassettePartsMapping entries (cassette_shape -> parts)';
  RAISE NOTICE '   4. Update MotorTubeCompatibility with actual CatalogItem IDs';
  RAISE NOTICE '   5. Create BOMTemplates and BOMComponents (or use existing)';
  RAISE NOTICE '   6. Update BOMComponents with qty_type, qty_value, select_rule';

END $$;

-- ====================================================
-- PART 9: TRIGGERS (updated_at)
-- ====================================================

-- Create or replace updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to all new tables
CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON public."Products"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_product_options_updated_at
  BEFORE UPDATE ON public."ProductOptions"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_product_option_values_updated_at
  BEFORE UPDATE ON public."ProductOptionValues"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_configured_products_updated_at
  BEFORE UPDATE ON public."ConfiguredProducts"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_configured_product_options_updated_at
  BEFORE UPDATE ON public."ConfiguredProductOptions"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_motor_tube_compatibility_updated_at
  BEFORE UPDATE ON public."MotorTubeCompatibility"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_cassette_parts_mapping_updated_at
  BEFORE UPDATE ON public."CassettePartsMapping"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_hardware_color_mapping_updated_at
  BEFORE UPDATE ON public."HardwareColorMapping"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_bom_instances_updated_at
  BEFORE UPDATE ON public."BomInstances"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_bom_instance_lines_updated_at
  BEFORE UPDATE ON public."BomInstanceLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ====================================================
-- COMPLETION
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Enhanced BOM Architecture migration completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Summary:';
  RAISE NOTICE '   ✅ Created Products table (base product definitions)';
  RAISE NOTICE '   ✅ Created ProductOptions and ProductOptionValues (normalized options)';
  RAISE NOTICE '   ✅ Created ConfiguredProducts and ConfiguredProductOptions (structured configs)';
  RAISE NOTICE '   ✅ Created MotorTubeCompatibility (explicit compatibility rules)';
  RAISE NOTICE '   ✅ Created CassettePartsMapping (cassette shape to parts)';
  RAISE NOTICE '   ✅ Created HardwareColorMapping (color variants)';
  RAISE NOTICE '   ✅ Extended BOMComponents with qty_type, qty_value, select_rule';
  RAISE NOTICE '   ✅ Created BomInstances and BomInstanceLines (traceability)';
  RAISE NOTICE '   ✅ Created indexes and RLS policies';
  RAISE NOTICE '   ✅ Seeded initial option definitions';
  RAISE NOTICE '';
  RAISE NOTICE '🔗 Integration Notes:';
  RAISE NOTICE '   - ConfiguredProducts can link to both Products (new) and ProductTypes (existing)';
  RAISE NOTICE '   - BOMComponents already supports block_condition (JSONB) - use it for conditions';
  RAISE NOTICE '   - BomInstances provide traceability - generate when quote is approved';
  RAISE NOTICE '   - Use HardwareColorMapping to resolve colored parts without duplicating BOMs';
  RAISE NOTICE '';
END $$;

