-- ====================================================
-- Script: Explain OrganizationCounters Table
-- ====================================================
-- This table is used for generating sequential numbers
-- (e.g., SO-000001, QT-000001, MO-000001) per organization
-- ====================================================

-- Step 1: Show table structure
SELECT 
    'Step 1: OrganizationCounters Structure' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'OrganizationCounters'
ORDER BY ordinal_position;

-- Step 2: Show current data
SELECT 
    'Step 2: Current OrganizationCounters Data' as check_type,
    organization_id,
    key,
    last_value,
    updated_at
FROM "OrganizationCounters"
ORDER BY organization_id, key;

-- Step 3: Show primary key constraint
SELECT 
    'Step 3: Primary Key Constraint' as check_type,
    constraint_name,
    constraint_type,
    table_name
FROM information_schema.table_constraints
WHERE table_schema = 'public'
AND table_name = 'OrganizationCounters'
AND constraint_type = 'PRIMARY KEY';

-- Step 4: Explain the design
-- This table uses a COMPOSITE PRIMARY KEY (organization_id, key) instead of a single 'id' column
-- This is CORRECT because:
-- 1. Each organization has multiple counters (one per 'key': 'sale_order', 'quote', 'manufacturing_order', etc.)
-- 2. The combination (organization_id, key) is unique
-- 3. No need for a separate 'id' column - the composite key is sufficient
-- 4. This design is more efficient for lookups: WHERE organization_id = X AND key = 'sale_order'

SELECT 
    'Step 4: Design Explanation' as check_type,
    'This table uses COMPOSITE PRIMARY KEY (organization_id, key)' as design_choice,
    'This is CORRECT - no separate id column needed' as status,
    'Each organization can have multiple counters (sale_order, quote, manufacturing_order, etc.)' as reason;

-- Step 5: Show how it's used
SELECT 
    'Step 5: Usage Example' as check_type,
    'Function: get_next_counter_value(organization_id, key)' as function_name,
    'Returns: next sequential number for that organization and key' as description,
    'Example: get_next_counter_value(org_id, ''sale_order'') → returns 11 (for SO-000011)' as example;








