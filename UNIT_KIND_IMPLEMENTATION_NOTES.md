# Unit Kind Implementation Notes

## Overview

This document describes the implementation of `unit_kind` to split `measure_basis='unit'` into two behaviors:
- **Dimensional Unit**: Affects dimensions of other roles via EngineeringRules
- **Consumable Unit**: Does NOT affect dimensions, only adds BOM lines (qty)

---

## Backend Changes

### 1. Database Schema

**File:** `ADD_UNIT_KIND_TO_CATALOG_ITEMS.sql`

- Added `unit_kind` column to `CatalogItems`
- Values: `'dimensional'` | `'consumable'` (only for `measure_basis = 'unit'`)
- Default: `'consumable'` (safe default)
- NULL for non-unit items
- CHECK constraint ensures data integrity

### 2. Engineering Rules Function

**File:** `UPDATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_WITH_UNIT_KIND.sql`

- Updated `resolve_dimensional_adjustments()` to filter by `unit_kind`
- Only processes components where:
  - `measure_basis != 'unit'` (fabric, linear_m always processed), OR
  - `measure_basis = 'unit' AND unit_kind = 'dimensional'` (only dimensional units)
- Consumable units are excluded from dimensional calculations

### 3. BOM Generation

**No changes required** - `generate_bom_for_manufacturing_order()` already:
- Copies all `QuoteLineComponents` to `BomInstanceLines` (regardless of `unit_kind`)
- Calls `resolve_dimensional_adjustments()` which now filters by `unit_kind`
- Dimensional adjustments only come from dimensional units

---

## Frontend / Configuration

### Where to Set `unit_kind`

#### Option 1: Catalog Items Management UI

**Location:** `src/pages/catalog/` (Catalog Items list/edit)

**Implementation:**
- Add a `Select` or `Radio` field when editing a Catalog Item
- Show field **only when** `measure_basis = 'unit'`
- Options:
  - `'dimensional'` - "Affects dimensions (brackets, drives, etc.)"
  - `'consumable'` - "Consumable item (screws, glue, etc.)"
- Default: `'consumable'`

**Example UI:**
```tsx
{formData.measure_basis === 'unit' && (
  <Select
    label="Unit Type"
    value={formData.unit_kind || 'consumable'}
    onChange={(value) => setFormData({ ...formData, unit_kind: value })}
    options={[
      { value: 'dimensional', label: 'Dimensional (affects dimensions)' },
      { value: 'consumable', label: 'Consumable (BOM line only)' }
    ]}
  />
)}
```

#### Option 2: BOM Template Configuration

**Location:** Where BOM Templates are configured (if applicable)

**Implementation:**
- When creating/editing BOM Templates, tag components as dimensional or consumable
- This would propagate to `CatalogItems.unit_kind` when templates are applied

#### Option 3: Bulk Update Script

**Location:** SQL script for bulk updates

**Example:**
```sql
-- Mark brackets as dimensional
UPDATE "CatalogItems"
SET unit_kind = 'dimensional'
WHERE measure_basis = 'unit'
AND (item_name ILIKE '%bracket%' OR sku LIKE 'RC%')
AND deleted = false;

-- Mark screws/glue as consumable (already default, but explicit)
UPDATE "CatalogItems"
SET unit_kind = 'consumable'
WHERE measure_basis = 'unit'
AND (item_name ILIKE '%screw%' OR item_name ILIKE '%glue%')
AND deleted = false;
```

---

## Examples

### Dimensional Units (affect dimensions)
- **Brackets** (`RC3104-W`, etc.) - Subtract from tube length
- **Drives/Motors** - May affect fabric width/height
- **Cassettes** - Affect fabric dimensions
- **End caps** - May affect rail length

### Consumable Units (BOM line only)
- **Screws** - Just add to BOM, no dimensional effect
- **Glue/Adhesive** - Just add to BOM, no dimensional effect
- **Packaging materials** - Just add to BOM
- **Labels/Tags** - Just add to BOM

---

## Migration Path

1. **Run `ADD_UNIT_KIND_TO_CATALOG_ITEMS.sql`**
   - Adds column with default `'consumable'` for all unit items
   - Safe: All existing items default to consumable (no breaking changes)

2. **Run `UPDATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_WITH_UNIT_KIND.sql`**
   - Updates function to filter by `unit_kind`
   - Safe: Only dimensional units affect dimensions (consumables already didn't affect)

3. **Review and Update Catalog Items**
   - Identify items that should be `'dimensional'`
   - Update via UI or bulk SQL script
   - Examples: Brackets, drives, cassettes → `'dimensional'`

4. **Test**
   - Verify dimensional adjustments only come from dimensional units
   - Verify consumable units still appear in BOM but don't affect dimensions

---

## Breaking Changes

**None** - This is a purely additive change:
- Existing unit items default to `'consumable'` (safe)
- Dimensional adjustments only apply to dimensional units (was already the case for most)
- BOM generation unchanged (still copies all components)

---

## Verification Queries

```sql
-- Check unit_kind distribution
SELECT 
    unit_kind,
    COUNT(*) as count
FROM "CatalogItems"
WHERE measure_basis = 'unit'
AND deleted = false
GROUP BY unit_kind;

-- Check which items are dimensional
SELECT 
    sku,
    item_name,
    unit_kind
FROM "CatalogItems"
WHERE measure_basis = 'unit'
AND unit_kind = 'dimensional'
AND deleted = false
ORDER BY sku;
```






