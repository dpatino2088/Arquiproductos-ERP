# Enhanced BOM Architecture - Integration Guide

## 📋 Overview

This migration extends the existing BOM system with a more structured and traceable architecture. It **does NOT replace** the existing `BOMTemplates` and `BOMComponents` tables - it adds new tables that work alongside them.

## 🎯 Key Benefits

1. **Normalized Options**: `ProductOptions` and `ProductOptionValues` provide a structured way to define and manage product options
2. **Structured Configurations**: `ConfiguredProducts` and `ConfiguredProductOptions` store user selections in a queryable format
3. **Explicit Compatibility Rules**: `MotorTubeCompatibility`, `CassettePartsMapping`, and `HardwareColorMapping` make rules explicit and maintainable
4. **Traceability**: `BomInstances` and `BomInstanceLines` provide full traceability of how a BOM was generated

## 🔄 UI to Database Mapping

### Step 1: User Selects Options in Configurator

When a user configures a product in the UI (`ProductConfigurator.tsx`), they select:
- `product_base`: "ABSOLUTE_ROLLER"
- `operation_type`: "manual" | "motor"
- `cassette_shape`: "none" | "L" | "round" | "square"
- `tube_type`: "RTU-38" | "RTU-42" | "RTU-50" | "RTU-65" | "RTU-80"
- `motor_family`: "CM-05" | "CM-06" | "CM-09" | "CM-10" (if motor)
- `bottom_bar_finish`: "white" | "black" | "wrapped"
- `drop_type`: "standard" | "L"
- `hardware_color`: "white" | "black" | "silver" | "bronze"
- `fabric`: collection + variant
- `measures`: width_mm, height_mm, qty

### Step 2: Save to ConfiguredProducts + ConfiguredProductOptions

When the user completes the configuration and adds to quote:

```sql
-- 1) Create ConfiguredProduct
INSERT INTO "ConfiguredProducts" (
  organization_id,
  product_id,              -- FK to Products (ABSOLUTE_ROLLER)
  product_type_id,         -- FK to ProductTypes (for compatibility)
  quote_line_id,           -- FK to QuoteLines
  width_mm,
  height_mm,
  qty,
  fabric_catalog_item_id
)
VALUES (...);

-- 2) Insert selected options
INSERT INTO "ConfiguredProductOptions" (configured_product_id, option_code, option_value)
VALUES
  (configured_product_id, 'operation_type', 'motor'),
  (configured_product_id, 'cassette_shape', 'L'),
  (configured_product_id, 'tube_type', 'RTU-65'),
  (configured_product_id, 'motor_family', 'CM-09'),
  (configured_product_id, 'bottom_bar_finish', 'white'),
  (configured_product_id, 'hardware_color', 'white');
```

### Step 3: Generate BOM from Template

Use existing `generate_configured_bom_for_quote_line()` function, but enhance it to:

1. **Read from ConfiguredProductOptions** instead of parsing JSONB
2. **Apply Compatibility Rules**:
   - Check `MotorTubeCompatibility` for motor/tube combinations
   - Check `CassettePartsMapping` for cassette parts
   - Check `HardwareColorMapping` for colored parts
3. **Resolve SKUs** based on:
   - `BOMComponents.block_condition` (matches ConfiguredProductOptions)
   - `BOMComponents.select_rule` (by_option, by_mapping, etc.)
   - `BOMComponents.qty_type` (fixed, per_width, per_area, by_option)

### Step 4: Create BomInstance for Traceability

When quote is approved or sent to production:

```sql
-- 1) Create BomInstance
INSERT INTO "BomInstances" (
  organization_id,
  configured_product_id,
  bom_template_id,
  status
)
VALUES (..., 'locked');

-- 2) Insert resolved lines
INSERT INTO "BomInstanceLines" (
  bom_instance_id,
  source_template_line_id,    -- FK to BOMComponents (optional)
  resolved_part_id,           -- FK to CatalogItems
  resolved_sku,               -- Cached SKU
  part_role,                  -- 'tube', 'bracket_left', 'motor', etc.
  qty,
  uom,
  rule_applied,               -- "Selected by motor_family=CM-09"
  inputs_snapshot              -- {"width_m": 2.5, "motor_family": "CM-09"}
)
SELECT ...;
```

## 🔧 BOM Template Line Selection Logic

### Example: Manual System BOM Lines

```sql
-- Base lines (always included)
INSERT INTO "BOMComponents" (
  bom_template_id,
  block_type,
  block_condition,        -- NULL = always active
  component_role,
  component_item_id,      -- e.g., RC4004 (bracket)
  qty_type,               -- 'fixed'
  qty_value,              -- 2
  uom,
  applies_color,          -- true
  hardware_color          -- 'white' (one row per color)
);

-- Manual-specific lines (conditional)
INSERT INTO "BOMComponents" (
  bom_template_id,
  block_type,
  block_condition,        -- {"operation_type": "manual"}
  component_role,
  component_item_id,      -- e.g., RC4001 (clutch set)
  qty_type,               -- 'by_option' or 'fixed'
  select_rule,            -- {"type": "by_option", "option_code": "tube_type", "mapping": {...}}
  uom
);

-- Motor-specific lines (conditional)
INSERT INTO "BOMComponents" (
  bom_template_id,
  block_type,
  block_condition,        -- {"operation_type": "motor"}
  component_role,
  component_item_id,      -- NULL (resolved by rule)
  qty_type,               -- 'by_option'
  select_rule,            -- {"type": "by_compatibility", "table": "MotorTubeCompatibility", "tube_option": "tube_type", "motor_option": "motor_family"}
  uom
);
```

