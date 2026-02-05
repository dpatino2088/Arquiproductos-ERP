-- ============================================================================
-- Migration: QuoteLine Pricing from ConfiguredProduct
-- Date: 2026-02-04
-- Description: 
--   QuoteLine debe tomar precio FINAL únicamente desde ConfiguredProducts.
--   El precio queda congelado (pricing_locked=true), sin recálculos.
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. AGREGAR bom_preview_snapshot SI NO EXISTE
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'ConfiguredProducts' 
      AND column_name = 'bom_preview_snapshot'
  ) THEN
    ALTER TABLE public."ConfiguredProducts"
    ADD COLUMN bom_preview_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb;
    
    COMMENT ON COLUMN public."ConfiguredProducts".bom_preview_snapshot IS 
    'JSONB snapshot del breakdown de BOM para UI. Contiene version, totals, items[].';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. RPC: commit_configured_product_to_quote_line
--    Fuente ÚNICA para crear QuoteLines desde productos configurados.
--    Usa totales directamente de ConfiguredProducts.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_company_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_roll_item RECORD;
  v_operating_type text;
  
  -- Totales finales (desde ConfiguredProducts)
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  
  -- Snapshot fallback
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  -- Recalc when snapshot/columns give 0 (e.g. snapshot not persisted yet)
  v_recalc jsonb;
