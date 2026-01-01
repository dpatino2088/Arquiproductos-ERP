# Canonical BOM Roles Definition

This document defines the canonical BOM role strings that must be used consistently across:
- `BOMTemplates.BOMComponents.component_role`
- `QuoteLineComponents.component_role`
- `BomInstanceLines.part_role`

## Roller Shade Roles

### Core Structural Roles

| Role | Type | UOM | Description | Conditional |
|------|------|-----|-------------|-------------|
| `tube` | Linear | `m` | Main tube (RTU-42, RTU-65, RTU-80) | No |
| `bracket` | Piece | `ea` | Mounting brackets | No |
| `fabric` | Area | `m2` | Shade fabric | No |
| `bottom_rail_profile` | Linear | `m` | Bottom rail profile | No |
| `bottom_rail_end_cap` | Piece | `ea` | Bottom rail end caps | No |
| `operating_system_drive` | Piece | `ea` | Operating system drive (Standard M/L) | No |

### Motorized Roles (Conditional)

| Role | Type | UOM | Description | Conditional |
|------|------|-----|-------------|-------------|
| `motor` | Piece | `ea` | Motor unit | `drive_type = 'motor'` |
| `motor_adapter` | Piece | `ea` | Motor adapter | `drive_type = 'motor'` |

### Side Channel Roles (Conditional)

| Role | Type | UOM | Description | Conditional |
|------|------|-----|-------------|-------------|
| `side_channel_profile` | Linear | `m` | Side channel profile | `side_channel = true` |
| `side_channel_end_cap` | Piece | `ea` | Side channel end caps | `side_channel = true` |
| `side_channel_fixing_kit` | Piece | `ea` | Side channel fixing kit (optional) | `side_channel = true` |

## Role Resolution Rules

### Tube (`tube`)
- **Configuration Field**: `tube_type` (RTU-42, RTU-65, RTU-80)
- **Resolver Logic**: Maps `tube_type` to SKU pattern (e.g., `%RTU-42%`)
- **UOM Conversion**: After `cut_length_mm` is calculated, convert to `uom='m'` and `qty = cut_length_mm / 1000`

### Bracket (`bracket`)
- **Configuration Fields**: `tube_type`, `hardware_color`
- **Resolver Logic**: Matches bracket SKU by tube size and color
- **UOM**: Always `ea`

### Operating System Drive (`operating_system_drive`)
- **Configuration Field**: `operating_system_variant` (standard_m, standard_l)
- **Resolver Logic**: Maps variant to SKU pattern (e.g., `%STANDARD%M%`)
- **UOM**: Always `ea`

### Motor (`motor`)
- **Configuration Fields**: `drive_type` (must be 'motor'), `operating_system_variant`
- **Resolver Logic**: Only resolves if `drive_type = 'motor'`, then maps by variant
- **UOM**: Always `ea`

### Bottom Rail Profile (`bottom_rail_profile`)
- **Configuration Field**: `bottom_rail_type` (standard, wrapped)
- **Resolver Logic**: Maps rail type to SKU pattern
- **UOM Conversion**: After `cut_length_mm` is calculated, convert to `uom='m'` and `qty = cut_length_mm / 1000`

### Side Channel Profile (`side_channel_profile`)
- **Configuration Fields**: `side_channel` (must be true), `side_channel_type`, `hardware_color`
- **Resolver Logic**: Only resolves if `side_channel = true`, then maps by type and color
- **UOM Conversion**: After `cut_length_mm` is calculated, convert to `uom='m'` and `qty = cut_length_mm / 1000`

## Implementation Notes

1. **Role Normalization**: All roles are normalized to lowercase before resolution
2. **Fallback Logic**: If resolver returns NULL, fallback to `component_item_id` from BOMComponents
3. **Error Handling**: If resolution fails, log warning and skip component (do not fail silently)
4. **UOM Conversion**: Linear roles (tube, bottom_rail_profile, side_channel_profile) are converted to meters after `cut_length_mm` is calculated by engineering rules

## Future Roles (Drapery)

| Role | Type | UOM | Description | Conditional |
|------|------|-----|-------------|-------------|
| `top_rail_type` | Piece | `ea` | Top rail (for Drapery) | `product_type = 'drapery'` |



