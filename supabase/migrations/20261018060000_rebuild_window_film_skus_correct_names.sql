-- Rebuild Window Film CatalogItems with correct provider names/SKUs
-- 53 items: each model × available widths, variant = Neutral/Grey/Bronze
-- Costs from Madico price sheet (per roll), same for all models within a collection family

DO $$
DECLARE
  v_org_id uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2';
  v_pt_id uuid;
  v_mfr_id uuid;
  v_cat_id uuid;
BEGIN
  SELECT id INTO v_pt_id FROM public."ProductTypes"
  WHERE code = 'window_film' AND organization_id = v_org_id;
  IF v_pt_id IS NULL THEN
    RAISE EXCEPTION 'window_film ProductType not found';
  END IF;

  SELECT id INTO v_mfr_id FROM public."Manufacturers" WHERE name = 'Madico' LIMIT 1;

  SELECT id INTO v_cat_id FROM public."CatalogCategories"
  WHERE name = 'Window Films' AND organization_id = v_org_id AND parent_id IS NOT NULL LIMIT 1;

  -- Nullify FK references from QuoteLines
  UPDATE public."QuoteLines"
  SET catalog_item_id = NULL
  WHERE catalog_item_id IN (
    SELECT id FROM public."CatalogItems"
    WHERE item_role = 'window_film' AND organization_id = v_org_id
  );

  -- Remove old items
  DELETE FROM public."CatalogItemProductTypes"
  WHERE catalog_item_id IN (
    SELECT id FROM public."CatalogItems"
    WHERE item_role = 'window_film' AND organization_id = v_org_id
  );
  DELETE FROM public."CatalogItemsMSRP"
  WHERE catalog_item_id IN (
    SELECT id FROM public."CatalogItems"
    WHERE item_role = 'window_film' AND organization_id = v_org_id
  );
  DELETE FROM public."CatalogItemSupply"
  WHERE catalog_item_id IN (
    SELECT id FROM public."CatalogItems"
    WHERE item_role = 'window_film' AND organization_id = v_org_id
  );
  DELETE FROM public."CatalogItems"
  WHERE item_role = 'window_film' AND organization_id = v_org_id;

  -- 53 items: collection_name, variant_color, sku, display_name, width_in, length_ft, cost_per_ft (Arquiproductos EXW)
  CREATE TEMP TABLE _wf (
    collection text,
    variant_color text,
    sku text,
    display_name text,
    roll_width_in numeric,
    roll_length_ft numeric,
    cost_per_ft numeric
  ) ON COMMIT DROP;

  INSERT INTO _wf VALUES
    -- OPTIVISION — models 25, 35, 45 — Neutral — 48/60/72
    ('Optivision 25','Neutral','OPTIVISION 25 DA SR-48','Optivision 25',48,100,3.03),
    ('Optivision 25','Neutral','OPTIVISION 25 DA SR-60','Optivision 25',60,100,3.20),
    ('Optivision 25','Neutral','OPTIVISION 25 DA SR-72','Optivision 25',72,100,3.75),
    ('Optivision 35','Neutral','OPTIVISION 35 DA SR-48','Optivision 35',48,100,3.03),
    ('Optivision 35','Neutral','OPTIVISION 35 DA SR-60','Optivision 35',60,100,3.20),
    ('Optivision 35','Neutral','OPTIVISION 35 DA SR-72','Optivision 35',72,100,3.75),
    ('Optivision 45','Neutral','OPTIVISION 45 DA SR-48','Optivision 45',48,100,3.03),
    ('Optivision 45','Neutral','OPTIVISION 45 DA SR-60','Optivision 45',60,100,3.20),
    ('Optivision 45','Neutral','OPTIVISION 45 DA SR-72','Optivision 45',72,100,3.75),

    -- SOLAR GREY — models 20, 35, 55 — Grey — 48/60/72
    ('Solar Grey 20','Grey','SG 20 DA SR-48','Solar Grey 20',48,100,3.63),
    ('Solar Grey 20','Grey','SG 20 DA SR-60','Solar Grey 20',60,100,3.95),
    ('Solar Grey 20','Grey','SG 20 DA SR-72','Solar Grey 20',72,100,4.65),
    ('Solar Grey 35','Grey','SG 35 DA SR-48','Solar Grey 35',48,100,3.63),
    ('Solar Grey 35','Grey','SG 35 DA SR-60','Solar Grey 35',60,100,3.95),
    ('Solar Grey 35','Grey','SG 35 DA SR-72','Solar Grey 35',72,100,4.65),
    ('Solar Grey 55','Grey','SG 55 DA SR-48','Solar Grey 55',48,100,3.63),
    ('Solar Grey 55','Grey','SG 55 DA SR-60','Solar Grey 55',60,100,3.95),
    ('Solar Grey 55','Grey','SG 55 DA SR-72','Solar Grey 55',72,100,4.65),

    -- DURALITE — models 10, 20, 30, 40 — Neutral — 60/72 only
    ('Duralite 10','Neutral','DL 10 DA SR-60','Duralite 10',60,100,5.40),
    ('Duralite 10','Neutral','DL 10 DA SR-72','Duralite 10',72,100,6.39),
    ('Duralite 20','Neutral','DL 20 DA SR-60','Duralite 20',60,100,5.40),
    ('Duralite 20','Neutral','DL 20 DA SR-72','Duralite 20',72,100,6.39),
    ('Duralite 30','Neutral','DL 30 DA SR-60','Duralite 30',60,100,5.40),
    ('Duralite 30','Neutral','DL 30 DA SR-72','Duralite 30',72,100,6.39),
    ('Duralite 40','Neutral','DL 40 DA SR-60','Duralite 40',60,100,5.40),
    ('Duralite 40','Neutral','DL 40 DA SR-72','Duralite 40',72,100,6.39),

    -- ADVANCE CERAMIC — models 3000, 4000, 5000 — Neutral — 48/60/72
    ('Advance Ceramic 3000','Neutral','MAC 3000 PS SR-48','Advance Ceramic 3000',48,100,5.23),
    ('Advance Ceramic 3000','Neutral','MAC 3000 PS SR-60','Advance Ceramic 3000',60,100,5.95),
    ('Advance Ceramic 3000','Neutral','MAC 3000 PS SR-72','Advance Ceramic 3000',72,100,7.05),
    ('Advance Ceramic 4000','Neutral','MAC 4000 PS SR-48','Advance Ceramic 4000',48,100,5.23),
    ('Advance Ceramic 4000','Neutral','MAC 4000 PS SR-60','Advance Ceramic 4000',60,100,5.95),
    ('Advance Ceramic 4000','Neutral','MAC 4000 PS SR-72','Advance Ceramic 4000',72,100,7.05),
    ('Advance Ceramic 5000','Neutral','MAC 5000 PS SR-48','Advance Ceramic 5000',48,100,5.23),
    ('Advance Ceramic 5000','Neutral','MAC 5000 PS SR-60','Advance Ceramic 5000',60,100,5.95),
    ('Advance Ceramic 5000','Neutral','MAC 5000 PS SR-72','Advance Ceramic 5000',72,100,7.05),

    -- SOLAR BRONZE — models 20, 35 — Bronze — 48/60/72
    ('Solar Bronze 20','Bronze','SB 20 E PS SR-48','Solar Bronze 20',48,100,4.27),
    ('Solar Bronze 20','Bronze','SB 20 E PS SR-60','Solar Bronze 20',60,100,4.75),
    ('Solar Bronze 20','Bronze','SB 20 E PS SR-72','Solar Bronze 20',72,100,5.61),
    ('Solar Bronze 35','Bronze','SB 35 E PS SR-48','Solar Bronze 35',48,100,4.27),
    ('Solar Bronze 35','Bronze','SB 35 E PS SR-60','Solar Bronze 35',60,100,4.75),
    ('Solar Bronze 35','Bronze','SB 35 E PS SR-72','Solar Bronze 35',72,100,5.61),

    -- PURELITE — models 40, 60 — Neutral — 48/60/72
    ('PureLite 40','Neutral','PL 40 DA DR-48','PureLite 40',48,100,6.31),
    ('PureLite 40','Neutral','PL 40 DA DR-60','PureLite 40',60,100,7.30),
    ('PureLite 40','Neutral','PL 40 DA DR-72','PureLite 40',72,100,8.67),
    ('PureLite 60','Neutral','PL 60 DA DR-48','PureLite 60',48,100,6.31),
    ('PureLite 60','Neutral','PL 60 DA DR-60','PureLite 60',60,100,7.30),
    ('PureLite 60','Neutral','PL 60 DA DR-72','PureLite 60',72,100,8.67),

    -- NOVA — models 35, 50, 70 — Neutral — 60/72 only
    ('Nova 35','Neutral','NOVA 35 PS SR-60','Nova 35',60,100,5.65),
    ('Nova 35','Neutral','NOVA 35 PS SR-72','Nova 35',72,100,6.69),
    ('Nova 50','Neutral','NOVA 50 PS SR-60','Nova 50',60,100,5.65),
    ('Nova 50','Neutral','NOVA 50 PS SR-72','Nova 50',72,100,6.69),
    ('Nova 70','Neutral','NOVA 70 PS SR-60','Nova 70',60,100,5.65),
    ('Nova 70','Neutral','NOVA 70 PS SR-72','Nova 70',72,100,6.69);

  -- Insert CatalogItems
  INSERT INTO public."CatalogItems" (
    id, organization_id, sku, name,
    collection_name, variant_name,
    category_id,
    measure_basis, purchase_unit, unit_of_measure,
    is_roll, roll_type, roll_pricing_mode,
    roll_width_m, roll_length_m,
    roll_width_value, roll_width_uom,
    roll_length_value, roll_length_uom,
    cost_exw, is_active, item_role,
    manufacturer, manufacturer_id,
    moq
  )
  SELECT
    gen_random_uuid(),
    v_org_id,
    w.sku,
    w.display_name,
    w.collection,
    w.variant_color,
    v_cat_id,
    'linear',
    'roll',
    'm',
    true,
    'window_film',
    'per_square_meter',
    ROUND((w.roll_width_in * 0.0254)::numeric, 4),
    ROUND((w.roll_length_ft * 0.3048)::numeric, 4),
    w.roll_width_in,
    'in',
    w.roll_length_ft,
    'ft',
    w.cost_per_ft,
    true,
    'window_film',
    'Madico',
    v_mfr_id,
    1
  FROM _wf w;

  -- Link to ProductType
  INSERT INTO public."CatalogItemProductTypes" (catalog_item_id, product_type_id, organization_id)
  SELECT ci.id, v_pt_id, v_org_id
  FROM public."CatalogItems" ci
  WHERE ci.item_role = 'window_film'
    AND ci.organization_id = v_org_id
    AND NOT EXISTS (
      SELECT 1 FROM public."CatalogItemProductTypes" cipt
      WHERE cipt.catalog_item_id = ci.id AND cipt.product_type_id = v_pt_id
    );

  -- Supply info: To Order, Import, 45-60 days
  INSERT INTO public."CatalogItemSupply" (catalog_item_id, organization_id, supply_type, supply_origin, lead_time_min_days, lead_time_max_days)
  SELECT ci.id, v_org_id, 'order', 'import', 45, 60
  FROM public."CatalogItems" ci
  WHERE ci.item_role = 'window_film'
    AND ci.organization_id = v_org_id
    AND NOT EXISTS (
      SELECT 1 FROM public."CatalogItemSupply" s
      WHERE s.catalog_item_id = ci.id AND s.organization_id = v_org_id
    );

  -- Compute MSRP for all
  PERFORM public.msrp_compute_for_item(ci.id)
  FROM public."CatalogItems" ci
  WHERE ci.item_role = 'window_film'
    AND ci.organization_id = v_org_id;

END $$;