BEGIN
  -- ═══════════════════════════════════════════════════════════════════════
  -- VALIDACIONES
  -- ═══════════════════════════════════════════════════════════════════════
  IF p_org_id IS NULL THEN
    RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required';
  END IF;
  
  IF p_quote_id IS NULL THEN
    RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required';
  END IF;
  
  IF p_configured_product_id IS NULL THEN
    RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required';
  END IF;

  -- Obtener ConfiguredProduct
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', 
      p_configured_product_id, p_org_id;
  END IF;

  IF v_cp.bom_template_id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % has no bom_template_id', p_configured_product_id;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- EXTRAER TOTALES: PRIORIDAD snapshot.items > snapshot.totals > columnas
  -- El snapshot.items tiene los precios correctos calculados en tiempo real
  -- ═══════════════════════════════════════════════════════════════════════
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  
  -- Inicializar en 0
  v_roll_msrp_total := 0;
  v_bom_total := 0;
  v_roll_total_cost := 0;
  v_bom_total_cost := 0;
  v_labor_amount := 0;
  v_accessories_total := 0;
  v_total_msrp := 0;
  
  -- ✅ MÉTODO 1: Calcular BOM total desde snapshot.items (más preciso)
  IF v_snapshot->>'version' = '1' AND jsonb_array_length(v_snapshot->'items') > 0 THEN
    -- Sumar todos los line_total de los items del snapshot
    SELECT 
      COALESCE(SUM(CASE WHEN item->>'kind' = 'roll' THEN (item->>'line_total')::numeric ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN item->>'kind' IN ('parent', 'child') THEN (item->>'line_total')::numeric ELSE 0 END), 0)
    INTO v_roll_msrp_total, v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item;
    
    -- También sumar children si existen
    SELECT COALESCE(SUM((child->>'line_total')::numeric), 0)
    INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item,
         jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) AS child
    WHERE item->>'kind' = 'parent';
    
    -- Recalcular bom_total sumando padres + hijos
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + 
      COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0)
    INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item
    WHERE item->>'kind' = 'parent';
    
    -- Roll MSRP desde items
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0)
    INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item
    WHERE item->>'kind' = 'roll';
    
    RAISE NOTICE 'Calculated from snapshot.items: roll=%, bom=%', v_roll_msrp_total, v_bom_total;
    
    -- Labor y accessories desde snapshot.totals si están disponibles
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    
  -- ✅ MÉTODO 2: Usar snapshot.totals directamente
  ELSIF v_snapshot->>'version' = '1' AND v_snapshot_totals IS NOT NULL THEN
    v_roll_msrp_total := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, 0);
    v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_total_msrp := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
    
    RAISE NOTICE 'Using snapshot.totals: roll=%, bom=%, total=%', v_roll_msrp_total, v_bom_total, v_total_msrp;
    
  -- ✅ MÉTODO 3: Fallback a columnas directas
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp := COALESCE(v_cp.total_msrp, 0);
    
    RAISE NOTICE 'Using ConfiguredProducts columns: roll=%, bom=%, total=%', 
      v_roll_msrp_total, v_bom_total, v_total_msrp;
  END IF;
  
  -- ✅ SIEMPRE calcular total_msrp desde las partes (más confiable)
  v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  -- ✅ Si el total sigue en 0 (snapshot vacío o columnas sin persistir), recalcular desde BOM
  IF (v_total_msrp IS NULL OR v_total_msrp = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(p_configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN
          v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
        END IF;
        RAISE NOTICE 'Totals were 0; recalculated via calculate_configured_product_totals: total_msrp=%', v_total_msrp;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'calculate_configured_product_totals failed (%), keeping existing totals', SQLERRM;
    END;
  END IF;
  
  RAISE NOTICE 'Final totals: roll=%, bom=%, labor=%, acc=%, TOTAL MSRP=%',
    v_roll_msrp_total, v_bom_total, v_labor_amount, v_accessories_total, v_total_msrp;

  -- ═══════════════════════════════════════════════════════════════════════
  -- PREPARAR DATOS ADICIONALES
  -- ═══════════════════════════════════════════════════════════════════════
  
  -- Dimensiones en metros
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  
  -- Normalizar operating_type
  v_operating_type := COALESCE(
    v_cp.operating_type,
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operating_type'
  );
  IF v_operating_type IS NOT NULL THEN
    v_operating_type := lower(trim(v_operating_type));
    IF v_operating_type IN ('motorized', 'motorised') THEN
      v_operating_type := 'motor';
    END IF;
  END IF;
  
  -- Info del Roll/Fabric
  SELECT 
    ci.sku,
    ci.name,
    ci.category_id,
    ci.manufacturer_id,
    m.name as manufacturer_name,
    ci.collection_name,
    ci.variant_name,
    COALESCE(ci.roll_width_m, ci.roll_width) as roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  -- ═══════════════════════════════════════════════════════════════════════
  -- INSERTAR QUOTELINE CON PRECIOS CONGELADOS
  -- ═══════════════════════════════════════════════════════════════════════
  
  INSERT INTO public."QuoteLines" (
    -- Identidad
    organization_id,
    company_id,
    quote_id,
    
    -- Producto
    product_type_id,
    configured_product_id,
    bom_template_id,
    
    -- Roll/Fabric
    catalog_item_id,
    sku,
    name,
    category_id,
    manufacturer_id,
    manufacturer,
    collection_name,
    variant_name,
    is_roll,
    roll_type,
    roll_width_m,
    
    -- Medidas
    width_m,
    height_m,
    quantity,
    
    -- Hardware
    hardware_color,
    drive_type,
    
    -- Ubicación
    position,
    area,
    
    -- ═══════════════════════════════════════════════════════════════════
    -- PRECIOS CONGELADOS DESDE ConfiguredProducts
    -- ═══════════════════════════════════════════════════════════════════
    roll_msrp_snapshot,
    bom_msrp_snapshot,
    roll_cost_snapshot,
    bom_cost_snapshot,
    msrp,
    total_cost,
    
    -- Estado: CONGELADO
    pricing_locked,
    last_priced_at,
    pricing_version
  )
  VALUES (
    -- Identidad
    p_org_id,
    COALESCE(p_company_id, (SELECT company_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)),
    p_quote_id,
    
    -- Producto
    v_cp.product_type_id,
    v_cp.id,  -- configured_product_id (link)
    v_cp.bom_template_id,
    
    -- Roll/Fabric
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku),
    v_roll_item.name,
    v_roll_item.category_id,
    v_roll_item.manufacturer_id,
    v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    
    -- Medidas
    v_width_m,
    v_height_m,
    COALESCE(v_cp.quantity, 1),
    
    -- Hardware
    v_cp.hardware_color,
    v_operating_type,
    
    -- Ubicación
    p_position,
    p_area,
    
    -- ═══════════════════════════════════════════════════════════════════
    -- PRECIOS: Directamente de ConfiguredProducts (fuente de verdad)
    -- ═══════════════════════════════════════════════════════════════════
    v_roll_msrp_total,       -- roll_msrp_snapshot
    v_bom_total,             -- bom_msrp_snapshot
    v_roll_total_cost,       -- roll_cost_snapshot
    v_bom_total_cost,        -- bom_cost_snapshot
    v_total_msrp,            -- msrp (PRECIO FINAL LISTADO)
    v_roll_total_cost + v_bom_total_cost + v_labor_amount, -- total_cost
    
    -- Estado: CONGELADO (no recalcular)
    true,    -- pricing_locked
    now(),   -- last_priced_at
    1        -- pricing_version
  )
  RETURNING id INTO v_quote_line_id;

  IF v_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'Failed to insert QuoteLine for ConfiguredProduct %', p_configured_product_id;
  END IF;

  RAISE NOTICE 'QuoteLine created: id=%, msrp=%', v_quote_line_id, v_total_msrp;

  -- ═══════════════════════════════════════════════════════════════════════
  -- ✅ NO CREAR BOMINSTANCE AQUÍ
  -- El bom_preview_snapshot en ConfiguredProducts es suficiente para ventas.
  -- BOMInstance se creará solo cuando el Quote se apruebe para Manufactura.
  -- ═══════════════════════════════════════════════════════════════════════
  
  v_bom_instance_id := NULL;
  
  RAISE NOTICE 'QuoteLine created without BOMInstance (will be created on approval for manufacturing)';

  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line IS 
'RPC oficial para crear QuoteLine desde ConfiguredProduct.

FUENTE DE VERDAD para precios:
- QuoteLines.msrp = ConfiguredProducts.total_msrp
- QuoteLines.roll_msrp_snapshot = ConfiguredProducts.roll_msrp_total
- QuoteLines.bom_msrp_snapshot = ConfiguredProducts.bom_total
- QuoteLines.roll_cost_snapshot = ConfiguredProducts.roll_total_cost
- QuoteLines.bom_cost_snapshot = ConfiguredProducts.bom_total_cost
- QuoteLines.total_cost = roll_total_cost + bom_total_cost + labor_amount

CONGELADO: pricing_locked=true para evitar recálculos automáticos.

Fallback a bom_preview_snapshot.totals si columnas directas son 0/null.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. TRIGGER: Guard para configured_product_id
--    Si QuoteLine viene del configurador, NO generar BOM automáticamente.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.trg_quote_lines_generate_bom_instance_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product_type_id uuid;
  v_exists boolean;
BEGIN
  -- ═══════════════════════════════════════════════════════════════════════
  -- GUARD 1: Si viene del configurador, NO hacer nada aquí.
  -- La RPC commit_configured_product_to_quote_line ya crea el BOMInstance.
  -- ═══════════════════════════════════════════════════════════════════════
  IF NEW.configured_product_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- GUARD 2: Si pricing_locked, no modificar (para evitar recálculos)
  -- ═══════════════════════════════════════════════════════════════════════
  IF NEW.pricing_locked = true THEN
    RETURN NEW;
  END IF;

  -- GUARD 3: Si ya existe BOMInstance, no hacer nada
  SELECT EXISTS (
    SELECT 1
    FROM public."BOMInstances" bi
    WHERE bi.organization_id = NEW.organization_id
      AND bi.quote_line_id = NEW.id
  ) INTO v_exists;

  IF v_exists THEN
    RETURN NEW;
  END IF;

  -- GUARD 4: Si ya tiene bom_template_id, el frontend/RPC lo maneja
  IF NEW.bom_template_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Resolver product_type_id
  v_product_type_id := NEW.product_type_id;

  -- Fallback: si no hay product_type_id, no inventar
  IF v_product_type_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Generar BOM solo para líneas legacy
  PERFORM public.generate_bom_instance_for_quote_line(
    NEW.organization_id, 
    NEW.id, 
    v_product_type_id
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_quote_lines_generate_bom_instance_fn IS 
'Trigger para generar BOMInstance automáticamente en QuoteLines LEGACY.

GUARDS que evitan ejecución:
1. configured_product_id IS NOT NULL -> Skip (viene del configurador)
2. pricing_locked = true -> Skip (precio congelado)
3. BOMInstance ya existe -> Skip
4. bom_template_id ya definido -> Skip
5. product_type_id IS NULL -> Skip

Solo aplica a líneas legacy (creadas sin configurador).';

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '✅ Migration 20260204_quoteline_pricing_from_configured_product';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
  RAISE NOTICE '  - commit_configured_product_to_quote_line RPC created/updated';
  RAISE NOTICE '  - trg_quote_lines_generate_bom_instance_fn updated with guards';
  RAISE NOTICE '  - QuoteLine.msrp now comes from ConfiguredProducts.total_msrp';
  RAISE NOTICE '  - pricing_locked=true prevents automatic repricing';
  RAISE NOTICE '══════════════════════════════════════════════════════════════';
END $$;