### Example: Cassette Parts

```sql
-- Cassette profile (conditional)
INSERT INTO "BOMComponents" (
  bom_template_id,
  block_type,
  block_condition,        -- {"cassette_shape": {"$ne": "none"}}
  component_role,
  component_item_id,      -- NULL (resolved by CassettePartsMapping)
  qty_type,               -- 'per_width'
  qty_value,              -- 1.0
  select_rule,            -- {"type": "by_mapping", "table": "CassettePartsMapping", "shape_option": "cassette_shape", "role": "profile"}
  uom                     -- 'm'
);
```

## 🎨 Hardware Color Resolution

Instead of duplicating BOM templates by color, use `HardwareColorMapping`:

```sql
-- Base part (no color)
INSERT INTO "CatalogItems" (sku, name, ...) VALUES ('RC4004', 'Bracket Base', ...);

-- Colored variants
INSERT INTO "CatalogItems" (sku, name, ...) VALUES ('RC4004-WH', 'Bracket White', ...);
INSERT INTO "CatalogItems" (sku, name, ...) VALUES ('RC4004-BK', 'Bracket Black', ...);

-- Mapping
INSERT INTO "HardwareColorMapping" (base_part_id, hardware_color, mapped_part_id)
SELECT 
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004'),
  'white',
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004-WH')
UNION ALL
SELECT 
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004'),
  'black',
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004-BK');
```

In BOM generation:
1. Check if component has `applies_color = true`
2. Get `hardware_color` from `ConfiguredProductOptions`
3. Look up `HardwareColorMapping` to get `mapped_part_id`
4. Use mapped part instead of base part

## 📊 Example: Complete Flow

### 1. User Configuration
- Product: ABSOLUTE_ROLLER
- Operation: Motor
- Tube: RTU-65
- Motor: CM-09
- Cassette: L-Shape
- Hardware Color: White
- Width: 2.5m, Height: 2.0m, Qty: 1

### 2. Save Configuration
```sql
-- ConfiguredProduct
INSERT INTO "ConfiguredProducts" (...) VALUES (...);

-- ConfiguredProductOptions
INSERT INTO "ConfiguredProductOptions" VALUES
  (cp_id, 'operation_type', 'motor'),
  (cp_id, 'tube_type', 'RTU-65'),
  (cp_id, 'motor_family', 'CM-09'),
  (cp_id, 'cassette_shape', 'L'),
  (cp_id, 'hardware_color', 'white');
```

### 3. Generate BOM
1. Find `BOMTemplate` for ABSOLUTE_ROLLER
2. Filter `BOMComponents` by `block_condition`:
   - `{"operation_type": "motor"}` ✅
   - `{"cassette_shape": {"$ne": "none"}}` ✅
3. For each component:
   - If `applies_color = true`: Look up `HardwareColorMapping` (white → RC4004-WH)
   - If `select_rule.type = "by_compatibility"`: Look up `MotorTubeCompatibility` (RTU-65 + CM-09 → crown part)
   - If `select_rule.type = "by_mapping"`: Look up `CassettePartsMapping` (L + profile → part)
   - Calculate qty: `fixed` = qty_value, `per_width` = width_m * qty_value, `per_area` = width_m * height_m * qty_value
4. Insert into `QuoteLineComponents` (existing table)

### 4. Generate BomInstance (when approved)
```sql
-- Create instance
INSERT INTO "BomInstances" (..., status = 'locked');

-- Insert resolved lines
INSERT INTO "BomInstanceLines" (
  bom_instance_id,
  resolved_part_id,
  resolved_sku,
  part_role,
  qty,
  rule_applied,
  inputs_snapshot
)
SELECT 
  bi_id,
  qlc.catalog_item_id,
  ci.sku,
  qlc.component_role,
  qlc.qty,
  'Selected by motor_family=CM-09 via MotorTubeCompatibility',
  jsonb_build_object('width_m', 2.5, 'motor_family', 'CM-09', 'tube_type', 'RTU-65')
FROM "QuoteLineComponents" qlc
JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
WHERE qlc.quote_line_id = ...;
```

## 🔗 Integration with Existing System

### Compatibility Layer

The new system works alongside the existing system:

1. **ConfiguredProducts** can link to both:
   - `Products` (new system) via `product_id`
   - `ProductTypes` (existing system) via `product_type_id`

2. **BOM Generation** can use:
   - Existing `BOMTemplates` and `BOMComponents` (with new columns: `qty_type`, `qty_value`, `select_rule`)
   - New compatibility tables for rule resolution

3. **Traceability** is optional:
   - Generate `BomInstances` when quote is approved
   - Or continue using `QuoteLineComponents` only

### Migration Path

1. **Phase 1** (Current): Use existing `BOMTemplates`/`BOMComponents` with new columns
2. **Phase 2**: Populate `Products`, `ProductOptions`, `ConfiguredProducts`
3. **Phase 3**: Populate compatibility tables (`MotorTubeCompatibility`, etc.)
4. **Phase 4**: Update BOM generation function to use new tables
5. **Phase 5**: Generate `BomInstances` for traceability

## ✅ Benefits Summary

- ✅ **No duplication**: One BOM template per product, not per RC code
- ✅ **Explicit rules**: Compatibility rules are in tables, not hardcoded
- ✅ **Color mapping**: Hardware colors don't duplicate BOMs
- ✅ **Traceability**: Full audit trail of how BOMs were generated
- ✅ **Scalable**: Easy to add new options, products, rules
- ✅ **Queryable**: Can query "all configurations with CM-09 motor"
- ✅ **Backward compatible**: Works with existing `BOMTemplates`/`BOMComponents`

