-- ====================================================
-- Script de Verificación: BOMTemplates para Shades
-- ====================================================
-- Este script verifica que los 12 templates se crearon correctamente
-- ====================================================

-- 1. Verificar que existen los 12 templates esperados
SELECT 
    '1. TEMPLATES CREADOS' as verificacion,
    pt.name as product_type,
    bt.name as template_name,
    bt.active,
    COUNT(bc.id) as total_components,
    COUNT(CASE WHEN bc.deleted = false THEN 1 END) as active_components
FROM "BOMTemplates" bt
INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY pt.name, bt.name, bt.active
ORDER BY pt.name, bt.name;

-- 2. Verificar componentes por template (detalle)
SELECT 
    '2. COMPONENTES POR TEMPLATE' as verificacion,
    bt.name as template_name,
    bc.component_role,
    COUNT(*) as cantidad,
    COUNT(CASE WHEN bc.component_item_id IS NOT NULL THEN 1 END) as con_catalog_item,
    COUNT(CASE WHEN bc.auto_select = true THEN 1 END) as auto_select,
    COUNT(CASE WHEN bc.applies_color = true THEN 1 END) as aplica_color
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND bc.deleted = false
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY bt.name, bc.component_role
ORDER BY bt.name, bc.component_role;

-- 3. Verificar block_types y block_conditions
SELECT 
    '3. BLOCK TYPES Y CONDITIONS' as verificacion,
    bt.name as template_name,
    bc.block_type,
    bc.block_condition,
    COUNT(*) as cantidad
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND bc.deleted = false
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
  AND bc.block_type IS NOT NULL
GROUP BY bt.name, bc.block_type, bc.block_condition
ORDER BY bt.name, bc.block_type;

-- 4. Verificar que los component_roles son válidos (no debería haber errores)
SELECT 
    '4. COMPONENT ROLES VÁLIDOS' as verificacion,
    bc.component_role,
    COUNT(*) as cantidad,
    CASE 
        WHEN bc.component_role IS NULL THEN 'NULL (permitido)'
        WHEN bc.component_role IN (
            'fabric', 'tube', 'bracket', 'cassette', 'bottom_bar', 'operating_system_drive',
            'motor', 'motor_adapter', 'adapter_end_plug', 'end_plug',
            'clutch', 'clutch_adapter',
            'bracket_end_cap', 'screw_end_cap',
            'bottom_rail_profile', 'bottom_rail_end_cap',
            'cassette_profile', 'cassette_end_cap',
            'side_channel_profile'
        ) THEN '✅ Válido'
        ELSE '❌ INVÁLIDO'
    END as estado
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND bc.deleted = false
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY bc.component_role
ORDER BY estado, bc.component_role;

-- 5. Verificar componentes con hardware_color
SELECT 
    '5. COMPONENTES CON HARDWARE COLOR' as verificacion,
    bt.name as template_name,
    bc.hardware_color,
    bc.component_role,
    COUNT(*) as cantidad
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND bc.deleted = false
  AND bc.applies_color = true
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY bt.name, bc.hardware_color, bc.component_role
ORDER BY bt.name, bc.hardware_color, bc.component_role;

-- 6. Verificar componentes auto_select (tube principalmente)
SELECT 
    '6. COMPONENTES AUTO_SELECT' as verificacion,
    bt.name as template_name,
    bc.component_role,
    bc.auto_select,
    COUNT(*) as cantidad
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
  AND bc.deleted = false
  AND bc.auto_select = true
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY bt.name, bc.component_role, bc.auto_select
ORDER BY bt.name, bc.component_role;

-- 7. Resumen por tipo de shade
SELECT 
    '7. RESUMEN POR TIPO DE SHADE' as verificacion,
    CASE 
        WHEN bt.name ILIKE '%Roller%' THEN 'Roller Shade'
        WHEN bt.name ILIKE '%Dual%' THEN 'Dual Shade'
        WHEN bt.name ILIKE '%Triple%' THEN 'Triple Shade'
    END as shade_type,
    COUNT(DISTINCT bt.id) as total_templates,
    COUNT(DISTINCT bc.id) as total_components,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'tube' THEN bc.id END) as tubes,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'operating_system_drive' THEN bc.id END) as drives,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'bracket' THEN bc.id END) as brackets,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'cassette' THEN bc.id END) as cassettes,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'side_channel_profile' THEN bc.id END) as side_channels,
    COUNT(DISTINCT CASE WHEN bc.component_role = 'bottom_bar' THEN bc.id END) as bottom_bars
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.deleted = false
  AND (bt.name ILIKE '%Roller Shade%' 
       OR bt.name ILIKE '%Dual Shade%' 
       OR bt.name ILIKE '%Triple Shade%')
GROUP BY 
    CASE 
        WHEN bt.name ILIKE '%Roller%' THEN 'Roller Shade'
        WHEN bt.name ILIKE '%Dual%' THEN 'Dual Shade'
        WHEN bt.name ILIKE '%Triple%' THEN 'Triple Shade'
    END
ORDER BY shade_type;

-- 8. Verificar que los templates tienen los componentes esperados (ejemplo: Roller Shade - Base)
SELECT 
    '8. DETALLE: Roller Shade - Base' as verificacion,
    bc.sequence_order,
    bc.component_role,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom,
    bc.block_type,
    bc.block_condition::text as block_condition_text,
    bc.applies_color,
    bc.hardware_color,
    bc.auto_select,
    CASE WHEN bc.component_item_id IS NULL THEN '⚠️ NULL' ELSE '✅' END as catalog_item_status
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.name = 'Roller Shade - Base'
  AND bt.deleted = false
  AND bc.deleted = false
ORDER BY bc.sequence_order;

