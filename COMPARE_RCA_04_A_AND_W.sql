-- ============================================================================
-- COMPARAR TODOS LOS CAMPOS DE RCA-04-A Y RCA-04-W
-- ============================================================================

SELECT 
    'COMPARACIÓN COMPLETA' as paso,
    ci.sku,
    ci.item_name,
    ci.organization_id,
    ci.active,
    ci.deleted,
    ci.archived,
    ci.discontinued,
    ci.item_type,
    ci.measure_basis,
    ci.uom,
    ci.is_fabric,
    ci.collection_name,
    ci.variant_name,
    ci.cost_exw,
    ci.msrp,
    ci.created_at,
    ci.updated_at
FROM "CatalogItems" ci
WHERE ci.sku IN ('RCA-04-A', 'RCA-04-W')
ORDER BY ci.sku;








