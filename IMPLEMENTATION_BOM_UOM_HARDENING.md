# 🔒 BOM UOM Hardening Implementation

## Overview

This implementation hardens BOM UOM handling to ensure consistent and predictable outputs for Manufacturing Orders and cutting lists. All changes respect the critical safety constraint: **DO NOT modify existing locked/frozen BOM snapshots**.

## Critical Safety Rules

✅ **Allowed Changes:**
- Backfill of `base_pricing_fields` in existing `BomInstanceLines` (via `populate_bom_line_base_pricing_fields`)
- New BOM generation (canonical UOM mapping)
- `CatalogItems` validation and data correction

❌ **Forbidden Changes:**
- Modifying `qty`, `role`, `uom`, `parts` in existing `BomInstanceLines`
- Changing frozen snapshots

## Files Created

### 1. Database Migrations

#### `database/migrations/188_bom_uom_validation_and_cost_uom.sql`
**Purpose:** Core UOM validation and cost_uom handling

**Contents:**
- ✅ UOM enum (`uom_code`) - if not exists
- ✅ `cost_uom` column in `CatalogItems` (with backfill)
- ✅ `validate_uom_measure_basis()` function (strict validation)
- ✅ CHECK constraint on `CatalogItems` (deferrable)
- ✅ Enhanced `get_unit_cost_in_uom()` (uses `cost_uom`, not display `uom`)
- ✅ `get_fabric_unit_cost_in_target_uom()` (fabric-specific conversions)
- ✅ Updated `normalize_uom_to_canonical()` (preserves `m2`)
- ✅ Diagnostic functions:
  - `diagnostic_invalid_uom_measure_basis()`
  - `diagnostic_bom_uom_summary()`
  - `diagnostic_quote_vs_bom_lines()`

