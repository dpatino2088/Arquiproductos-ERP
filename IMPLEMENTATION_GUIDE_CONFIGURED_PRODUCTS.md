# Implementation Guide: ConfiguredProducts & BOM Preview

## 📋 Overview

This implementation adds a **preview/snapshot architecture** that resolves Fabric + BOM **before** QuoteLine creation, using `ConfiguredProducts` table and reusable `BOMInstances` for previews.

## 🎯 Architecture

```
ProductConfigurator (UI)
    ↓
create_configured_product_and_bom_preview() RPC
    ├── Resolves BOM template (exact SKU matching)
    ├── Creates ConfiguredProduct (snapshot)
    ├── Generates BOMInstance (preview, configured_product_id)
    ├── Calculates totals (fabric + bom)
    └── Returns configured_product_id + totals
    ↓
QuoteLine (when user confirms)
    ├── Uses ConfiguredProduct totals
    └── Stores configured_product_id in metadata
```

## 📁 Files Created/Modified

### New Files:
1. **`database/migrations/20260121_create_configured_products_and_bom_preview.sql`**
   - Creates `ConfiguredProducts` table
   - Modifies `BOMInstances` to support `configured_product_id` (XOR with `quote_line_id`)
   - Creates RPC functions
   - Adds RLS policies

2. **`src/types/configured-product.ts`**
   - TypeScript interfaces for ConfiguredProduct

3. **`src/lib/bom/createConfiguredProductPreview.ts`**
   - Helper function to call RPC

### Modified Files:
1. **`src/pages/sales/ProductConfigurator.tsx`**
   - Creates ConfiguredProduct preview before calling `onComplete`

2. **`src/pages/sales/QuoteNew.tsx`**
   - Uses ConfiguredProduct totals when `configured_product_id` exists

## 🔧 SQL Migration Details

### ConfiguredProducts Table
- Stores full config snapshot in `config_snapshot` JSONB
- Stores calculated totals: `fabric_msrp_total`, `bom_total`, `fabric_plus_bom_total`, `total_msrp`
- Links to `quote_id` (nullable, set after QuoteLine creation)

### BOMInstances Changes
- `quote_line_id` is now **NULLABLE**
- New `configured_product_id` column (nullable)
- XOR constraint: exactly one of (`quote_line_id`, `configured_product_id`) must be not null
- Supports both use cases:
  - Preview: `configured_product_id` only
  - Production: `quote_line_id` only (existing flow)

## 🚀 Functions Created

### 1. `select_best_bom_template_for_configured_product(org_id, product_type_id, config_snapshot)`
- Reuses exact SKU matching logic
- Works with JSONB config instead of QuoteLineComponents

### 2. `generate_bom_from_slots_for_configured_product(org_id, configured_product_id, product_type_id)`
- Generates BOMInstance for preview
- Reads selections from `config_snapshot` JSONB
- Handles mounting_clip rules (per_width)

### 3. `calculate_configured_product_totals(configured_product_id)`
- Calculates fabric_msrp_total (from CatalogItemsMSRP)
- Calculates bom_total (sums all BOMInstanceLines MSRP sale_out)
- Updates ConfiguredProduct with totals

### 4. `create_configured_product_and_bom_preview(org_id, product_type_id, config_snapshot, quote_id)`
- Main RPC function
- Atomic operation: creates ConfiguredProduct → generates BOM → calculates totals
- Returns IDs and totals

## 🔐 RLS Policies

### ConfiguredProducts
- SELECT/INSERT/UPDATE: Only active org members

### BOMInstances (updated)
- Existing policies for `quote_line_id` unchanged
- New policy for `configured_product_id`: validates access via ConfiguredProduct.organization_id

## 💻 TypeScript Changes

### ProductConfigurator.tsx
**Location:** `src/pages/sales/ProductConfigurator.tsx`
**Changes:**
- Line ~15: Added imports for `createConfiguredProductPreview` and `useOrganizationContext`
- Line ~36: Added `activeOrganizationId` from context
- Lines ~633-666: Modified `handleComplete` to create ConfiguredProduct preview before calling `onComplete`

**What it does:**
1. After validation, creates ConfiguredProduct using RPC
2. Adds `configured_product_id` and `configured_product_totals` to config
3. Passes enriched config to `onComplete`
4. Falls back to legacy flow if preview creation fails

### QuoteNew.tsx
**Location:** `src/pages/sales/QuoteNew.tsx`
**Changes:**
- Lines ~785-810: Check for `configured_product_id` and use totals from ConfiguredProduct
- Lines ~1790-1803: Use ConfiguredProduct totals when available instead of recalculating

**What it does:**
1. Checks if config has `configured_product_id`
2. If yes, uses totals from ConfiguredProduct (already calculated)
3. If no, uses legacy calculation flow
4. Still generates BOMInstance for QuoteLine (separate from preview)

