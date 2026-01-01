# BOM Configuration Fields Implementation Summary

## Overview

This implementation makes BOM generation deterministic by persisting configuration fields (`tube_type`, `operating_system_variant`, etc.) and using a role-to-SKU resolver function to ensure consistent SKU selection across different configuration variants.

## Migrations Created

### 225: Add Configuration Fields
- **File**: `225_add_bom_configuration_fields.sql`
- **Changes**:
  - Adds `tube_type`, `operating_system_variant`, `top_rail_type` to `QuoteLines`
  - Adds `tube_type`, `operating_system_variant`, `top_rail_type`, `bottom_rail_type`, `side_channel`, `side_channel_type` to `SalesOrderLines`
- **Purpose**: Persist configuration choices that drive BOM SKU selection

### 226: Update Trigger to Copy Config Fields
- **File**: `226_update_trigger_copy_config_fields.sql`
- **Changes**:
  - Updates `on_quote_approved_create_operational_docs()` to copy all configuration fields from `QuoteLines` to `SalesOrderLines`
  - Updates call to `generate_configured_bom_for_quote_line()` to pass new configuration fields
- **Purpose**: Ensure configuration is available in SalesOrderLines for traceability and BOM generation

### 227: Create Role-to-SKU Resolver
- **File**: `227_create_role_to_sku_resolver.sql`
- **Changes**:
  - Creates `resolve_bom_role_to_sku()` function
  - Implements deterministic SKU resolution based on configuration fields
  - Supports all canonical roles: tube, bracket, fabric, bottom_rail_profile, bottom_rail_end_cap, operating_system_drive, motor, motor_adapter, side_channel_profile, side_channel_end_cap
- **Purpose**: Single source of truth for role-to-SKU mapping

### 228: Update BOM Generator to Use Resolver
- **File**: `228_update_bom_generator_use_resolver.sql`
- **Changes**:
  - Updates `generate_configured_bom_for_quote_line()` to:
    - Accept new parameters: `p_tube_type`, `p_operating_system_variant`
    - Load configuration fields from `QuoteLines` if not provided as parameters
    - Use `resolve_bom_role_to_sku()` as primary resolution method
    - Fallback to `component_item_id` and legacy `auto_select` rules
    - Track resolution errors and return them in result JSONB
- **Purpose**: Make BOM generation deterministic and track resolution failures

### 229: Verification Queries
- **File**: `229_verification_queries.sql`
- **Changes**:
  - 10 verification queries to check:
    1. QuoteLines configuration fields
    2. QuoteLineComponents roles
    3. BomInstanceLines roles
    4. SalesOrderLines configuration
    5. Compare different configurations (RTU-42 vs RTU-80)
    6. Side channel components
    7. Linear UOM conversion
    8. Operating system variant resolution
    9. Summary statistics
    10. Resolution errors
- **Purpose**: Validate implementation and diagnose issues

### 230: Canonical BOM Roles Documentation
- **File**: `230_canonical_bom_roles.md`
- **Changes**: Documentation of canonical role names and resolution rules
- **Purpose**: Single source of truth for role definitions

## Key Features

### 1. Deterministic SKU Resolution
- Configuration fields (`tube_type`, `operating_system_variant`) are persisted in `QuoteLines`
- `resolve_bom_role_to_sku()` uses these fields to select the correct SKU
- Different configurations (RTU-42 vs RTU-80, Standard M vs Standard L) produce different SKUs

### 2. Configuration Persistence
- All configuration choices are stored in `QuoteLines` and copied to `SalesOrderLines`
- This ensures traceability and allows BOM regeneration with the same configuration

### 3. Side Channel Support
- Side channel roles (`side_channel_profile`, `side_channel_end_cap`) are conditionally resolved
- Only appear in BOM when `side_channel = true`

### 4. Conditional Roles
- Motor and motor_adapter only resolve when `drive_type = 'motor'`
- Side channel roles only resolve when `side_channel = true`

### 5. Error Tracking
- Resolution failures are logged and returned in the result JSONB
- Helps identify missing SKU mappings or configuration issues

## Usage

### Frontend: Persist Configuration Fields

When user configures a QuoteLine, persist these fields:

```javascript
// Example: Update QuoteLine with configuration
await supabase
  .from('QuoteLines')
  .update({
    tube_type: 'RTU-42',                    // NEW
    operating_system_variant: 'standard_m',  // NEW
    drive_type: 'motor',
    bottom_rail_type: 'standard',
    side_channel: true,
    side_channel_type: 'side_only',
    hardware_color: 'white',
    // ... other fields
  })
  .eq('id', quoteLineId);
```

### Backend: BOM Generation

BOM generation happens automatically when:
1. Quote is approved → `on_quote_approved_create_operational_docs()` trigger fires
2. Trigger calls `generate_configured_bom_for_quote_line()` with configuration fields
3. Function uses `resolve_bom_role_to_sku()` to resolve each role to a SKU
4. QuoteLineComponents are created with resolved SKUs
5. BomInstanceLines are created from QuoteLineComponents
6. Engineering rules calculate `cut_length_mm` and convert linear roles to meters

## Verification

Run verification queries from `229_verification_queries.sql` to check:
- Configuration fields are persisted
- QuoteLineComponents have correct roles and SKUs
- BomInstanceLines inherit roles correctly
- Linear UOM conversion works (tube, bottom_rail_profile → meters)
- Different configurations produce different SKUs

## Next Steps

### STEP 3: Define Canonical BOM Roles (PENDING)
- Ensure all BOMTemplates use canonical role names
- Update existing BOMComponents to use correct role names
- Verify role names match across templates

### STEP 4: Update BOMTemplates to Include Side Channel Roles (PENDING)
- Add `side_channel_profile` and `side_channel_end_cap` to appropriate Roller templates
- Set `block_condition` to include `side_channel: true`
- Ensure these roles are conditionally included

## Notes

- **Do NOT create templates per variant**: BOMTemplates should define structural roles, not decide which SKU variant is used
- **Resolver is the single source of truth**: All SKU resolution goes through `resolve_bom_role_to_sku()`
- **Configuration fields are required**: For deterministic BOM, `tube_type` and `operating_system_variant` should be set
- **Fallback logic exists**: If resolver fails, falls back to `component_item_id` or legacy rules



