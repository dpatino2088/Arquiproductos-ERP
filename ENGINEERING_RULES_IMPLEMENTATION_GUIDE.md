# Engineering Rules + BOM Calculation Implementation Guide

## 📋 Overview

This implementation adds a scalable dimensional adjustment engine using `EngineeringRules` table to adjust linear parts (tubes/cassettes/rails) and fabric (WxH) based on unit components (brackets, drives, endcaps, etc.).

## 🚀 Execution Order

Execute these SQL scripts in Supabase SQL Editor **in this exact order**:

### Step 1: Inspect Schema
```sql
-- Run: INSPECT_SCHEMA_FOR_ENGINEERING_RULES.sql
-- This will show you the current table structures
-- Review the output to understand existing columns
```

### Step 2: Create EngineeringRules Table
```sql
-- Run: CREATE_ENGINEERING_RULES_TABLE.sql
-- Creates EngineeringRules table with all required columns
-- Adds indexes and RLS policies
```

### Step 3: Create Adjustment Resolution Function
```sql
-- Run: CREATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_FUNCTION.sql
-- Creates public.resolve_dimensional_adjustments() function
-- This function calculates total adjustments in mm
```

### Step 4: Add Dimension Columns to BomInstanceLines
```sql
-- Run: UPDATE_BOM_GENERATION_WITH_ADJUSTMENTS.sql (first part only)
-- OR run this manually:
ALTER TABLE "BomInstanceLines" 
ADD COLUMN IF NOT EXISTS cut_length_mm integer,
ADD COLUMN IF NOT EXISTS cut_width_mm integer,
ADD COLUMN IF NOT EXISTS cut_height_mm integer,
ADD COLUMN IF NOT EXISTS calc_notes text;
```

### Step 5: Integrate Adjustments into BOM Generation
```sql
-- Run: INTEGRATE_ENGINEERING_RULES_INTO_BOM.sql
-- Updates generate_bom_for_manufacturing_order() to:
-- - Keep existing BOM generation logic
-- - Apply dimensional adjustments
-- - Update MO status to PLANNED when BOM is valid
```

## 📊 Schema Changes

### New Table: EngineeringRules
- `organization_id` (uuid, NOT NULL)
- `product_type_id` (uuid, NOT NULL)
- `source_component_id` (uuid, NOT NULL, FK to CatalogItems)
- `target_role` (text, NOT NULL) - e.g., 'tube', 'fabric', 'side_channel'
- `dimension` (text, NOT NULL) - 'WIDTH', 'HEIGHT', 'LENGTH'
- `operation` (text, NOT NULL) - 'ADD', 'SUBTRACT'
- `value_mm` (integer, NOT NULL, default 0)
- `per_unit` (boolean, NOT NULL, default true)
- `multiplier` (numeric, NOT NULL, default 1)
- `active` (boolean, NOT NULL, default true)
- `deleted` (boolean, NOT NULL, default false)
- Timestamps

### New Columns in BomInstanceLines
- `cut_length_mm` (integer, nullable)
- `cut_width_mm` (integer, nullable)
- `cut_height_mm` (integer, nullable)
- `calc_notes` (text, nullable)

## 🔧 Functions

### 1. `resolve_dimensional_adjustments(uuid, uuid, uuid, text, text)`
**Purpose:** Calculates total adjustment in mm for a given quote line, product type, target role, and dimension.

**Parameters:**
- `p_organization_id` - Organization ID
- `p_product_type_id` - Product Type ID
- `p_quote_line_id` - Quote Line ID
- `p_target_role` - Target role (e.g., 'tube', 'fabric')
- `p_dimension` - Dimension ('WIDTH', 'HEIGHT', 'LENGTH')

**Returns:** Integer (mm, can be negative for SUBTRACT)

**Logic:**
1. Reads all `QuoteLineComponents` for the quote line
2. Matches against `EngineeringRules` where:
   - Same organization_id
   - Same product_type_id
   - Same source_component_id
   - Same target_role + dimension
   - active=true and deleted=false
3. Computes: `sum(operation_sign * value_mm * (qty if per_unit else 1) * multiplier)`