## 🧪 Test Plan

### Test 1: Create ConfiguredProduct Preview
**Steps:**
1. Open ProductConfigurator
2. Select ProductType: `roller-shade`
3. Select Hardware Color: `White`
4. Enter measurements: Width 1000mm, Height 2000mm
5. Select Fabric variant
6. Select Bottom Bar SKU
7. Select Headbox (or None)
8. Select Operating Type: `motor`
9. Select Motor SKU
10. Select Tube SKU
11. Click "Complete"

**Expected:**
- ConfiguredProduct created with `config_snapshot`
- BOMInstance created with `configured_product_id` (not `quote_line_id`)
- BOMInstanceLines generated (parents + children)
- Totals calculated and stored in ConfiguredProduct
- `configured_product_id` passed to QuoteNew

**Verify in DB:**
```sql
SELECT * FROM "ConfiguredProducts" WHERE deleted = false ORDER BY created_at DESC LIMIT 1;
SELECT * FROM "BomInstances" WHERE configured_product_id = '<id>' AND deleted = false;
SELECT * FROM "BomInstanceLines" WHERE bom_instance_id = '<bom_instance_id>' AND deleted = false;
```

### Test 2: Use ConfiguredProduct Totals in QuoteLine
**Steps:**
1. After Test 1, confirm QuoteLine creation
2. Verify QuoteLine is created with correct pricing

**Expected:**
- QuoteLine created with `msrp` = total from ConfiguredProduct
- QuoteLine `metadata` contains `configured_product_id`
- BOMInstance for QuoteLine also created (separate from preview)

**Verify in DB:**
```sql
SELECT id, msrp, metadata FROM "QuoteLines" WHERE id = '<quote_line_id>';
SELECT * FROM "BomInstances" WHERE quote_line_id = '<quote_line_id>' AND deleted = false;
```

### Test 3: BOM Template Matching (SKU Exact Match)
**Steps:**
1. Create config with specific Bottom Bar SKU
2. Verify only 1 BOM template matches

**Expected:**
- Only templates with exact SKU match are selected
- Matching logic: ProductType → Color → SKU exact match (bottom_bar, headbox, motor, drive, tube)

### Test 4: Child Components in BOM
**Steps:**
1. Create ConfiguredProduct with motor that has children (adapter, end_cap)
2. Check BOMInstanceLines

**Expected:**
- Parent components in BOMInstanceLines
- Child components also in BOMInstanceLines (from CatalogItemComponents)
- BOM total includes both parents and children MSRP sale_out

### Test 5: mounting_clip Rule (per_width)
**Steps:**
1. Create config with headbox that triggers mounting_clip rule
2. Check BOMInstanceLines for mounting_clip

**Expected:**
- mounting_clip quantity = ceil(width_m * qty_value) with minimum 2
- UOM = 'ea'
- Correct qty calculation based on BOMComponents rule

### Test 6: Legacy Flow (No ConfiguredProduct)
**Steps:**
1. Create QuoteLine without ConfiguredProduct (simulate old flow)
2. Verify it still works

**Expected:**
- Legacy calculation flow still works
- BOMInstance created with `quote_line_id` only
- No errors

### Test 7: RLS Permissions
**Steps:**
1. Try to access ConfiguredProduct from different organization
2. Verify access denied

**Expected:**
- RLS policies block cross-org access
- Only org members can create/view ConfiguredProducts

### Test 8: Fabric + BOM Total Calculation
**Steps:**
1. Create ConfiguredProduct with fabric and BOM
2. Verify totals in ConfiguredProduct

**Expected:**
- `fabric_msrp_total` = width_m × height_m × msrp_sale_out × quantity
- `bom_total` = sum of all BOMInstanceLines (MSRP sale_out × qty)
- `fabric_plus_bom_total` = fabric_msrp_total + bom_total
- `total_msrp` = (fabric_plus_bom_total × (1 + labor_pct)) + accessories_total

## ✅ Validation Checklist

- [ ] ConfiguredProducts table created
- [ ] BOMInstances.quote_line_id is nullable
- [ ] BOMInstances.configured_product_id added
- [ ] XOR constraint working
- [ ] RPC functions created and working
- [ ] RLS policies applied
- [ ] ProductConfigurator creates ConfiguredProduct
- [ ] QuoteNew uses ConfiguredProduct totals
- [ ] Legacy flow still works
- [ ] mounting_clip rules applied correctly
- [ ] Child components included in BOM total
- [ ] SKU matching works correctly

## 📝 Notes

- **No breaking changes**: Legacy flow still works
- **Backward compatible**: QuoteLines without ConfiguredProduct still work
- **Immutable pricing**: ConfiguredProduct totals are snapshot, not recalculated on QuoteLine
- **Preview vs Production**: BOMInstances can exist for preview (`configured_product_id`) or production (`quote_line_id`)
