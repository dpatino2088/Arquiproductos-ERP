# 🔧 Fix: Materials Loading Error (404/406)

## 🐛 Problem

The `useManufacturingMaterials` hook was trying to use a view `SalesOrderMaterialList` that doesn't exist, causing 404 errors. Additionally, embedded joins with `CatalogItems` were causing 406 (Not Acceptable) errors due to RLS policies.

## ✅ Solution

### Changes Made:

1. **Removed `SalesOrderMaterialList` view dependency**
   - The hook now queries `BomInstances` and `BomInstanceLines` directly
   - No fallback to non-existent view

2. **Separated `CatalogItems` query**
   - Removed embedded join: `CatalogItems:resolved_part_id (...)`
   - Fetch `CatalogItems` in a separate query after getting `BomInstanceLines`
   - Chunk the IDs to avoid URL length limits (100 IDs per chunk)
   - Build a Map for efficient lookup

3. **Improved error handling**
   - Better error messages
   - Graceful handling of missing CatalogItems

## 📝 Code Changes

**File:** `src/hooks/useManufacturing.ts`

**Before:**
- Tried to use `SalesOrderMaterialList` view (doesn't exist)
- Used embedded join: `CatalogItems:resolved_part_id (...)`

**After:**
- Queries `BomInstanceLines` directly
- Fetches `CatalogItems` separately
- Maps catalog items to BOM lines

## 🧪 Testing

After this fix:
1. Open Manufacturing Order with status = 'DRAFT' or 'planned'
2. Navigate to "Materials" tab
3. Materials should load without 404/406 errors
4. If BOM exists, materials should display correctly
5. If no BOM exists, should show empty state gracefully

## ⚠️ Note About Cut List

The "Cut List" tab correctly shows:
> "Cut list can only be generated when Manufacturing Order status is Planned. Current status: DRAFT."

This is **expected behavior**. To generate a cut list:
1. First generate BOM (changes MO status to 'planned')
2. Then generate Cut List

---

**Status:** ✅ Fixed - Ready to test