**Key Features:**
- Uses `cost_uom` (not display `uom`) for cost conversions
- Supports `m`, `ft`, `yd` conversions (1 m = 3.28084 ft, 1 yd = 0.9144 m)
- Fabric conversions use `roll_width_m`
- Returns original cost with notice if conversion unavailable (doesn't crash)

#### `database/migrations/189_fix_bom_backfill_format_error.sql`
**Purpose:** Fix format() error in backfill function

**Contents:**
- ✅ Fixed `populate_bom_line_base_pricing_fields()` format() error
- ✅ Numerics converted to text before `format()`
- ✅ Ensures helper functions exist (`calculate_fabric_pricing_qty`, `get_unit_cost_in_pricing_uom`)

**Fix Details:**
```sql
-- BEFORE (error):
format('Base=%s %s', v_qty_base, v_uom_base)

-- AFTER (fixed):
format('Base=%s %s', ROUND(v_qty_base, 4)::text, v_uom_base)
```

### 2. Data Correction Scripts

#### `scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql`
**Purpose:** Fix critical invalid UOM/measure_basis pairs

**What it does:**
- Fixes items with `measure_basis=linear_m` but `uom=PCS/EA` (invalid)
- Changes `uom` to `'m'` for these items
- Includes preview and verification queries

**Status:** ✅ **CRITICAL - Execute this**

#### `scripts/NORMALIZE_FT_TO_M_FOR_LINEAR_ITEMS.sql`
**Purpose:** Optional normalization for consistency

**What it does:**
- Analyzes items with `measure_basis=linear_m` and `uom=FT`
- Provides two options:
  - **Option A:** Simple UOM change (if `cost_exw` is per meter)
  - **Option B:** UOM change + cost conversion (if `cost_exw` is per foot)
- Includes preview and verification

**Status:** ⚠️ **OPTIONAL - Only execute after confirming cost UOM**

## Canonical UOM Rules

### For BOM Outputs (Manufacturing Orders / Cutting Lists)

| measure_basis | Canonical UOM | Notes |
|--------------|---------------|-------|
| `linear_m` | `'m'` | Meters (normalized from ft, yd) |
| `area` / `fabric` | `'m2'` | Square meters (base for fabric) |
| `unit` | `'ea'` | Each (normalized from pcs, set) |

**Key Point:** BOM generation must use canonical mapping, NOT `CatalogItems.uom` directly.

### For CatalogItems Validation

| measure_basis | Allowed UOM | Notes |
|--------------|-------------|-------|
| `linear_m` | `m`, `ft`, `yd` | Length units |
| `area` | `m2` | Area units only |
| `unit` | `ea`, `pcs`, `set` | Count units |
| `fabric` | `m2`, `m`, `yd`, `roll` | Base is `m2`, pricing can vary |

## Cost Conversion Logic

### Source: `cost_uom` (NOT display `uom`)

1. **Get cost from `CatalogItems`:**
   - `cost_exw` + `cost_uom` (if `cost_uom` is NULL, use `uom`)

2. **Convert to target UOM:**
   - `m` ↔ `ft`: 1 m = 3.28084 ft
   - `m` ↔ `yd`: 1 yd = 0.9144 m
   - `ft` ↔ `yd`: 1 yd = 3 ft

3. **Fabric conversions:**
   - Requires `roll_width_m > 0`
   - `m2` ↔ `m`: `cost_per_m = cost_per_m2 * roll_width_m`
   - `m2` ↔ `yd`: `cost_per_yd = (cost_per_m2 * roll_width_m) * 0.9144`

4. **Fallback:**
   - If conversion unavailable: return original `cost_exw` with `RAISE NOTICE` (doesn't crash)

## Execution Order

### Step 1: Run Migration 188
```sql
\i database/migrations/188_bom_uom_validation_and_cost_uom.sql
```

**Expected Output:**
- ✅ Enum created
- ✅ `cost_uom` column added and backfilled
- ✅ Validation function created
- ✅ Constraint added (may warn if invalid data exists)
- ✅ Cost conversion functions updated
- ✅ Diagnostic functions created

### Step 2: Check for Invalid Data
```sql
SELECT * FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;
```

**Expected:** Should show items with `linear_m`/`PCS` (7 items from CSV analysis)

### Step 3: Fix Invalid Data
```sql
\i scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql
```

**Expected Output:**
- ✅ 7 items fixed (PCS → m)
- ✅ 0 remaining invalid pairs

### Step 4: Run Migration 189
```sql
\i database/migrations/189_fix_bom_backfill_format_error.sql
```

**Expected Output:**
- ✅ `populate_bom_line_base_pricing_fields()` fixed
- ✅ Helper functions ensured

### Step 5: Re-run Backfill
```sql
SELECT * FROM backfill_bom_lines_base_pricing();
```

**Expected Output:**
- ✅ All lines updated successfully
- ✅ No format() errors

### Step 6: Verify Results
```sql
-- Check backfill success
SELECT 
    COUNT(*) FILTER (WHERE updated = true) as success_count,
    COUNT(*) FILTER (WHERE updated = false) as error_count
FROM backfill_bom_lines_base_pricing();

-- Check invalid items
SELECT COUNT(*) 
FROM diagnostic_invalid_uom_measure_basis() 
WHERE is_valid = false;

-- Check BOM UOM distribution
SELECT * FROM diagnostic_bom_uom_summary();
```

**Expected:**
- ✅ `success_count` = total lines
- ✅ `error_count` = 0
- ✅ Invalid items = 0
- ✅ BOM UOMs are canonical (`m`, `m2`, `ea`)

### Step 7: (Optional) Normalize FT to M
```sql
-- First, review the analysis
\i scripts/NORMALIZE_FT_TO_M_FOR_LINEAR_ITEMS.sql

-- Then, if confirmed, uncomment Option A or B in the script
```

## Validation Rules

### `validate_uom_measure_basis(measure_basis, uom)`

**Returns:** `boolean` (true = valid, false = invalid)

**Rules:**
- `linear_m` → `['m', 'ft', 'yd']`
- `area` → `['m2']`
- `unit` → `['ea', 'pcs', 'set']`
- `fabric` → `['m2', 'm', 'yd', 'roll']`
- Unknown `measure_basis` → `false` (strict)

**Enforcement:**
- CHECK constraint on `CatalogItems` (deferrable)
- Can be disabled if legacy data needs fixing first

## Diagnostic Functions

### 1. `diagnostic_invalid_uom_measure_basis()`
**Returns:** All `CatalogItems` with invalid UOM/measure_basis pairs

**Usage:**
```sql
SELECT * FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;
```

### 2. `diagnostic_bom_uom_summary()`
**Returns:** Summary of `BomInstanceLines` by `category_code` and UOM

**Usage:**
```sql
SELECT * FROM diagnostic_bom_uom_summary();
```

### 3. `diagnostic_quote_vs_bom_lines(quote_line_id)`
**Returns:** Comparison of `QuoteLineComponents` vs `BomInstanceLines`

**Usage:**
```sql
SELECT * FROM diagnostic_quote_vs_bom_lines('your-quote-line-id');
```

## Testing Checklist

- [ ] Migration 188 runs without errors
- [ ] `cost_uom` column exists and is backfilled
- [ ] `validate_uom_measure_basis()` returns correct results
- [ ] Invalid items identified (7 items with `linear_m`/`PCS`)
- [ ] `FIX_INVALID_UOM_MEASURE_BASIS.sql` fixes all invalid items
- [ ] Migration 189 runs without errors
- [ ] Backfill runs without format() errors
- [ ] All `BomInstanceLines` have `qty_base`, `uom_base`, `qty_pricing`, `uom_pricing`
- [ ] BOM UOMs are canonical (`m`, `m2`, `ea`)
- [ ] Cost conversions work correctly (test with sample items)
- [ ] Fabric conversions work correctly (test with fabric items)

## Notes

1. **Backward Compatibility:**
   - Existing `BomInstanceLines` are NOT modified (only backfill of new fields)
   - `CatalogItems` validation is strict but can be disabled if needed
   - Cost conversions fall back gracefully

2. **Performance:**
   - Validation function is `IMMUTABLE` (can be indexed)
   - Cost conversion functions are `STABLE` (safe for queries)
   - Diagnostic functions are `STABLE` (safe for reporting)

3. **Future Enhancements:**
   - Add `UomConversions` table support (already referenced in `get_unit_cost_in_uom`)
   - Add `roll_length_m` for `per_roll` fabric pricing mode
   - Add more diagnostic functions as needed

---

**Last Updated:** December 2024  
**Status:** ✅ Ready for execution





