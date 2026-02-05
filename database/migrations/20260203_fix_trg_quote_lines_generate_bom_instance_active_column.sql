-- Fix schema mismatch in quote line trigger:
-- BOMTemplates column is "is_active", not "active".

CREATE OR REPLACE FUNCTION public.trg_quote_lines_generate_bom_instance_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product_type_id uuid;
BEGIN
  -- Solo en INSERT
  IF TG_OP = 'INSERT' THEN

    -- ✅ Resolver product_type_id
    -- 1) Si QuoteLines tiene product_type_id úsalo
    BEGIN
      EXECUTE 'SELECT ($1).product_type_id' INTO v_product_type_id USING NEW;
    EXCEPTION WHEN undefined_column THEN
      v_product_type_id := NULL;
    END;

    -- 2) Fallback: intenta por ConfiguredProducts si existe relación
    IF v_product_type_id IS NULL THEN
      BEGIN
        EXECUTE $q$
          SELECT cp.product_type_id
          FROM public."ConfiguredProducts" cp
          WHERE cp.id = ($1).configured_product_id
          LIMIT 1
        $q$ INTO v_product_type_id USING NEW;
      EXCEPTION WHEN undefined_column THEN
        v_product_type_id := NULL;
      END;
    END IF;

    -- 3) Fallback FINAL: primer template activo del org (si tienes un default)
    IF v_product_type_id IS NULL THEN
      SELECT bt.product_type_id
      INTO v_product_type_id
      FROM public."BOMTemplates" bt
      WHERE bt.organization_id = NEW.organization_id
        AND bt.deleted = false
        AND bt.archived = false
        AND bt.is_active = true
      ORDER BY COALESCE((bt.metadata->>'priority')::int, 0) DESC, bt.updated_at DESC
      LIMIT 1;
    END IF;

    IF v_product_type_id IS NULL THEN
      RAISE EXCEPTION 'Cannot generate BOMInstance: product_type_id could not be resolved for QuoteLine %', NEW.id;
    END IF;

    -- ✅ Llamada CORRECTA (3 params)
    PERFORM public.generate_bom_instance_for_quote_line(
      NEW.organization_id,
      NEW.id,
      v_product_type_id
    );
  END IF;

  RETURN NEW;
END;
$$;

