# Inventory Unit Model v2

This document defines how purchasing quantities are converted into internal inventory quantities.

## Canonical rules

- Internal stock basis:
  - `ea` for unit items.
  - `linear_m` for linear materials and roll materials.
- Purchase mode:
  - `unit_packaged`: purchase by each/pack/box/case/set/bag/bundle/carton.
  - `linear_direct`: purchase directly in `m`, `ft`, or `yd`.
  - `roll`: purchase by roll; normalize to meters using roll length.

## Resolution matrix

- If `is_roll = true` -> `stockBasis = linear_m`, `purchaseMode = roll`
- Else if `measure_basis = linear`:
  - `purchase_unit in (each, pack, set, box, case, bag, bundle, carton)` -> `unit_packaged`
  - otherwise -> `linear_direct`
- Else (`measure_basis = unit` or `area`) -> `stockBasis = ea`, `purchaseMode = unit_packaged`

## Normalization

- `roll`: `internal_qty_m = purchase_qty * roll_length_in_meters`
- `linear_direct`: `internal_qty_m = purchase_qty converted from m/ft/yd to m`
- `unit_packaged`: `internal_qty = purchase_qty * units_per_purchase_unit`

## Notes

- `m2` for roll/fabric is derived as a reference (`length_m * width_m`) and is not the stock basis.
- Existing fields remain valid for backward compatibility:
  - `purchase_unit`, `units_per_purchase_unit`
  - `unit_of_measure`, `measure_basis`
  - `roll_length_value`, `roll_length_uom`, `roll_width_value`, `roll_width_uom`

