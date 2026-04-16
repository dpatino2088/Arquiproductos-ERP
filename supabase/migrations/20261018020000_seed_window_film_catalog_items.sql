-- Seed Window Film CatalogItems from pricing table
-- Each row = model × roll width combination
-- measure_basis = 'area', purchase_unit = 'roll', is_roll = true

DO $$
DECLARE
  v_org_id uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2';
  v_pt_id uuid;
  v_item_id uuid;
BEGIN
  SELECT id INTO v_pt_id FROM public."ProductTypes"
  WHERE code = 'window_film' AND organization_id = v_org_id;

  IF v_pt_id IS NULL THEN
    RAISE EXCEPTION 'window_film ProductType not found';
  END IF;

  -- Helper: inserts a CatalogItem + links to ProductType
  -- Parameters: sku, name, roll_width_inches, roll_length_ft, cost_per_sqft
  -- Conversion: 1 inch = 0.0254m, 1 foot = 0.3048m, 1 sqft = 0.0929m²

  CREATE TEMP TABLE _wf_items (
    sku text, name text, roll_width_in numeric, roll_length_ft numeric, cost_per_sqft numeric
  ) ON COMMIT DROP;

  INSERT INTO _wf_items (sku, name, roll_width_in, roll_length_ft, cost_per_sqft) VALUES
    -- Optivision 25/35/45 DA SR (Madico)
    ('WF-OPT-48', 'Optivision 25/35/45 DA SR - 48"', 48, 100, 0.57),
    ('WF-OPT-60', 'Optivision 25/35/45 DA SR - 60"', 60, 100, 0.49),
    ('WF-OPT-72', 'Optivision 25/35/45 DA SR - 72"', 72, 100, 0.50),
    -- Solar Grey 20/35/55
    ('WF-SGREY-48', 'Solar Grey 20/35/55 - 48"', 48, 100, 0.72),
    ('WF-SGREY-60', 'Solar Grey 20/35/55 - 60"', 60, 100, 0.64),
    ('WF-SGREY-72', 'Solar Grey 20/35/55 - 72"', 72, 100, 0.65),
    -- Duralite 10/20/30/40
    ('WF-DURA-60', 'Duralite 10/20/30/40 - 60"', 60, 100, 0.93),
    ('WF-DURA-72', 'Duralite 10/20/30/40 - 72"', 72, 100, 0.94),
    -- Ceramic 30/40/50
    ('WF-CERA-48', 'Ceramic 30/40/50 - 48"', 48, 100, 1.12),
    ('WF-CERA-60', 'Ceramic 30/40/50 - 60"', 60, 100, 1.04),
    ('WF-CERA-72', 'Ceramic 30/40/50 - 72"', 72, 100, 1.05),
    -- Solar Bronze 20/35
    ('WF-SBRONZE-48', 'Solar Bronze 20/35 - 48"', 48, 100, 0.88),
    ('WF-SBRONZE-60', 'Solar Bronze 20/35 - 60"', 60, 100, 0.80),
    ('WF-SBRONZE-72', 'Solar Bronze 20/35 - 72"', 72, 100, 0.81),
    -- PureLite 40/60
    ('WF-PURE-48', 'PureLite 40/60 - 48"', 48, 100, 1.39),
    ('WF-PURE-60', 'PureLite 40/60 - 60"', 60, 100, 1.31),
    ('WF-PURE-72', 'PureLite 40/60 - 72"', 72, 100, 1.32),
    -- Nova 35/50/70
    ('WF-NOVA-60', 'Nova 35/50/70 - 60"', 60, 100, 0.98),
    ('WF-NOVA70-72', 'Nova 70 - 72"', 72, 100, 0.99);

  FOR v_item_id IN
    SELECT gen_random_uuid() FROM _wf_items
  LOOP
    -- placeholder, actual insert below
  END LOOP;

  INSERT INTO public."CatalogItems" (
    id, organization_id, sku, name,
    measure_basis, purchase_unit, unit_of_measure,
    is_roll, roll_pricing_mode, roll_width_m, roll_length_m,
    cost_exw, is_active, item_role,
    manufacturer, manufacturer_id
  )
  SELECT
    gen_random_uuid(),
    v_org_id,
    wi.sku,
    wi.name,
    'area',
    'roll',
    'm',
    true,
    'per_square_meter',
    ROUND((wi.roll_width_in * 0.0254)::numeric, 4),
    ROUND((wi.roll_length_ft * 0.3048)::numeric, 4),
    ROUND((wi.cost_per_sqft * (wi.roll_width_in / 12.0) / 0.3048)::numeric, 4),
    true,
    'window_film',
    'Madico',
    (SELECT id FROM public."Manufacturers" WHERE name = 'Madico' LIMIT 1)
  FROM _wf_items wi
  WHERE NOT EXISTS (
    SELECT 1 FROM public."CatalogItems" ci
    WHERE ci.sku = wi.sku AND ci.organization_id = v_org_id
  );

  INSERT INTO public."CatalogItemProductTypes" (catalog_item_id, product_type_id, organization_id)
  SELECT ci.id, v_pt_id, v_org_id
  FROM public."CatalogItems" ci
  WHERE ci.item_role = 'window_film'
    AND ci.organization_id = v_org_id
    AND NOT EXISTS (
      SELECT 1 FROM public."CatalogItemProductTypes" cipt
      WHERE cipt.catalog_item_id = ci.id AND cipt.product_type_id = v_pt_id
    );

  -- Trigger MSRP compute for all window film items
  PERFORM public.msrp_compute_for_item(ci.id)
  FROM public."CatalogItems" ci
  WHERE ci.item_role = 'window_film'
    AND ci.organization_id = v_org_id;

END $$;
