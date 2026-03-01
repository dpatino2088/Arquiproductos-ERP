# Phase 1 QA Checklist - Categories/Subcategories

## Scope

This checklist validates the Phase 1 contract:
- taxonomy is strictly 2 levels (`Category` -> `Subcategory`)
- BOM parent/children semantics are kept separate
- item assignment uses subcategory leaves only

Legend:
- `[x]` = verified in code/migrations
- `[ ]` = pending runtime QA in environment

## Database contract checks

- [ ] Migration `20260228173000_phase1_catalog_categories_subcategories_contract.sql` runs successfully.
- [x] `CatalogCategories` has expected columns: `code`, `is_group`, `deleted`, `archived`.
- [x] Root rows are auto-normalized as `is_group = true`.
- [x] Child rows are auto-normalized as `is_group = false`.
- [x] `CatalogCategories` trigger rejects depth > 2 and cross-org parent references.
- [x] `CatalogItems` trigger rejects `category_id` pointing to a parent category.
- [x] Existing items formerly pointing to parent categories are reassigned to a valid subcategory ("General" when needed).

## Categories UI checks

- [x] `Categories` page shows two clear blocks: `Categories` and `Subcategories`.
- [x] Selecting a category filters subcategories for that parent.
- [x] Category form creates/edits only parent categories.
- [x] Subcategory form requires a selected parent category.
- [ ] Deleting a category with subcategories is blocked with a clear error.
- [ ] Deleting a subcategory with assigned items is blocked with a clear error.

## Item form checks

- [x] `CatalogItemNew` field label is `Subcategory`.
- [x] The dropdown only lists leaf nodes (no parent categories).
- [x] Options render as `Category > Subcategory` path for context.
- [x] Saving an item with a parent category id is blocked at DB level.

## Regression checks

- [ ] Catalog list/detail modules still resolve category names correctly.
- [ ] BOM behavior modules continue using BOM role logic (no taxonomy coupling).
- [x] No fallback to legacy `ItemCategories` path remains in category hooks.