### 2. `generate_bom_for_manufacturing_order(uuid)` (Updated)
**Purpose:** Generates BOM and applies dimensional adjustments.

**New Behavior:**
1. Copies `QuoteLineComponents` to `BomInstanceLines` (existing logic)
2. **NEW:** For each line, applies adjustments:
   - Linear parts: Calculates `cut_length_mm` and `cut_width_mm`
   - Fabric: Calculates `cut_width_mm` and `cut_height_mm`
3. **NEW:** Updates MO status to `PLANNED` if BOM has lines > 0

## 🎨 Frontend Changes

### SummaryTab.tsx
- ✅ Improved error handling (no false red alerts)
- ✅ Loading state during BOM generation
- ✅ Status label: "Material Review" for DRAFT status
- ✅ Automatic status update after BOM generation

## 📝 EngineeringRules Usage Example

```sql
-- Example: Add 50mm to tube length for each bracket
INSERT INTO "EngineeringRules" (
    organization_id,
    product_type_id,
    source_component_id,  -- ID of bracket component
    target_role,           -- 'tube'
    dimension,             -- 'LENGTH'
    operation,             -- 'ADD'
    value_mm,              -- 50
    per_unit,              -- true (multiply by qty)
    multiplier,            -- 1
    active
) VALUES (
    'your-org-id',
    'your-product-type-id',
    'bracket-catalog-item-id',
    'tube',
    'LENGTH',
    'ADD',
    50,
    true,
    1,
    true
);
```

## ✅ QA Checklist

- [ ] Create MO → status is DRAFT
- [ ] Click "Generate BOM" → no red error flash; button shows loading
- [ ] After success:
  - [ ] BomInstances created per SalesOrderLine
  - [ ] BomInstanceLines populated from QuoteLineComponents
  - [ ] Dimensional adjustments applied on relevant lines (check `cut_length_mm`, `cut_width_mm`, `cut_height_mm`)
  - [ ] MO status flips to PLANNED ONLY when BOM is valid
- [ ] Re-running "Generate BOM" is idempotent (rebuilds lines cleanly)
- [ ] Status label shows "Material Review" for DRAFT status

## 🔍 Verification Queries

```sql
-- Check EngineeringRules
SELECT * FROM "EngineeringRules" 
WHERE organization_id = 'your-org-id' 
AND active = true 
AND deleted = false;

-- Check BOM with adjustments
SELECT 
    bil.id,
    bil.resolved_sku,
    bil.part_role,
    bil.cut_length_mm,
    bil.cut_width_mm,
    bil.cut_height_mm,
    bil.calc_notes
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.sale_order_line_id IN (
    SELECT id FROM "SalesOrderLines" 
    WHERE sale_order_id = 'your-so-id'
)
AND bil.deleted = false;

-- Verify MO status after BOM generation
SELECT 
    mo.manufacturing_order_no,
    mo.status,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = mo.sale_order_id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE mo.id = 'your-mo-id'
GROUP BY mo.manufacturing_order_no, mo.status;
```

## ⚠️ Important Notes

1. **Non-breaking:** All changes are additive. Existing BOM generation continues to work.
2. **Idempotent:** Re-running BOM generation is safe (deletes and recreates lines).
3. **Multi-tenant:** All queries filter by `organization_id`.
4. **Status Logic:** MO status only changes to PLANNED when BOM has lines > 0.
5. **Adjustments are optional:** If no EngineeringRules exist, BOM generation works normally (just no adjustments).

## 🐛 Troubleshooting

### BOM not generating
- Check that `QuoteLineComponents` exist for the QuoteLine
- Verify `source = 'configured_component'` in QuoteLineComponents
- Check logs for RAISE NOTICE messages

### Adjustments not applying
- Verify EngineeringRules exist for the product_type_id
- Check that `active = true` and `deleted = false`
- Verify `target_role` and `dimension` match the component
- Check `calc_notes` field in BomInstanceLines for adjustment details

### MO status not changing to PLANNED
- Verify BomInstanceLines were created (count > 0)
- Check that MO status was 'draft' before BOM generation
- Review function logs for warnings






