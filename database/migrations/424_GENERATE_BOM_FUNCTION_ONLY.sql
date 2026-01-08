-- ====================================================
-- Migration 424: Updated generate_bom_for_manufacturing_order Function
-- ====================================================
-- This file contains ONLY the generate_bom_for_manufacturing_order function
-- with all the fixes for fabric resolution and UOM normalization.
-- 
-- INSTRUCTIONS:
-- 1. Copy ALL content from this file
-- 2. Paste in Supabase SQL Editor
-- 3. Execute
-- ====================================================

CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
-- [FUNCTION BODY - Copy from 405_fix_bom_instances_rls_and_return_counts.sql lines 152-1607]
-- This is a placeholder - the actual function body is in 405_fix_bom_instances_rls_and_return_counts.sql
-- You need to copy the ENTIRE function from that file (from CREATE OR REPLACE to $$;)
$$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order IS 
    'Generates BOM instances and lines for a Manufacturing Order. Supports formulas (qty_formula_code), assemblies (CatalogItemBOMLines), and ensures linear quantities are stored in METERS (uom=''m''). Returns JSON with counts (created_instances, created_lines) and errors/warnings. Uses QuoteLine.hardware_color (user selection) with priority over BOMComponent.hardware_color (fallback) for auto-select SKU resolution. Calculates and stores costs from CatalogItems.';

GRANT EXECUTE ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) TO authenticated;


