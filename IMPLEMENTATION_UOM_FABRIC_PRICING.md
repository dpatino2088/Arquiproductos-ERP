# 🎯 Implementation: Robust UOM and Fabric Pricing Model

## 📋 Overview

This implementation fixes the BOM UOM normalization system to properly handle:
- **Fabric items** with pricing modes (per_sqm, per_linear_m, per_linear_yd)
- **Base quantities** in canonical UOM (m, m2, ea) for engineering/reporting
- **Pricing quantities** in purchase/display UOM for procurement
- **Cost conversions** using `roll_width_m` for fabric items

## 🗂️ Migration Files

1. **`database/migrations/200_robust_uom_fabric_pricing_model.sql`**
   - Creates enums (uom_code, measure_basis_code, fabric_pricing_mode)
   - Adds fields to CatalogItems and BomInstanceLines
   - Creates/updates normalization and validation functions
   - Enhances cost conversion functions
   - Provides diagnostic queries

2. **`database/migrations/201_update_bom_trigger_use_base_pricing_fields.sql`**
   - Updates trigger function to populate base/pricing fields
   - Ensures new BOMs get proper UOM handling

## 🚀 Execution Order

```sql
-- Step 1: Run main migration
\i database/migrations/200_robust_uom_fabric_pricing_model.sql

-- Step 2: Update trigger
\i database/migrations/201_update_bom_trigger_use_base_pricing_fields.sql

-- Step 3: Backfill existing data
SELECT * FROM backfill_bom_lines_base_pricing();

-- Step 4: Verify
SELECT * FROM diagnostic_invalid_uom_measure_basis();
```

## 📊 New Fields

### CatalogItems
- `fabric_pricing_mode` (enum): `per_sqm`, `per_linear_m`, `per_linear_yd`, `per_roll`
- `pricing_uom` (text): Explicit pricing UOM if different from base

### BomInstanceLines
- `qty_base` / `uom_base`: Base consumption (canonical: m, m2, ea)
- `qty_pricing` / `uom_pricing`: Purchase/display quantities
- `unit_cost_base` / `total_cost_base`: Costs in base UOM
- `unit_cost_pricing` / `total_cost_pricing`: Costs in pricing UOM
- `calc_notes`: Calculation explanation

## 🔧 Key Functions

### `normalize_uom_to_canonical(p_uom text)`
**Updated** to preserve m2:
- Length units → `'m'`
- Area units → `'m2'`
- Everything else → `'ea'`

### `get_unit_cost_in_uom(p_catalog_item_id, p_target_uom, p_org_id)`
**Enhanced** to support:
- `m2` as target UOM
- Fabric conversions using `roll_width_m`:
  - `cost_m2 → cost_m`: `cost_m2 * roll_width_m`
  - `cost_m → cost_m2`: `cost_m / roll_width_m`
  - Yard conversions via `0.9144` factor

### `calculate_fabric_pricing_qty(p_qty_base_m2, p_fabric_pricing_mode, p_roll_width_m)`
**New** function that calculates:
- `per_sqm`: Returns same qty, `uom='m2'`
- `per_linear_m`: `qty = qty_base_m2 / roll_width_m`, `uom='m'`
- `per_linear_yd`: `qty = (qty_base_m2 / roll_width_m) / 0.9144`, `uom='yd'`

### `populate_bom_line_base_pricing_fields(...)`
**New** function that:
- Determines base UOM (always `m2` for fabric)
- Calculates pricing qty/UOM based on `fabric_pricing_mode`
- Computes costs in both base and pricing UOMs
- Updates BomInstanceLine with all fields

## 📝 Usage Examples

### Setting Fabric Pricing Mode

```sql
-- Set fabric to price per linear meter
UPDATE "CatalogItems"
SET fabric_pricing_mode = 'per_linear_m',
    roll_width_m = 1.5  -- 1.5m roll width
WHERE id = '<fabric_item_id>'
AND is_fabric = true;
```

### Querying BOM with Base/Pricing

```sql
-- Get BOM lines with both base and pricing quantities
SELECT 
    bil.part_role,
    bil.qty_base,
    bil.uom_base,
    bil.qty_pricing,
    bil.uom_pricing,
    bil.unit_cost_pricing,
    bil.total_cost_pricing
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = '<bom_instance_id>'
AND bil.deleted = false;
```

### Diagnostic Queries

```sql
-- 1. Show BOM lines for a SaleOrderLine
SELECT * FROM diagnostic_bom_lines_for_sale_order_line('<sale_order_line_id>');

-- 2. Find invalid UOM/measure_basis pairs
SELECT * FROM diagnostic_invalid_uom_measure_basis();

-- 3. Compare QuoteLineComponents vs BomInstanceLines
SELECT * FROM diagnostic_quote_vs_bom_lines('<quote_line_id>');
```

## ⚠️ Important Notes

### Fabric Items
- **Base UOM is always `m2`** (even if stored as linear m in QuoteLineComponents)
- **Pricing UOM** depends on `fabric_pricing_mode`:
  - `per_sqm` → `m2`
  - `per_linear_m` → `m`
  - `per_linear_yd` → `yd`
- **Requires `roll_width_m`** for conversions (if NULL, falls back to base)

### Non-Fabric Items
- Base and pricing are the same (canonical UOM)
- No special conversion needed

### Backward Compatibility
- Existing `qty`, `uom`, `unit_cost_exw`, `total_cost_exw` fields remain
- New fields are additive (nullable initially)
- Backfill function populates new fields from existing data

## 🔍 Troubleshooting

### Issue: Fabric qty_pricing is NULL
**Check:**
1. Does CatalogItem have `fabric_pricing_mode` set?
2. Does CatalogItem have `roll_width_m` > 0?
3. Run backfill: `SELECT * FROM backfill_bom_lines_base_pricing();`

### Issue: Costs are 0
**Check:**
1. Does CatalogItem have `cost_exw`?
2. Does `get_unit_cost_in_uom()` return a value?
   ```sql
   SELECT public.get_unit_cost_in_uom('<item_id>', 'm2', '<org_id>');
   ```

### Issue: Invalid UOM/measure_basis pairs
**Fix:**
```sql
-- See invalid pairs
SELECT * FROM diagnostic_invalid_uom_measure_basis();

-- Fix example: change UOM to match measure_basis
UPDATE "CatalogItems"
SET uom = 'm2'
WHERE measure_basis = 'fabric' AND uom = 'ea';
```

## 📈 Next Steps (Future Enhancements)

1. **UI Updates**: Show base/pricing quantities in Manufacturing Orders
2. **Purchase Orders**: Use `qty_pricing` / `uom_pricing` for procurement
3. **Reporting**: Aggregate by base UOM for engineering, by pricing UOM for purchasing
4. **Roll Length**: Support `per_roll` pricing mode (requires `roll_length_m`)

## ✅ Validation Checklist

After running migrations:

- [ ] Enums created: `uom_code`, `measure_basis_code`, `fabric_pricing_mode`
- [ ] CatalogItems has `fabric_pricing_mode`, `pricing_uom` columns
- [ ] BomInstanceLines has all base/pricing columns
- [ ] Functions exist: `normalize_uom_to_canonical`, `get_unit_cost_in_uom`, etc.
- [ ] Trigger function updated
- [ ] Backfill completed: `SELECT COUNT(*) FROM backfill_bom_lines_base_pricing() WHERE updated = true;`
- [ ] No invalid UOM pairs: `SELECT COUNT(*) FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;`

---

**Created:** December 2024  
**Version:** 1.0





