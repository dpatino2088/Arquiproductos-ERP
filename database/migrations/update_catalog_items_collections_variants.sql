-- ====================================================
-- Auto-generated SQL: Update CatalogItems with Collection and Variant
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total fabrics to update: 565
-- ====================================================

DO $$
DECLARE
    updated_count integer := 0;
BEGIN
    RAISE NOTICE '📝 Updating CatalogItems metadata with collection/variant...';
    RAISE NOTICE '   Processing 565 fabrics...';
    
    -- Update 1 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Block"'), '{variant}', '"cream"')
WHERE sku = 'DRF-BLOCK-0100' AND is_fabric = true AND deleted = false;

    -- Update 2 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Block"'), '{variant}', '"grey"')
WHERE sku = 'DRF-BLOCK-0200' AND is_fabric = true AND deleted = false;

    -- Update 3 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Block"'), '{variant}', '"black"')
WHERE sku = 'DRF-BLOCK-0300' AND is_fabric = true AND deleted = false;

    -- Update 4 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Block"'), '{variant}', '"white/white"')
WHERE sku = 'DRF-BLOCK-0400' AND is_fabric = true AND deleted = false;

    -- Update 5 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Fiji"'), '{variant}', '"white/grey"')
WHERE sku = 'DRF-FIJI-0100' AND is_fabric = true AND deleted = false;

    -- Update 6 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Fiji"'), '{variant}', '"white/sand"')
WHERE sku = 'DRF-FIJI-0200' AND is_fabric = true AND deleted = false;

    -- Update 7 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Fiji"'), '{variant}', '"white/black"')
WHERE sku = 'DRF-FIJI-0300' AND is_fabric = true AND deleted = false;

    -- Update 8 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Fiji"'), '{variant}', '"beige/brown"')
WHERE sku = 'DRF-FIJI-0400' AND is_fabric = true AND deleted = false;

    -- Update 9 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Fiji"'), '{variant}', '"white"')
WHERE sku = 'DRF-FIJI-0600' AND is_fabric = true AND deleted = false;

    -- Update 10 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Honey"'), '{variant}', '"cream"')
WHERE sku = 'DRF-HONEY-0100' AND is_fabric = true AND deleted = false;

    -- Update 11 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Honey"'), '{variant}', '"grey"')
WHERE sku = 'DRF-HONEY-0200' AND is_fabric = true AND deleted = false;

    -- Update 12 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Honey"'), '{variant}', '"black"')
WHERE sku = 'DRF-HONEY-0300' AND is_fabric = true AND deleted = false;

    -- Update 13 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Honey"'), '{variant}', '"pearl"')
WHERE sku = 'DRF-HONEY-0400' AND is_fabric = true AND deleted = false;

    -- Update 14 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"silver"')
WHERE sku = 'DRF-HYDRA-0100' AND is_fabric = true AND deleted = false;

    -- Update 15 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"bronze"')
WHERE sku = 'DRF-HYDRA-0200' AND is_fabric = true AND deleted = false;

    -- Update 16 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"steel"')
WHERE sku = 'DRF-HYDRA-0300' AND is_fabric = true AND deleted = false;

    -- Update 17 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"copper"')
WHERE sku = 'DRF-HYDRA-0400' AND is_fabric = true AND deleted = false;

    -- Update 18 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"brown sugar"')
WHERE sku = 'DRF-HYDRA-0500' AND is_fabric = true AND deleted = false;

    -- Update 19 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hydra"'), '{variant}', '"fossil"')
WHERE sku = 'DRF-HYDRA-0600' AND is_fabric = true AND deleted = false;

    -- Update 20 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"saffron"')
WHERE sku = 'DRF-IKARIA-0100' AND is_fabric = true AND deleted = false;

    -- Update 21 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"grain"')
WHERE sku = 'DRF-IKARIA-0400' AND is_fabric = true AND deleted = false;

    -- Update 22 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"concrete"')
WHERE sku = 'DRF-IKARIA-0500' AND is_fabric = true AND deleted = false;

    -- Update 23 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"charcoal"')
WHERE sku = 'DRF-IKARIA-0600' AND is_fabric = true AND deleted = false;

    -- Update 24 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"sky"')
WHERE sku = 'DRF-IKARIA-0700' AND is_fabric = true AND deleted = false;

    -- Update 25 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ikaria"'), '{variant}', '"white"')
WHERE sku = 'DRF-IKARIA-0900' AND is_fabric = true AND deleted = false;

    -- Update 26 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Madagascar"'), '{variant}', '"grey"')
WHERE sku = 'DRF-MADAGASCAR-0100' AND is_fabric = true AND deleted = false;

    -- Update 27 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Madagascar"'), '{variant}', '"black"')
WHERE sku = 'DRF-MADAGASCAR-0200' AND is_fabric = true AND deleted = false;

    -- Update 28 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Madagascar"'), '{variant}', '"ice"')
WHERE sku = 'DRF-MADAGASCAR-0300' AND is_fabric = true AND deleted = false;

    -- Update 29 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Madagascar"'), '{variant}', '"white"')
WHERE sku = 'DRF-MADAGASCAR-0600' AND is_fabric = true AND deleted = false;

    -- Update 30 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Naxos"'), '{variant}', '"sand"')
WHERE sku = 'DRF-NAXOS-0100' AND is_fabric = true AND deleted = false;

    -- Update 31 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Naxos"'), '{variant}', '"stone"')
WHERE sku = 'DRF-NAXOS-0200' AND is_fabric = true AND deleted = false;

    -- Update 32 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Naxos"'), '{variant}', '"black"')
WHERE sku = 'DRF-NAXOS-0300' AND is_fabric = true AND deleted = false;

    -- Update 33 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Naxos"'), '{variant}', '"chalk"')
WHERE sku = 'DRF-NAXOS-0500' AND is_fabric = true AND deleted = false;

    -- Update 34 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Parga"'), '{variant}', '"cream"')
WHERE sku = 'DRF-PARGA-0100' AND is_fabric = true AND deleted = false;

    -- Update 35 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Parga"'), '{variant}', '"slate"')
WHERE sku = 'DRF-PARGA-0200' AND is_fabric = true AND deleted = false;

    -- Update 36 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Parga"'), '{variant}', '"white"')
WHERE sku = 'DRF-PARGA-0300' AND is_fabric = true AND deleted = false;

    -- Update 37 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Poros"'), '{variant}', '"off white"')
WHERE sku = 'DRF-POROS-5100' AND is_fabric = true AND deleted = false;

    -- Update 38 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Poros"'), '{variant}', '"silver"')
WHERE sku = 'DRF-POROS-5200' AND is_fabric = true AND deleted = false;

    -- Update 39 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Poros"'), '{variant}', '"anthracite"')
WHERE sku = 'DRF-POROS-5300' AND is_fabric = true AND deleted = false;

    -- Update 40 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Poros"'), '{variant}', '"white"')
WHERE sku = 'DRF-POROS-5400' AND is_fabric = true AND deleted = false;

    -- Update 41 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Samos"'), '{variant}', '"natural"')
WHERE sku = 'DRF-SAMOS-0100' AND is_fabric = true AND deleted = false;

    -- Update 42 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Samos"'), '{variant}', '"anthracite"')
WHERE sku = 'DRF-SAMOS-0300' AND is_fabric = true AND deleted = false;

    -- Update 43 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Samos"'), '{variant}', '"light grey"')
WHERE sku = 'DRF-SAMOS-0600' AND is_fabric = true AND deleted = false;

    -- Update 44 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Samos"'), '{variant}', '"white"')
WHERE sku = 'DRF-SAMOS-0900' AND is_fabric = true AND deleted = false;

    -- Update 45 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"cream"')
WHERE sku = 'DRF-SKYROS-S-0100' AND is_fabric = true AND deleted = false;

    -- Update 46 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"silver"')
WHERE sku = 'DRF-SKYROS-S-0200' AND is_fabric = true AND deleted = false;

    -- Update 47 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"iron"')
WHERE sku = 'DRF-SKYROS-S-1400' AND is_fabric = true AND deleted = false;

    -- Update 48 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"black"')
WHERE sku = 'DRF-SKYROS-S-1600' AND is_fabric = true AND deleted = false;

    -- Update 49 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"sesame"')
WHERE sku = 'DRF-SKYROS-S-1700' AND is_fabric = true AND deleted = false;

    -- Update 50 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Skyros"'), '{variant}', '"white"')
WHERE sku = 'DRF-SKYROS-S-2300' AND is_fabric = true AND deleted = false;

    -- Update 51 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Spetses"'), '{variant}', '"crystal"')
WHERE sku = 'DRF-SPETSES-0100' AND is_fabric = true AND deleted = false;

    -- Update 52 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Spetses"'), '{variant}', '"titan"')
WHERE sku = 'DRF-SPETSES-0200' AND is_fabric = true AND deleted = false;

    -- Update 53 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Spetses"'), '{variant}', '"silver"')
WHERE sku = 'DRF-SPETSES-0300' AND is_fabric = true AND deleted = false;

    -- Update 54 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Spetses"'), '{variant}', '"platinum"')
WHERE sku = 'DRF-SPETSES-0400' AND is_fabric = true AND deleted = false;

    -- Update 55 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Spetses"'), '{variant}', '"mushroom"')
WHERE sku = 'DRF-SPETSES-0500' AND is_fabric = true AND deleted = false;

    -- Update 56 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Thasos"'), '{variant}', '"sand"')
WHERE sku = 'DRF-THASOS-0100' AND is_fabric = true AND deleted = false;

    -- Update 57 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Thasos"'), '{variant}', '"charcoal"')
WHERE sku = 'DRF-THASOS-0200' AND is_fabric = true AND deleted = false;

    -- Update 58 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Thasos"'), '{variant}', '"stone"')
WHERE sku = 'DRF-THASOS-0300' AND is_fabric = true AND deleted = false;

    -- Update 59 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Thasos"'), '{variant}', '"bright white"')
WHERE sku = 'DRF-THASOS-0400' AND is_fabric = true AND deleted = false;

    -- Update 60 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"gardenia"')
WHERE sku = 'DRF-ZAKYNTHOS-01-280' AND is_fabric = true AND deleted = false;

    -- Update 61 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"peach"')
WHERE sku = 'DRF-ZAKYNTHOS-02-280' AND is_fabric = true AND deleted = false;

    -- Update 62 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"croissant"')
WHERE sku = 'DRF-ZAKYNTHOS-04-280' AND is_fabric = true AND deleted = false;

    -- Update 63 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"cappuccino"')
WHERE sku = 'DRF-ZAKYNTHOS-05-280' AND is_fabric = true AND deleted = false;

    -- Update 64 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"metal"')
WHERE sku = 'DRF-ZAKYNTHOS-07-280' AND is_fabric = true AND deleted = false;

    -- Update 65 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"steel grey"')
WHERE sku = 'DRF-ZAKYNTHOS-08-280' AND is_fabric = true AND deleted = false;

    -- Update 66 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"pirate black"')
WHERE sku = 'DRF-ZAKYNTHOS-09-280' AND is_fabric = true AND deleted = false;

    -- Update 67 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"dark shadow"')
WHERE sku = 'DRF-ZAKYNTHOS-10-280' AND is_fabric = true AND deleted = false;

    -- Update 68 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"cinder"')
WHERE sku = 'DRF-ZAKYNTHOS-11-280' AND is_fabric = true AND deleted = false;

    -- Update 69 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"blue night"')
WHERE sku = 'DRF-ZAKYNTHOS-12-280' AND is_fabric = true AND deleted = false;

    -- Update 70 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Zakynthos"'), '{variant}', '"white"')
WHERE sku = 'DRF-ZAKYNTHOS-20-280' AND is_fabric = true AND deleted = false;

    -- Update 71 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"brown"')
WHERE sku = 'PF-HC45-BLTMR-563-01' AND is_fabric = true AND deleted = false;

    -- Update 72 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"grey"')
WHERE sku = 'PF-HC45-BLTMR-563-02' AND is_fabric = true AND deleted = false;

    -- Update 73 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"dark grey"')
WHERE sku = 'PF-HC45-BLTMR-563-03' AND is_fabric = true AND deleted = false;

    -- Update 74 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"black"')
WHERE sku = 'PF-HC45-BLTMR-563-04' AND is_fabric = true AND deleted = false;

    -- Update 75 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"ivory"')
WHERE sku = 'PF-HC45-BLTMR-563-05' AND is_fabric = true AND deleted = false;

    -- Update 76 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Baltimore"'), '{variant}', '"beige"')
WHERE sku = 'PF-HC45-BLTMR-563-06' AND is_fabric = true AND deleted = false;

    -- Update 77 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"light grey"')
WHERE sku = 'PF-HC45-DEVON-0300' AND is_fabric = true AND deleted = false;

    -- Update 78 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"cream"')
WHERE sku = 'PF-HC45-DEVON-0400' AND is_fabric = true AND deleted = false;

    -- Update 79 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"oyster"')
WHERE sku = 'PF-HC45-DEVON-0500' AND is_fabric = true AND deleted = false;

    -- Update 80 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"white"')
WHERE sku = 'PF-HC45-DEVON-0600' AND is_fabric = true AND deleted = false;

    -- Update 81 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"brown"')
WHERE sku = 'PF-HC45-DEVON-0700' AND is_fabric = true AND deleted = false;

    -- Update 82 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Devon"'), '{variant}', '"grey"')
WHERE sku = 'PF-HC45-DEVON-0800' AND is_fabric = true AND deleted = false;

    -- Update 83 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"dark grey"')
WHERE sku = 'PF-HC45-DMNTN-5600' AND is_fabric = true AND deleted = false;

    -- Update 84 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"black"')
WHERE sku = 'PF-HC45-DMNTN-5603' AND is_fabric = true AND deleted = false;

    -- Update 85 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"ivory"')
WHERE sku = 'PF-HC45-DMNTN-5609' AND is_fabric = true AND deleted = false;

    -- Update 86 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"beige"')
WHERE sku = 'PF-HC45-DMNTN-5610' AND is_fabric = true AND deleted = false;

    -- Update 87 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"light grey"')
WHERE sku = 'PF-HC45-DMNTN-5611' AND is_fabric = true AND deleted = false;

    -- Update 88 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"cream"')
WHERE sku = 'PF-HC45-DMNTN-5612' AND is_fabric = true AND deleted = false;

    -- Update 89 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"oyster"')
WHERE sku = 'PF-HC45-DMNTN-5613' AND is_fabric = true AND deleted = false;

    -- Update 90 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"sand"')
WHERE sku = 'PF-HC45-DMNTN-5615' AND is_fabric = true AND deleted = false;

    -- Update 91 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"charcoal"')
WHERE sku = 'PF-HC45-DMNTN-5623' AND is_fabric = true AND deleted = false;

    -- Update 92 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"mist"')
WHERE sku = 'PF-HC45-DMNTN-5629' AND is_fabric = true AND deleted = false;

    -- Update 93 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"sky"')
WHERE sku = 'PF-HC45-DMNTN-5650' AND is_fabric = true AND deleted = false;

    -- Update 94 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"sand"')
WHERE sku = 'PF-HC45-DMNTN-5653' AND is_fabric = true AND deleted = false;

    -- Update 95 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"cinder"')
WHERE sku = 'PF-HC45-DMNTN-5659' AND is_fabric = true AND deleted = false;

    -- Update 96 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"storm"')
WHERE sku = 'PF-HC45-DMNTN-5660' AND is_fabric = true AND deleted = false;

    -- Update 97 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"cinder"')
WHERE sku = 'PF-HC45-DMNTN-5661' AND is_fabric = true AND deleted = false;

    -- Update 98 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"storm"')
WHERE sku = 'PF-HC45-DMNTN-5662' AND is_fabric = true AND deleted = false;

    -- Update 99 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"charcoal"')
WHERE sku = 'PF-HC45-DMNTN-5663' AND is_fabric = true AND deleted = false;

    -- Update 100 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"mist"')
WHERE sku = 'PF-HC45-DMNTN-5665' AND is_fabric = true AND deleted = false;

    -- Update 101 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"sky"')
WHERE sku = 'PF-HC45-DMNTN-5673' AND is_fabric = true AND deleted = false;

    -- Update 102 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Edmonton"'), '{variant}', '"lily"')
WHERE sku = 'PF-HC45-DMNTN-5679' AND is_fabric = true AND deleted = false;

    -- Update 103 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"ivory"')
WHERE sku = 'PF-HC45-HALIFAX-0100' AND is_fabric = true AND deleted = false;

    -- Update 104 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"dawn"')
WHERE sku = 'PF-HC45-HALIFAX-0300' AND is_fabric = true AND deleted = false;

    -- Update 105 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"charcoal"')
WHERE sku = 'PF-HC45-HALIFAX-0400' AND is_fabric = true AND deleted = false;

    -- Update 106 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR white"')
WHERE sku = 'PF-HC45-HALIFAX-0500' AND is_fabric = true AND deleted = false;

    -- Update 107 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR dawn"')
WHERE sku = 'PF-HC45-HALIFAX-5100' AND is_fabric = true AND deleted = false;

    -- Update 108 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR mouse"')
WHERE sku = 'PF-HC45-HALIFAX-5247' AND is_fabric = true AND deleted = false;

    -- Update 109 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR smoke"')
WHERE sku = 'PF-HC45-HALIFAX-5249' AND is_fabric = true AND deleted = false;

    -- Update 110 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR white"')
WHERE sku = 'PF-HC45-HALIFAX-5267' AND is_fabric = true AND deleted = false;

    -- Update 111 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR dawn"')
WHERE sku = 'PF-HC45-HALIFAX-5269' AND is_fabric = true AND deleted = false;

    -- Update 112 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR mouse"')
WHERE sku = 'PF-HC45-HALIFAX-5300' AND is_fabric = true AND deleted = false;

    -- Update 113 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"FR smoke"')
WHERE sku = 'PF-HC45-HALIFAX-5400' AND is_fabric = true AND deleted = false;

    -- Update 114 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Halifax"'), '{variant}', '"snow white"')
WHERE sku = 'PF-HC45-HALIFAX-5500' AND is_fabric = true AND deleted = false;

    -- Update 115 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hudson"'), '{variant}', '"beach beige"')
WHERE sku = 'PF-HC45-HDSN-562-01' AND is_fabric = true AND deleted = false;

    -- Update 116 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hudson"'), '{variant}', '"moon rock"')
WHERE sku = 'PF-HC45-HDSN-562-02' AND is_fabric = true AND deleted = false;

    -- Update 117 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hudson"'), '{variant}', '"stone blue"')
WHERE sku = 'PF-HC45-HDSN-562-04' AND is_fabric = true AND deleted = false;

    -- Update 118 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hudson"'), '{variant}', '"pebble"')
WHERE sku = 'PF-HC45-HDSN-562-05' AND is_fabric = true AND deleted = false;

    -- Update 119 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"light grey"')
WHERE sku = 'PF-HC45-LBRT-773-01' AND is_fabric = true AND deleted = false;

    -- Update 120 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"white"')
WHERE sku = 'PF-HC45-LBRT-773-02' AND is_fabric = true AND deleted = false;

    -- Update 121 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"pearl"')
WHERE sku = 'PF-HC45-LBRT-773-03' AND is_fabric = true AND deleted = false;

    -- Update 122 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"dawn"')
WHERE sku = 'PF-HC45-LBRT-773-04' AND is_fabric = true AND deleted = false;

    -- Update 123 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"espresso"')
WHERE sku = 'PF-HC45-LBRT-776-01' AND is_fabric = true AND deleted = false;

    -- Update 124 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"mouse"')
WHERE sku = 'PF-HC45-LBRT-776-02' AND is_fabric = true AND deleted = false;

    -- Update 125 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"white"')
WHERE sku = 'PF-HC45-LBRT-776-03' AND is_fabric = true AND deleted = false;

    -- Update 126 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Liberty"'), '{variant}', '"pearl"')
WHERE sku = 'PF-HC45-LBRT-776-04' AND is_fabric = true AND deleted = false;

    -- Update 127 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"dawn"')
WHERE sku = 'PF-HC45-OXFORD-0100' AND is_fabric = true AND deleted = false;

    -- Update 128 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"espresso"')
WHERE sku = 'PF-HC45-OXFORD-0300' AND is_fabric = true AND deleted = false;

    -- Update 129 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"mouse"')
WHERE sku = 'PF-HC45-OXFORD-0600' AND is_fabric = true AND deleted = false;

    -- Update 130 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"lime"')
WHERE sku = 'PF-HC45-OXFORD-0700' AND is_fabric = true AND deleted = false;

    -- Update 131 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"off-white"')
WHERE sku = 'PF-HC45-OXFORD-0900' AND is_fabric = true AND deleted = false;

    -- Update 132 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Oxford"'), '{variant}', '"shell"')
WHERE sku = 'PF-HC45-OXFORD-1000' AND is_fabric = true AND deleted = false;

    -- Update 133 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"dust"')
WHERE sku = 'PF-HC45-RIOJA0100-36' AND is_fabric = true AND deleted = false;

    -- Update 134 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"bark"')
WHERE sku = 'PF-HC45-RIOJA0110-36' AND is_fabric = true AND deleted = false;

    -- Update 135 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"cement"')
WHERE sku = 'PF-HC45-RIOJA0150-36' AND is_fabric = true AND deleted = false;

    -- Update 136 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"cloud"')
WHERE sku = 'PF-HC45-RIOJA0170-36' AND is_fabric = true AND deleted = false;

    -- Update 137 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"mint"')
WHERE sku = 'PF-HC45-RIOJA0180-36' AND is_fabric = true AND deleted = false;

    -- Update 138 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"sour lime"')
WHERE sku = 'PF-HC45-RIOJA5100-36' AND is_fabric = true AND deleted = false;

    -- Update 139 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"jeans"')
WHERE sku = 'PF-HC45-RIOJA5110-36' AND is_fabric = true AND deleted = false;

    -- Update 140 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"dark coral"')
WHERE sku = 'PF-HC45-RIOJA5150-36' AND is_fabric = true AND deleted = false;

    -- Update 141 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"bark"')
WHERE sku = 'PF-HC45-RIOJA5170-36' AND is_fabric = true AND deleted = false;

    -- Update 142 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"dust"')
WHERE sku = 'PF-HC45-RIOJA5180-36' AND is_fabric = true AND deleted = false;

    -- Update 143 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"off white"')
WHERE sku = 'PF-HC45-RIOJA5240-36' AND is_fabric = true AND deleted = false;

    -- Update 144 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"cement"')
WHERE sku = 'PF-HC45-RIOJA-772-01' AND is_fabric = true AND deleted = false;

    -- Update 145 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"cloud"')
WHERE sku = 'PF-HC45-RIOJA-772-02' AND is_fabric = true AND deleted = false;

    -- Update 146 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"mint"')
WHERE sku = 'PF-HC45-RIOJA-772-04' AND is_fabric = true AND deleted = false;

    -- Update 147 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"shell"')
WHERE sku = 'PF-HC45-RIOJA-772-05' AND is_fabric = true AND deleted = false;

    -- Update 148 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"jeans"')
WHERE sku = 'PF-HC45-RIOJA-772-06' AND is_fabric = true AND deleted = false;

    -- Update 149 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"dark coral"')
WHERE sku = 'PF-HC45-RIOJA-772-07' AND is_fabric = true AND deleted = false;

    -- Update 150 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"bright white"')
WHERE sku = 'PF-HC45-RIOJA-772-08' AND is_fabric = true AND deleted = false;

    -- Update 151 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"biscotti"')
WHERE sku = 'PF-HC45-RIOJA-772-09' AND is_fabric = true AND deleted = false;

    -- Update 152 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"dune"')
WHERE sku = 'PF-HC45-RIOJA-772-10' AND is_fabric = true AND deleted = false;

    -- Update 153 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"chestnut"')
WHERE sku = 'PF-HC45-RIOJA-772-11' AND is_fabric = true AND deleted = false;

    -- Update 154 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"White"')
WHERE sku = 'PF-HC45-RIOJA-775-01' AND is_fabric = true AND deleted = false;

    -- Update 155 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"White"')
WHERE sku = 'PF-HC45-RIOJA-775-02' AND is_fabric = true AND deleted = false;

    -- Update 156 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"White"')
WHERE sku = 'PF-HC45-RIOJA-775-05' AND is_fabric = true AND deleted = false;

    -- Update 157 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Champ. Beige"')
WHERE sku = 'PF-HC45-RIOJA-775-06' AND is_fabric = true AND deleted = false;

    -- Update 158 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Champ. Beige"')
WHERE sku = 'PF-HC45-RIOJA-775-07' AND is_fabric = true AND deleted = false;

    -- Update 159 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Champ. Beige"')
WHERE sku = 'PF-HC45-RIOJA-775-08' AND is_fabric = true AND deleted = false;

    -- Update 160 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Fawn"')
WHERE sku = 'PF-HC45-RIOJA-775-09' AND is_fabric = true AND deleted = false;

    -- Update 161 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Fawn"')
WHERE sku = 'PF-HC45-RIOJA-775-10' AND is_fabric = true AND deleted = false;

    -- Update 162 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Rijoa"'), '{variant}', '"Fawn"')
WHERE sku = 'PF-HC45-RIOJA-775-11' AND is_fabric = true AND deleted = false;

    -- Update 163 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bali"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm bright white"')
WHERE sku = 'RF-BALI-0100' AND is_fabric = true AND deleted = false;

    -- Update 164 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bali"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm biscotti"')
WHERE sku = 'RF-BALI-0300' AND is_fabric = true AND deleted = false;

    -- Update 165 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bali"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm dune"')
WHERE sku = 'RF-BALI-0700' AND is_fabric = true AND deleted = false;

    -- Update 166 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bali"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm chestnut"')
WHERE sku = 'RF-BALI-0800' AND is_fabric = true AND deleted = false;

    -- Update 167 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 183cm x 3000cm White"')
WHERE sku = 'RF-BASIC-BO-01-183-N' AND is_fabric = true AND deleted = false;

    -- Update 168 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 244cm x 3000cm White"')
WHERE sku = 'RF-BASIC-BO-01-244-N' AND is_fabric = true AND deleted = false;

    -- Update 169 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm White"')
WHERE sku = 'RF-BASIC-BO-01-300' AND is_fabric = true AND deleted = false;

    -- Update 170 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 183cm x 3000cm Champ. Beige"')
WHERE sku = 'RF-BASIC-BO-02-183-N' AND is_fabric = true AND deleted = false;

    -- Update 171 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 244cm x 3000cm Champ. Beige"')
WHERE sku = 'RF-BASIC-BO-02-244-N' AND is_fabric = true AND deleted = false;

    -- Update 172 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm Champ. Beige"')
WHERE sku = 'RF-BASIC-BO-02-300' AND is_fabric = true AND deleted = false;

    -- Update 173 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 183cm x 3000cm Fawn"')
WHERE sku = 'RF-BASIC-BO-03-183-N' AND is_fabric = true AND deleted = false;

    -- Update 174 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 244cm x 3000cm Fawn"')
WHERE sku = 'RF-BASIC-BO-03-244-N' AND is_fabric = true AND deleted = false;

    -- Update 175 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm Fawn"')
WHERE sku = 'RF-BASIC-BO-03-300' AND is_fabric = true AND deleted = false;

    -- Update 176 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 183cm x 3000cm Grey"')
WHERE sku = 'RF-BASIC-BO-04-183-N' AND is_fabric = true AND deleted = false;

    -- Update 177 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 244cm x 3000cm Grey"')
WHERE sku = 'RF-BASIC-BO-04-244-N' AND is_fabric = true AND deleted = false;

    -- Update 178 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm Grey"')
WHERE sku = 'RF-BASIC-BO-04-300' AND is_fabric = true AND deleted = false;

    -- Update 179 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"PVC BO 183cm x 3000cm stone"')
WHERE sku = 'RF-BASIC-BO-05-183-N' AND is_fabric = true AND deleted = false;

    -- Update 180 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 244cm x 3000cm stone"')
WHERE sku = 'RF-BASIC-BO-05-244-N' AND is_fabric = true AND deleted = false;

    -- Update 181 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm Stone"')
WHERE sku = 'RF-BASIC-BO-05-300' AND is_fabric = true AND deleted = false;

    -- Update 182 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"PVC BO 183cm x 3000cm black"')
WHERE sku = 'RF-BASIC-BO-06-183-N' AND is_fabric = true AND deleted = false;

    -- Update 183 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"PVC BO 244cm x 3000cm black"')
WHERE sku = 'RF-BASIC-BO-06-244-N' AND is_fabric = true AND deleted = false;

    -- Update 184 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Basic"'), '{variant}', '"Roller blind fabric Plain BO PVC BO 300cm x 2800cm Black"')
WHERE sku = 'RF-BASIC-BO-06-300' AND is_fabric = true AND deleted = false;

    -- Update 185 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Beijing"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm grey"')
WHERE sku = 'RF-BEIJING-01-240' AND is_fabric = true AND deleted = false;

    -- Update 186 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm blanc"')
WHERE sku = 'RF-BERLIN-0100-250' AND is_fabric = true AND deleted = false;

    -- Update 187 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm snow white"')
WHERE sku = 'RF-BERLIN-0120-250' AND is_fabric = true AND deleted = false;

    -- Update 188 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm moth"')
WHERE sku = 'RF-BERLIN-0220-250' AND is_fabric = true AND deleted = false;

    -- Update 189 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm vanilla"')
WHERE sku = 'RF-BERLIN-0300-250' AND is_fabric = true AND deleted = false;

    -- Update 190 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm peach"')
WHERE sku = 'RF-BERLIN-0500-250' AND is_fabric = true AND deleted = false;

    -- Update 191 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm twill"')
WHERE sku = 'RF-BERLIN-0540-250' AND is_fabric = true AND deleted = false;

    -- Update 192 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm metal"')
WHERE sku = 'RF-BERLIN-0600-250' AND is_fabric = true AND deleted = false;

    -- Update 193 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm limestone"')
WHERE sku = 'RF-BERLIN-0610-250' AND is_fabric = true AND deleted = false;

    -- Update 194 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain TR PES 250cm mimosa"')
WHERE sku = 'RF-BERLIN-0800-250' AND is_fabric = true AND deleted = false;

    -- Update 195 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm blue night"')
WHERE sku = 'RF-BERLIN-1000-250' AND is_fabric = true AND deleted = false;

    -- Update 196 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm rust"')
WHERE sku = 'RF-BERLIN-1200-250' AND is_fabric = true AND deleted = false;

    -- Update 197 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm grey"')
WHERE sku = 'RF-BERLIN-1300-250' AND is_fabric = true AND deleted = false;

    -- Update 198 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm black"')
WHERE sku = 'RF-BERLIN-1320-250' AND is_fabric = true AND deleted = false;

    -- Update 199 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm blanc"')
WHERE sku = 'RF-BERLIN-5100-250' AND is_fabric = true AND deleted = false;

    -- Update 200 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm snow white"')
WHERE sku = 'RF-BERLIN-5120-250' AND is_fabric = true AND deleted = false;

    -- Update 201 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm moth"')
WHERE sku = 'RF-BERLIN-5220-250' AND is_fabric = true AND deleted = false;

    -- Update 202 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm vanilla"')
WHERE sku = 'RF-BERLIN-5300-250' AND is_fabric = true AND deleted = false;

    -- Update 203 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm peach"')
WHERE sku = 'RF-BERLIN-5500-250' AND is_fabric = true AND deleted = false;

    -- Update 204 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm twill"')
WHERE sku = 'RF-BERLIN-5540-250' AND is_fabric = true AND deleted = false;

    -- Update 205 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm metal"')
WHERE sku = 'RF-BERLIN-5600-250' AND is_fabric = true AND deleted = false;

    -- Update 206 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm limestone"')
WHERE sku = 'RF-BERLIN-5610-250' AND is_fabric = true AND deleted = false;

    -- Update 207 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm mimosa"')
WHERE sku = 'RF-BERLIN-5800-250' AND is_fabric = true AND deleted = false;

    -- Update 208 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm riviera"')
WHERE sku = 'RF-BERLIN-5900-250' AND is_fabric = true AND deleted = false;

    -- Update 209 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm blue night"')
WHERE sku = 'RF-BERLIN-6000-250' AND is_fabric = true AND deleted = false;

    -- Update 210 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm grey"')
WHERE sku = 'RF-BERLIN-6300-250' AND is_fabric = true AND deleted = false;

    -- Update 211 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Berlin"'), '{variant}', '"Roller blind fabric plain BO PES 250cm black"')
WHERE sku = 'RF-BERLIN-6320-250' AND is_fabric = true AND deleted = false;

    -- Update 212 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm white"')
WHERE sku = 'RF-BOMBAY-0100' AND is_fabric = true AND deleted = false;

    -- Update 213 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm natural"')
WHERE sku = 'RF-BOMBAY-0300' AND is_fabric = true AND deleted = false;

    -- Update 214 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm sand"')
WHERE sku = 'RF-BOMBAY-0400' AND is_fabric = true AND deleted = false;

    -- Update 215 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm bean"')
WHERE sku = 'RF-BOMBAY-0600' AND is_fabric = true AND deleted = false;

    -- Update 216 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm moth"')
WHERE sku = 'RF-BOMBAY-0700' AND is_fabric = true AND deleted = false;

    -- Update 217 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Bombay"'), '{variant}', '"Roller blind fabric Nature SH 240cm mist"')
WHERE sku = 'RF-BOMBAY-0800' AND is_fabric = true AND deleted = false;

    -- Update 218 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Brasilia"'), '{variant}', '"Roller blind fabric Texture LF PES TREVIRA CS 300cm twill"')
WHERE sku = 'RF-BRASILIA-0200' AND is_fabric = true AND deleted = false;

    -- Update 219 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Brasilia"'), '{variant}', '"Roller blind fabric Texture LF PES TREVIRA CS 300cm steel"')
WHERE sku = 'RF-BRASILIA-0500' AND is_fabric = true AND deleted = false;

    -- Update 220 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Brasilia"'), '{variant}', '"Roller blind fabric Texture LF PES TREV CS 300cm steeple grey"')
WHERE sku = 'RF-BRASILIA-0600' AND is_fabric = true AND deleted = false;

    -- Update 221 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Brasilia"'), '{variant}', '"Roller blind fabric Texture LF PES TREVIRA CS 300cm raven"')
WHERE sku = 'RF-BRASILIA-0800' AND is_fabric = true AND deleted = false;

    -- Update 222 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm white"')
WHERE sku = 'RF-COMO-5100' AND is_fabric = true AND deleted = false;

    -- Update 223 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm shell"')
WHERE sku = 'RF-COMO-5300' AND is_fabric = true AND deleted = false;

    -- Update 224 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm sesame"')
WHERE sku = 'RF-COMO-5500' AND is_fabric = true AND deleted = false;

    -- Update 225 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm chanterelle"')
WHERE sku = 'RF-COMO-5600' AND is_fabric = true AND deleted = false;

    -- Update 226 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm sand"')
WHERE sku = 'RF-COMO-5700' AND is_fabric = true AND deleted = false;

    -- Update 227 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Como"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm mist"')
WHERE sku = 'RF-COMO-5800' AND is_fabric = true AND deleted = false;

    -- Update 228 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm cloud"')
WHERE sku = 'RF-DARWIN-5100' AND is_fabric = true AND deleted = false;

    -- Update 229 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm sand"')
WHERE sku = 'RF-DARWIN-5200' AND is_fabric = true AND deleted = false;

    -- Update 230 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm taupe"')
WHERE sku = 'RF-DARWIN-5300' AND is_fabric = true AND deleted = false;

    -- Update 231 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm black"')
WHERE sku = 'RF-DARWIN-5400' AND is_fabric = true AND deleted = false;

    -- Update 232 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm indigo"')
WHERE sku = 'RF-DARWIN-5500' AND is_fabric = true AND deleted = false;

    -- Update 233 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Darwin"'), '{variant}', '"Roller blind fabric Texture BO PES  280cm aubergine"')
WHERE sku = 'RF-DARWIN-5600' AND is_fabric = true AND deleted = false;

    -- Update 234 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Durban"'), '{variant}', '"Roller blind fabric Texture LF  PES 280 cm grain"')
WHERE sku = 'RF-DURBAN-0100' AND is_fabric = true AND deleted = false;

    -- Update 235 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Durban"'), '{variant}', '"Roller blind fabric Texture LF  PES 280 cm  bark"')
WHERE sku = 'RF-DURBAN-0200' AND is_fabric = true AND deleted = false;

    -- Update 236 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Durban"'), '{variant}', '"Roller blind fabric Texture LF  PES 280 cm charcoal"')
WHERE sku = 'RF-DURBAN-0300' AND is_fabric = true AND deleted = false;

    -- Update 237 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Durban"'), '{variant}', '"Roller blind fabric Texture LF  PES 280 cm mist"')
WHERE sku = 'RF-DURBAN-0400' AND is_fabric = true AND deleted = false;

    -- Update 238 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm snow white"')
WHERE sku = 'RF-EKO50-0100' AND is_fabric = true AND deleted = false;

    -- Update 239 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm pearled ivory"')
WHERE sku = 'RF-EKO50-0400' AND is_fabric = true AND deleted = false;

    -- Update 240 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm pale khaki"')
WHERE sku = 'RF-EKO50-0700' AND is_fabric = true AND deleted = false;

    -- Update 241 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm inda ink"')
WHERE sku = 'RF-EKO50-1900' AND is_fabric = true AND deleted = false;

    -- Update 242 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm silver cloud"')
WHERE sku = 'RF-EKO50-2000' AND is_fabric = true AND deleted = false;

    -- Update 243 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm atmosphere"')
WHERE sku = 'RF-EKO50-2100' AND is_fabric = true AND deleted = false;

    -- Update 244 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm cinder"')
WHERE sku = 'RF-EKO50-2200' AND is_fabric = true AND deleted = false;

    -- Update 245 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm caviar"')
WHERE sku = 'RF-EKO50-2300' AND is_fabric = true AND deleted = false;

    -- Update 246 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Eko"'), '{variant}', '"Roller blind fabric Texture LF PES 210cm limestone"')
WHERE sku = 'RF-EKO50-2400' AND is_fabric = true AND deleted = false;

    -- Update 247 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm blanc"')
WHERE sku = 'RF-ESVEDRA-0100-280' AND is_fabric = true AND deleted = false;

    -- Update 248 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm vanilla"')
WHERE sku = 'RF-ESVEDRA-0200-280' AND is_fabric = true AND deleted = false;

    -- Update 249 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm metal"')
WHERE sku = 'RF-ESVEDRA-3000-280' AND is_fabric = true AND deleted = false;

    -- Update 250 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm cinder"')
WHERE sku = 'RF-ESVEDRA-3200-280' AND is_fabric = true AND deleted = false;

    -- Update 251 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm dark shadow"')
WHERE sku = 'RF-ESVEDRA-3300-280' AND is_fabric = true AND deleted = false;

    -- Update 252 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm castle rock"')
WHERE sku = 'RF-ESVEDRA-3400-280' AND is_fabric = true AND deleted = false;

    -- Update 253 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm feather"')
WHERE sku = 'RF-ESVEDRA-3500-280' AND is_fabric = true AND deleted = false;

    -- Update 254 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Esvedra"'), '{variant}', '"Roller blind fabric Plain SH PES 280cm mushroom"')
WHERE sku = 'RF-ESVEDRA-3600-280' AND is_fabric = true AND deleted = false;

    -- Update 255 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Gunsang"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm pearl"')
WHERE sku = 'RF-GUNSANG-0100' AND is_fabric = true AND deleted = false;

    -- Update 256 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Gunsang"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 200cm pearl"')
WHERE sku = 'RF-GUNSANGSPNGL-0100' AND is_fabric = true AND deleted = false;

    -- Update 257 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm light grey"')
WHERE sku = 'RF-HAMPTON-0100' AND is_fabric = true AND deleted = false;

    -- Update 258 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm white"')
WHERE sku = 'RF-HAMPTON-0150' AND is_fabric = true AND deleted = false;

    -- Update 259 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm sand"')
WHERE sku = 'RF-HAMPTON-0200' AND is_fabric = true AND deleted = false;

    -- Update 260 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm beige"')
WHERE sku = 'RF-HAMPTON-0300' AND is_fabric = true AND deleted = false;

    -- Update 261 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm antra"')
WHERE sku = 'RF-HAMPTON-0400' AND is_fabric = true AND deleted = false;

    -- Update 262 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture SH PES 280 cm off white"')
WHERE sku = 'RF-HAMPTON-0500' AND is_fabric = true AND deleted = false;

    -- Update 263 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm light grey"')
WHERE sku = 'RF-HAMPTON-5100' AND is_fabric = true AND deleted = false;

    -- Update 264 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm white"')
WHERE sku = 'RF-HAMPTON-5150' AND is_fabric = true AND deleted = false;

    -- Update 265 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm sand"')
WHERE sku = 'RF-HAMPTON-5200' AND is_fabric = true AND deleted = false;

    -- Update 266 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm beige"')
WHERE sku = 'RF-HAMPTON-5300' AND is_fabric = true AND deleted = false;

    -- Update 267 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm antra"')
WHERE sku = 'RF-HAMPTON-5400' AND is_fabric = true AND deleted = false;

    -- Update 268 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hampton"'), '{variant}', '"Roller blind fabric Texture BO  PES 280 cm off white"')
WHERE sku = 'RF-HAMPTON-5500' AND is_fabric = true AND deleted = false;

    -- Update 269 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hong Kong"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 180cm natural"')
WHERE sku = 'RF-HONGKONG-01' AND is_fabric = true AND deleted = false;

    -- Update 270 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hueva"'), '{variant}', '"Roller blind fabric Nature SH 240cm vanilla"')
WHERE sku = 'RF-HUEVA-0100' AND is_fabric = true AND deleted = false;

    -- Update 271 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hueva"'), '{variant}', '"Roller blind fabric Nature SH 240cm straw"')
WHERE sku = 'RF-HUEVA-0200' AND is_fabric = true AND deleted = false;

    -- Update 272 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hueva"'), '{variant}', '"Roller blind fabric Nature SH 240cm sand"')
WHERE sku = 'RF-HUEVA-0300' AND is_fabric = true AND deleted = false;

    -- Update 273 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hueva"'), '{variant}', '"Roller blind fabric Nature SH 240cm metal"')
WHERE sku = 'RF-HUEVA-0400' AND is_fabric = true AND deleted = false;

    -- Update 274 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Hueva"'), '{variant}', '"Roller blind fabric Nature SH 240cm ink"')
WHERE sku = 'RF-HUEVA-0500' AND is_fabric = true AND deleted = false;

    -- Update 275 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jacquard�"'), '{variant}', '"Roller blind fabric jacquard SH PES 280cm white"')
WHERE sku = 'RF-JA21001-001' AND is_fabric = true AND deleted = false;

    -- Update 276 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jacquard�"'), '{variant}', '"Roller blind fabric jacquard SH PES 280cm ivory"')
WHERE sku = 'RF-JA21001-002' AND is_fabric = true AND deleted = false;

    -- Update 277 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jacquard�"'), '{variant}', '"Roller blind fabric jacquard SH PES 280cm light grey"')
WHERE sku = 'RF-JA21001-003' AND is_fabric = true AND deleted = false;

    -- Update 278 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jacquard�"'), '{variant}', '"Roller blind fabric jacquard SH PES 280cm dark grey"')
WHERE sku = 'RF-JA21001-004' AND is_fabric = true AND deleted = false;

    -- Update 279 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Aretha"'), '{variant}', '"Roller blind fabric Jacquard LF PES 240cm white"')
WHERE sku = 'RF-JA-ARETHA-0100' AND is_fabric = true AND deleted = false;

    -- Update 280 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Aretha"'), '{variant}', '"Roller blind fabric Jacquard LF PES 240cm off-white"')
WHERE sku = 'RF-JA-ARETHA-0200' AND is_fabric = true AND deleted = false;

    -- Update 281 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Aretha"'), '{variant}', '"Roller blind fabric Jacquard LF PES 240cm cream"')
WHERE sku = 'RF-JA-ARETHA-0300' AND is_fabric = true AND deleted = false;

    -- Update 282 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Aretha"'), '{variant}', '"Roller blind fabric Jacquard LF PES 240cm grey"')
WHERE sku = 'RF-JA-ARETHA-0500' AND is_fabric = true AND deleted = false;

    -- Update 283 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Aretha"'), '{variant}', '"Roller blind fabric Jacquard LF PES 240cm dark grey"')
WHERE sku = 'RF-JA-ARETHA-0800' AND is_fabric = true AND deleted = false;

    -- Update 284 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jinju"'), '{variant}', '"Roller blind fabric Nature LF PAP JUT 200cm grey"')
WHERE sku = 'RF-JINJU-0100' AND is_fabric = true AND deleted = false;

    -- Update 285 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jinju"'), '{variant}', '"Roller blind fabric Nature LF PAP JUT 200cm sand"')
WHERE sku = 'RF-JINJU-0200' AND is_fabric = true AND deleted = false;

    -- Update 286 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Jinju"'), '{variant}', '"Roller blind fabric Nature LF PAP JUT 200cm sun"')
WHERE sku = 'RF-JINJU-0300' AND is_fabric = true AND deleted = false;

    -- Update 287 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lf Jtu Pes"'), '{variant}', '"Roller blind fabric Nature LF JUT PES 180cm beige"')
WHERE sku = 'RF-LIN2' AND is_fabric = true AND deleted = false;

    -- Update 288 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lf Jtu Pes"'), '{variant}', '"Roller blind fabric Nature LF JUT PES 180cm black"')
WHERE sku = 'RF-LIN3' AND is_fabric = true AND deleted = false;

    -- Update 289 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lisboa"'), '{variant}', '"Roller blind fabric Texture BO PES 280cm white"')
WHERE sku = 'RF-LISBOA-5100' AND is_fabric = true AND deleted = false;

    -- Update 290 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lisboa"'), '{variant}', '"Roller blind fabric Texture BO PES 280cm mist"')
WHERE sku = 'RF-LISBOA-5400' AND is_fabric = true AND deleted = false;

    -- Update 291 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lisboa"'), '{variant}', '"Roller blind fabric Texture BO PES 280cm dust"')
WHERE sku = 'RF-LISBOA-5500' AND is_fabric = true AND deleted = false;

    -- Update 292 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lisboa"'), '{variant}', '"Roller blind fabric Texture BO PES 280cm buffalo"')
WHERE sku = 'RF-LISBOA-5600' AND is_fabric = true AND deleted = false;

    -- Update 293 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lisboa"'), '{variant}', '"Roller blind fabric Texture BO PES 280cm cacoa"')
WHERE sku = 'RF-LISBOA-5700' AND is_fabric = true AND deleted = false;

    -- Update 294 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm white"')
WHERE sku = 'RF-MELBOURNE-0100' AND is_fabric = true AND deleted = false;

    -- Update 295 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm sand"')
WHERE sku = 'RF-MELBOURNE-0300' AND is_fabric = true AND deleted = false;

    -- Update 296 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm mocca"')
WHERE sku = 'RF-MELBOURNE-0400' AND is_fabric = true AND deleted = false;

    -- Update 297 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm mist"')
WHERE sku = 'RF-MELBOURNE-0500' AND is_fabric = true AND deleted = false;

    -- Update 298 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm ash"')
WHERE sku = 'RF-MELBOURNE-0600' AND is_fabric = true AND deleted = false;

    -- Update 299 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm charcoal"')
WHERE sku = 'RF-MELBOURNE-0700' AND is_fabric = true AND deleted = false;

    -- Update 300 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm grain"')
WHERE sku = 'RF-MELBOURNE-0800' AND is_fabric = true AND deleted = false;

    -- Update 301 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Melbourne"'), '{variant}', '"Roller blind fabric Texture SH Trevira CS 300 cm jeans"')
WHERE sku = 'RF-MELBOURNE-0900' AND is_fabric = true AND deleted = false;

    -- Update 302 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mexico"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm sand"')
WHERE sku = 'RF-MEXICO-5102' AND is_fabric = true AND deleted = false;

    -- Update 303 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mexico"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm coffee"')
WHERE sku = 'RF-MEXICO-5105' AND is_fabric = true AND deleted = false;

    -- Update 304 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mexico"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm ash"')
WHERE sku = 'RF-MEXICO-5106' AND is_fabric = true AND deleted = false;

    -- Update 305 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mexico"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm slate"')
WHERE sku = 'RF-MEXICO-5107' AND is_fabric = true AND deleted = false;

    -- Update 306 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm white"')
WHERE sku = 'RF-MIAMI-5100' AND is_fabric = true AND deleted = false;

    -- Update 307 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm pearl"')
WHERE sku = 'RF-MIAMI-5200' AND is_fabric = true AND deleted = false;

    -- Update 308 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm cream"')
WHERE sku = 'RF-MIAMI-5300' AND is_fabric = true AND deleted = false;

    -- Update 309 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm sand"')
WHERE sku = 'RF-MIAMI-5500' AND is_fabric = true AND deleted = false;

    -- Update 310 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm black"')
WHERE sku = 'RF-MIAMI-6000' AND is_fabric = true AND deleted = false;

    -- Update 311 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm steel grey"')
WHERE sku = 'RF-MIAMI-6100' AND is_fabric = true AND deleted = false;

    -- Update 312 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Miami"'), '{variant}', '"Roller blind fabric Texture BO PES FR 280cm mist"')
WHERE sku = 'RF-MIAMI-6200' AND is_fabric = true AND deleted = false;

    -- Update 313 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm sand"')
WHERE sku = 'RF-MOMBASSA-0100' AND is_fabric = true AND deleted = false;

    -- Update 314 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm snow"')
WHERE sku = 'RF-MOMBASSA-0150' AND is_fabric = true AND deleted = false;

    -- Update 315 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm oyster"')
WHERE sku = 'RF-MOMBASSA-0200' AND is_fabric = true AND deleted = false;

    -- Update 316 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm dust"')
WHERE sku = 'RF-MOMBASSA-0300' AND is_fabric = true AND deleted = false;

    -- Update 317 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm ink"')
WHERE sku = 'RF-MOMBASSA-0400' AND is_fabric = true AND deleted = false;

    -- Update 318 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm ash"')
WHERE sku = 'RF-MOMBASSA-0500' AND is_fabric = true AND deleted = false;

    -- Update 319 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture LF PES 300cm grain"')
WHERE sku = 'RF-MOMBASSA-0600' AND is_fabric = true AND deleted = false;

    -- Update 320 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm sand"')
WHERE sku = 'RF-MOMBASSA-5100' AND is_fabric = true AND deleted = false;

    -- Update 321 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm snow"')
WHERE sku = 'RF-MOMBASSA-5150' AND is_fabric = true AND deleted = false;

    -- Update 322 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm oyster"')
WHERE sku = 'RF-MOMBASSA-5200' AND is_fabric = true AND deleted = false;

    -- Update 323 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm dust"')
WHERE sku = 'RF-MOMBASSA-5300' AND is_fabric = true AND deleted = false;

    -- Update 324 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm ink"')
WHERE sku = 'RF-MOMBASSA-5400' AND is_fabric = true AND deleted = false;

    -- Update 325 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm ash"')
WHERE sku = 'RF-MOMBASSA-5500' AND is_fabric = true AND deleted = false;

    -- Update 326 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Mombassa"'), '{variant}', '"Roller blind fabric Texture BO PES 300cm grain"')
WHERE sku = 'RF-MOMBASSA-5600' AND is_fabric = true AND deleted = false;

    -- Update 327 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm snow white"')
WHERE sku = 'RF-MUENCHEN-0150' AND is_fabric = true AND deleted = false;

    -- Update 328 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm snow white"')
WHERE sku = 'RF-MUENCHEN-0150-300' AND is_fabric = true AND deleted = false;

    -- Update 329 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm grey anthracite"')
WHERE sku = 'RF-MUENCHEN-0301' AND is_fabric = true AND deleted = false;

    -- Update 330 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm grey anthracite"')
WHERE sku = 'RF-MUENCHEN-0301-300' AND is_fabric = true AND deleted = false;

    -- Update 331 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm bleached sand"')
WHERE sku = 'RF-MUENCHEN-0401' AND is_fabric = true AND deleted = false;

    -- Update 332 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm bleached sand"')
WHERE sku = 'RF-MUENCHEN-0401-300' AND is_fabric = true AND deleted = false;

    -- Update 333 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm lime stone"')
WHERE sku = 'RF-MUENCHEN-1002' AND is_fabric = true AND deleted = false;

    -- Update 334 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm lime stone"')
WHERE sku = 'RF-MUENCHEN-1002-300' AND is_fabric = true AND deleted = false;

    -- Update 335 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm oyster grey"')
WHERE sku = 'RF-MUENCHEN-2700' AND is_fabric = true AND deleted = false;

    -- Update 336 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm oyster grey"')
WHERE sku = 'RF-MUENCHEN-2700-300' AND is_fabric = true AND deleted = false;

    -- Update 337 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm dark shadow"')
WHERE sku = 'RF-MUENCHEN-4301' AND is_fabric = true AND deleted = false;

    -- Update 338 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm dark shadow"')
WHERE sku = 'RF-MUENCHEN-4301-300' AND is_fabric = true AND deleted = false;

    -- Update 339 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm moth"')
WHERE sku = 'RF-MUENCHEN-4400' AND is_fabric = true AND deleted = false;

    -- Update 340 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm moth"')
WHERE sku = 'RF-MUENCHEN-4400-300' AND is_fabric = true AND deleted = false;

    -- Update 341 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 200cm clay"')
WHERE sku = 'RF-MUENCHEN-4601' AND is_fabric = true AND deleted = false;

    -- Update 342 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric Plain LF PES 300cm clay"')
WHERE sku = 'RF-MUENCHEN-4601-300' AND is_fabric = true AND deleted = false;

    -- Update 343 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm lime stone"')
WHERE sku = 'RF-MUENCHEN-5001' AND is_fabric = true AND deleted = false;

    -- Update 344 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm lime stone"')
WHERE sku = 'RF-MUENCHEN-5001-300' AND is_fabric = true AND deleted = false;

    -- Update 345 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm grey anthracite"')
WHERE sku = 'RF-MUENCHEN-5300' AND is_fabric = true AND deleted = false;

    -- Update 346 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm grey anthracite"')
WHERE sku = 'RF-MUENCHEN-5300-300' AND is_fabric = true AND deleted = false;

    -- Update 347 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm bleached sand"')
WHERE sku = 'RF-MUENCHEN-5401' AND is_fabric = true AND deleted = false;

    -- Update 348 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm bleached sand"')
WHERE sku = 'RF-MUENCHEN-5401-300' AND is_fabric = true AND deleted = false;

    -- Update 349 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm snow white"')
WHERE sku = 'RF-MUENCHEN-6250' AND is_fabric = true AND deleted = false;

    -- Update 350 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm snow white"')
WHERE sku = 'RF-MUENCHEN-6250-300' AND is_fabric = true AND deleted = false;

    -- Update 351 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm dark shadow"')
WHERE sku = 'RF-MUENCHEN-6301' AND is_fabric = true AND deleted = false;

    -- Update 352 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm dark shadow"')
WHERE sku = 'RF-MUENCHEN-6301-300' AND is_fabric = true AND deleted = false;

    -- Update 353 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm moth"')
WHERE sku = 'RF-MUENCHEN-6400' AND is_fabric = true AND deleted = false;

    -- Update 354 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm moth"')
WHERE sku = 'RF-MUENCHEN-6400-300' AND is_fabric = true AND deleted = false;

    -- Update 355 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm clay"')
WHERE sku = 'RF-MUENCHEN-7600' AND is_fabric = true AND deleted = false;

    -- Update 356 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm clay"')
WHERE sku = 'RF-MUENCHEN-7600-300' AND is_fabric = true AND deleted = false;

    -- Update 357 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 200cm oyster grey"')
WHERE sku = 'RF-MUENCHEN-7700' AND is_fabric = true AND deleted = false;

    -- Update 358 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Muenchen"'), '{variant}', '"Roller blind fabric plain BO PES 300cm oyster grey"')
WHERE sku = 'RF-MUENCHEN-7700-300' AND is_fabric = true AND deleted = false;

    -- Update 359 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm bright white"')
WHERE sku = 'RF-NATAL-0150' AND is_fabric = true AND deleted = false;

    -- Update 360 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm star white"')
WHERE sku = 'RF-NATAL-0200' AND is_fabric = true AND deleted = false;

    -- Update 361 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm moonbeam"')
WHERE sku = 'RF-NATAL-0400' AND is_fabric = true AND deleted = false;

    -- Update 362 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm oyster grey"')
WHERE sku = 'RF-NATAL-0500' AND is_fabric = true AND deleted = false;

    -- Update 363 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm moon mist"')
WHERE sku = 'RF-NATAL-0600' AND is_fabric = true AND deleted = false;

    -- Update 364 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm jet set"')
WHERE sku = 'RF-NATAL-0700' AND is_fabric = true AND deleted = false;

    -- Update 365 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric Plain LF PES 250cm black coffee"')
WHERE sku = 'RF-NATAL-0900' AND is_fabric = true AND deleted = false;

    -- Update 366 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm bright white"')
WHERE sku = 'RF-NATAL-5150' AND is_fabric = true AND deleted = false;

    -- Update 367 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm star white"')
WHERE sku = 'RF-NATAL-5200' AND is_fabric = true AND deleted = false;

    -- Update 368 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm moonbeam"')
WHERE sku = 'RF-NATAL-5400' AND is_fabric = true AND deleted = false;

    -- Update 369 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm oyster grey"')
WHERE sku = 'RF-NATAL-5500' AND is_fabric = true AND deleted = false;

    -- Update 370 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm moon mist"')
WHERE sku = 'RF-NATAL-5600' AND is_fabric = true AND deleted = false;

    -- Update 371 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm jet set"')
WHERE sku = 'RF-NATAL-5700' AND is_fabric = true AND deleted = false;

    -- Update 372 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Natal"'), '{variant}', '"Roller blind fabric plain BO PES 250cm black coffee"')
WHERE sku = 'RF-NATAL-5900' AND is_fabric = true AND deleted = false;

    -- Update 373 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Osaka"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 185cm stone"')
WHERE sku = 'RF-OSAKA-0100-185' AND is_fabric = true AND deleted = false;

    -- Update 374 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Osaka"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 185cm latte"')
WHERE sku = 'RF-OSAKA-0300-185' AND is_fabric = true AND deleted = false;

    -- Update 375 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Osaka"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 185cm mocha"')
WHERE sku = 'RF-OSAKA-0400-185' AND is_fabric = true AND deleted = false;

    -- Update 376 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Sh Pap Pes"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm white"')
WHERE sku = 'RF-PAP2-240' AND is_fabric = true AND deleted = false;

    -- Update 377 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Sh Pap Pes"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm natural"')
WHERE sku = 'RF-PAP3-240' AND is_fabric = true AND deleted = false;

    -- Update 378 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Sh Pap Pes"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm sand"')
WHERE sku = 'RF-PAP7-240' AND is_fabric = true AND deleted = false;

    -- Update 379 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm blanc"')
WHERE sku = 'RF-PARIS-0100-300' AND is_fabric = true AND deleted = false;

    -- Update 380 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm gardenia"')
WHERE sku = 'RF-PARIS-0150-300' AND is_fabric = true AND deleted = false;

    -- Update 381 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm buff"')
WHERE sku = 'RF-PARIS-0400-300' AND is_fabric = true AND deleted = false;

    -- Update 382 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm dove"')
WHERE sku = 'RF-PARIS-3300-300' AND is_fabric = true AND deleted = false;

    -- Update 383 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREV. CS 300cm steel grey"')
WHERE sku = 'RF-PARIS-3400-300' AND is_fabric = true AND deleted = false;

    -- Update 384 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm caviar"')
WHERE sku = 'RF-PARIS-3500-300' AND is_fabric = true AND deleted = false;

    -- Update 385 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm twill"')
WHERE sku = 'RF-PARIS-3800-300' AND is_fabric = true AND deleted = false;

    -- Update 386 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Paris"'), '{variant}', '"Roller blind fabric Plain SH PES TREVIRA CS 300cm raven"')
WHERE sku = 'RF-PARIS-4200-300' AND is_fabric = true AND deleted = false;

    -- Update 387 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lf Pes"'), '{variant}', '"Roller blind fabric Print LF PES 240 cm  sand"')
WHERE sku = 'RF-PR180660-0100' AND is_fabric = true AND deleted = false;

    -- Update 388 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lf Pes"'), '{variant}', '"Roller blind fabric Print LF PES 240 cm  taupe"')
WHERE sku = 'RF-PR180660-0200' AND is_fabric = true AND deleted = false;

    -- Update 389 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Lf Pes"'), '{variant}', '"Roller blind fabric Print LF PES 240 cm moth"')
WHERE sku = 'RF-PR180660-0300' AND is_fabric = true AND deleted = false;

    -- Update 390 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm white"')
WHERE sku = 'RF-RICHMOND-0100' AND is_fabric = true AND deleted = false;

    -- Update 391 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm cream"')
WHERE sku = 'RF-RICHMOND-0200' AND is_fabric = true AND deleted = false;

    -- Update 392 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm sand"')
WHERE sku = 'RF-RICHMOND-0300' AND is_fabric = true AND deleted = false;

    -- Update 393 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm mist"')
WHERE sku = 'RF-RICHMOND-0500' AND is_fabric = true AND deleted = false;

    -- Update 394 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm bison"')
WHERE sku = 'RF-RICHMOND-0700' AND is_fabric = true AND deleted = false;

    -- Update 395 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm castle rock"')
WHERE sku = 'RF-RICHMOND-0900' AND is_fabric = true AND deleted = false;

    -- Update 396 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Richmond"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm frost"')
WHERE sku = 'RF-RICHMOND-1000' AND is_fabric = true AND deleted = false;

    -- Update 397 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Saigon"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm natural"')
WHERE sku = 'RF-SAIGON-0100' AND is_fabric = true AND deleted = false;

    -- Update 398 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Saigon"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm sand"')
WHERE sku = 'RF-SAIGON-0200' AND is_fabric = true AND deleted = false;

    -- Update 399 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Saigon"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm dark brown"')
WHERE sku = 'RF-SAIGON-0300' AND is_fabric = true AND deleted = false;

    -- Update 400 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Saigon"'), '{variant}', '"Roller blind fabric Nature SH PAP PES 240cm black"')
WHERE sku = 'RF-SAIGON-0500' AND is_fabric = true AND deleted = false;

    -- Update 401 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm optical white"')
WHERE sku = 'RF-SALVADOR-0100' AND is_fabric = true AND deleted = false;

    -- Update 402 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm white"')
WHERE sku = 'RF-SALVADOR-0200' AND is_fabric = true AND deleted = false;

    -- Update 403 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm cream"')
WHERE sku = 'RF-SALVADOR-0300' AND is_fabric = true AND deleted = false;

    -- Update 404 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm beige"')
WHERE sku = 'RF-SALVADOR-0500' AND is_fabric = true AND deleted = false;

    -- Update 405 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm stone"')
WHERE sku = 'RF-SALVADOR-0700' AND is_fabric = true AND deleted = false;

    -- Update 406 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm slate"')
WHERE sku = 'RF-SALVADOR-0800' AND is_fabric = true AND deleted = false;

    -- Update 407 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm black"')
WHERE sku = 'RF-SALVADOR-1100' AND is_fabric = true AND deleted = false;

    -- Update 408 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm dark grey"')
WHERE sku = 'RF-SALVADOR-1300' AND is_fabric = true AND deleted = false;

    -- Update 409 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Salvador"'), '{variant}', '"Roller blind fabric Plain SH TREVIRA CS 240cm grey"')
WHERE sku = 'RF-SALVADOR-1400' AND is_fabric = true AND deleted = false;

    -- Update 410 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm bright white"')
WHERE sku = 'RF-SANTIAGO-5100' AND is_fabric = true AND deleted = false;

    -- Update 411 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm blanc"')
WHERE sku = 'RF-SANTIAGO-5200' AND is_fabric = true AND deleted = false;

    -- Update 412 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm gardenia"')
WHERE sku = 'RF-SANTIAGO-5300' AND is_fabric = true AND deleted = false;

    -- Update 413 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm sand"')
WHERE sku = 'RF-SANTIAGO-5400' AND is_fabric = true AND deleted = false;

    -- Update 414 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm chocolate"')
WHERE sku = 'RF-SANTIAGO-5600' AND is_fabric = true AND deleted = false;

    -- Update 415 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm raven"')
WHERE sku = 'RF-SANTIAGO-5700' AND is_fabric = true AND deleted = false;

    -- Update 416 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm black"')
WHERE sku = 'RF-SANTIAGO-5800' AND is_fabric = true AND deleted = false;

    -- Update 417 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Santiago"'), '{variant}', '"Roller blind fabric plain BO PES FR 280cm metal"')
WHERE sku = 'RF-SANTIAGO-6000' AND is_fabric = true AND deleted = false;

    -- Update 418 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Tokio"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 200cm natural"')
WHERE sku = 'RF-TOKIO-0100' AND is_fabric = true AND deleted = false;

    -- Update 419 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Tokio"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 200cm oak"')
WHERE sku = 'RF-TOKIO-0200' AND is_fabric = true AND deleted = false;

    -- Update 420 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Tokio"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 200cm teak"')
WHERE sku = 'RF-TOKIO-0300' AND is_fabric = true AND deleted = false;

    -- Update 421 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Tokio"'), '{variant}', '"Roller blind fabric Nature LF PAP PES 200cm palisander"')
WHERE sku = 'RF-TOKIO-0400' AND is_fabric = true AND deleted = false;

    -- Update 422 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Toulouse"'), '{variant}', '"Roller blind fabric Texture LF PES 280cm flour"')
WHERE sku = 'RF-TOULOUSE-0100' AND is_fabric = true AND deleted = false;

    -- Update 423 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Toulouse"'), '{variant}', '"Roller blind fabric Texture BO PES 280 cm flour"')
WHERE sku = 'RF-TOULOUSE-5100' AND is_fabric = true AND deleted = false;

    -- Update 424 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm natural"')
WHERE sku = 'RF-UBUD-0100' AND is_fabric = true AND deleted = false;

    -- Update 425 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm fossil"')
WHERE sku = 'RF-UBUD-0200' AND is_fabric = true AND deleted = false;

    -- Update 426 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm sand"')
WHERE sku = 'RF-UBUD-0300' AND is_fabric = true AND deleted = false;

    -- Update 427 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm bean"')
WHERE sku = 'RF-UBUD-0400' AND is_fabric = true AND deleted = false;

    -- Update 428 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm wood"')
WHERE sku = 'RF-UBUD-0500' AND is_fabric = true AND deleted = false;

    -- Update 429 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm smoke"')
WHERE sku = 'RF-UBUD-0600' AND is_fabric = true AND deleted = false;

    -- Update 430 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm charcoal"')
WHERE sku = 'RF-UBUD-0700' AND is_fabric = true AND deleted = false;

    -- Update 431 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ubud"'), '{variant}', '"Roller blind fabric Nature SH 240cm teak"')
WHERE sku = 'RF-UBUD-1200' AND is_fabric = true AND deleted = false;

    -- Update 432 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm white"')
WHERE sku = 'RF-WELLINGTON-5100' AND is_fabric = true AND deleted = false;

    -- Update 433 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm beige"')
WHERE sku = 'RF-WELLINGTON-5400' AND is_fabric = true AND deleted = false;

    -- Update 434 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm taupe"')
WHERE sku = 'RF-WELLINGTON-5500' AND is_fabric = true AND deleted = false;

    -- Update 435 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm grey"')
WHERE sku = 'RF-WELLINGTON-5600' AND is_fabric = true AND deleted = false;

    -- Update 436 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm antracite"')
WHERE sku = 'RF-WELLINGTON-5700' AND is_fabric = true AND deleted = false;

    -- Update 437 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Wellington"'), '{variant}', '"Roller blind fabric plain BO PES 300cm black"')
WHERE sku = 'RF-WELLINGTON-5800' AND is_fabric = true AND deleted = false;

    -- Update 438 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm white"')
WHERE sku = 'RF-WINCHESTER-0100' AND is_fabric = true AND deleted = false;

    -- Update 439 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm cream"')
WHERE sku = 'RF-WINCHESTER-0200' AND is_fabric = true AND deleted = false;

    -- Update 440 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm sand"')
WHERE sku = 'RF-WINCHESTER-0300' AND is_fabric = true AND deleted = false;

    -- Update 441 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm mist"')
WHERE sku = 'RF-WINCHESTER-0500' AND is_fabric = true AND deleted = false;

    -- Update 442 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm bison"')
WHERE sku = 'RF-WINCHESTER-0700' AND is_fabric = true AND deleted = false;

    -- Update 443 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm castle rock"')
WHERE sku = 'RF-WINCHESTER-0900' AND is_fabric = true AND deleted = false;

    -- Update 444 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Winchester"'), '{variant}', '"Roller blind fabric Texture SH PES TREV CS 300cm frost"')
WHERE sku = 'RF-WINCHESTER-1000' AND is_fabric = true AND deleted = false;

    -- Update 445 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen linen"'), '{variant}', '"Screen linen 5% 250cmx2740cm shifting sand"')
WHERE sku = 'SCA5-LINEN-01-250' AND is_fabric = true AND deleted = false;

    -- Update 446 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen linen"'), '{variant}', '"Screen linen 5% 250cmx2740cm feather grey"')
WHERE sku = 'SCA5-LINEN-02-250' AND is_fabric = true AND deleted = false;

    -- Update 447 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen linen"'), '{variant}', '"Screen linen 5% 250cmx2740cm moon mist"')
WHERE sku = 'SCA5-LINEN-03-250' AND is_fabric = true AND deleted = false;

    -- Update 448 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen linen"'), '{variant}', '"Screen linen 5% 250cmx2740cm frost"')
WHERE sku = 'SCA5-LINEN-04-250' AND is_fabric = true AND deleted = false;

    -- Update 449 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen linen"'), '{variant}', '"Screen linen 5% 250cmx2740cm raven"')
WHERE sku = 'SCA5-LINEN-05-250' AND is_fabric = true AND deleted = false;

    -- Update 450 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm chalk"')
WHERE sku = 'SCR-3001-01-250' AND is_fabric = true AND deleted = false;

    -- Update 451 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm chalk"')
WHERE sku = 'SCR-3001-01-300' AND is_fabric = true AND deleted = false;

    -- Update 452 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3001-02-250' AND is_fabric = true AND deleted = false;

    -- Update 453 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3001-02-300' AND is_fabric = true AND deleted = false;

    -- Update 454 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3001-03-250' AND is_fabric = true AND deleted = false;

    -- Update 455 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3001-03-300' AND is_fabric = true AND deleted = false;

    -- Update 456 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3001-05-250' AND is_fabric = true AND deleted = false;

    -- Update 457 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3001-05-300' AND is_fabric = true AND deleted = false;

    -- Update 458 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm ebony"')
WHERE sku = 'SCR-3001-06-250' AND is_fabric = true AND deleted = false;

    -- Update 459 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm ebony"')
WHERE sku = 'SCR-3001-06-300' AND is_fabric = true AND deleted = false;

    -- Update 460 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm soft grey"')
WHERE sku = 'SCR-3001-08-250' AND is_fabric = true AND deleted = false;

    -- Update 461 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm soft grey"')
WHERE sku = 'SCR-3001-08-300' AND is_fabric = true AND deleted = false;

    -- Update 462 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3001-10-250' AND is_fabric = true AND deleted = false;

    -- Update 463 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3001-10-300' AND is_fabric = true AND deleted = false;

    -- Update 464 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 250cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3001-11-250' AND is_fabric = true AND deleted = false;

    -- Update 465 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3001"'), '{variant}', '"Screen 3001 1% 300cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3001-11-300' AND is_fabric = true AND deleted = false;

    -- Update 466 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm chalk"')
WHERE sku = 'SCR-3003-01-250' AND is_fabric = true AND deleted = false;

    -- Update 467 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm chalk"')
WHERE sku = 'SCR-3003-01-300' AND is_fabric = true AND deleted = false;

    -- Update 468 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3003-02-250' AND is_fabric = true AND deleted = false;

    -- Update 469 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3003-02-300' AND is_fabric = true AND deleted = false;

    -- Update 470 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3003-03-250' AND is_fabric = true AND deleted = false;

    -- Update 471 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3003-03-300' AND is_fabric = true AND deleted = false;

    -- Update 472 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3003-05-250' AND is_fabric = true AND deleted = false;

    -- Update 473 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3003-05-300' AND is_fabric = true AND deleted = false;

    -- Update 474 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm ebony"')
WHERE sku = 'SCR-3003-06-250' AND is_fabric = true AND deleted = false;

    -- Update 475 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm ebony"')
WHERE sku = 'SCR-3003-06-300' AND is_fabric = true AND deleted = false;

    -- Update 476 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm soft grey"')
WHERE sku = 'SCR-3003-08-250' AND is_fabric = true AND deleted = false;

    -- Update 477 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm soft grey"')
WHERE sku = 'SCR-3003-08-300' AND is_fabric = true AND deleted = false;

    -- Update 478 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3003-10-250' AND is_fabric = true AND deleted = false;

    -- Update 479 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3003-10-300' AND is_fabric = true AND deleted = false;

    -- Update 480 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 250cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3003-11-250' AND is_fabric = true AND deleted = false;

    -- Update 481 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3003"'), '{variant}', '"Screen 3003 3% 300cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3003-11-300' AND is_fabric = true AND deleted = false;

    -- Update 482 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm chalk"')
WHERE sku = 'SCR-3005-01-250' AND is_fabric = true AND deleted = false;

    -- Update 483 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm chalk"')
WHERE sku = 'SCR-3005-01-300' AND is_fabric = true AND deleted = false;

    -- Update 484 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3005-02-250' AND is_fabric = true AND deleted = false;

    -- Update 485 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3005-02-300' AND is_fabric = true AND deleted = false;

    -- Update 486 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3005-03-250' AND is_fabric = true AND deleted = false;

    -- Update 487 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3005-03-300' AND is_fabric = true AND deleted = false;

    -- Update 488 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3005-05-250' AND is_fabric = true AND deleted = false;

    -- Update 489 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3005-05-300' AND is_fabric = true AND deleted = false;

    -- Update 490 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm ebony"')
WHERE sku = 'SCR-3005-06-250' AND is_fabric = true AND deleted = false;

    -- Update 491 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm ebony"')
WHERE sku = 'SCR-3005-06-300' AND is_fabric = true AND deleted = false;

    -- Update 492 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm soft grey"')
WHERE sku = 'SCR-3005-08-250' AND is_fabric = true AND deleted = false;

    -- Update 493 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm soft grey"')
WHERE sku = 'SCR-3005-08-300' AND is_fabric = true AND deleted = false;

    -- Update 494 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3005-10-250' AND is_fabric = true AND deleted = false;

    -- Update 495 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3005-10-300' AND is_fabric = true AND deleted = false;

    -- Update 496 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 250cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3005-11-250' AND is_fabric = true AND deleted = false;

    -- Update 497 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3005"'), '{variant}', '"Screen 3005 5% 300cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3005-11-300' AND is_fabric = true AND deleted = false;

    -- Update 498 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm chalk"')
WHERE sku = 'SCR-3010-01-250' AND is_fabric = true AND deleted = false;

    -- Update 499 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm chalk"')
WHERE sku = 'SCR-3010-01-300' AND is_fabric = true AND deleted = false;

    -- Update 500 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3010-02-250' AND is_fabric = true AND deleted = false;

    -- Update 501 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm chalk beige cream"')
WHERE sku = 'SCR-3010-02-300' AND is_fabric = true AND deleted = false;

    -- Update 502 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3010-03-250' AND is_fabric = true AND deleted = false;

    -- Update 503 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm chalk soft grey"')
WHERE sku = 'SCR-3010-03-300' AND is_fabric = true AND deleted = false;

    -- Update 504 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3010-05-250' AND is_fabric = true AND deleted = false;

    -- Update 505 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm charcoal iron grey"')
WHERE sku = 'SCR-3010-05-300' AND is_fabric = true AND deleted = false;

    -- Update 506 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm ebony"')
WHERE sku = 'SCR-3010-06-250' AND is_fabric = true AND deleted = false;

    -- Update 507 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm ebony"')
WHERE sku = 'SCR-3010-06-300' AND is_fabric = true AND deleted = false;

    -- Update 508 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm soft grey"')
WHERE sku = 'SCR-3010-08-250' AND is_fabric = true AND deleted = false;

    -- Update 509 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm soft grey"')
WHERE sku = 'SCR-3010-08-300' AND is_fabric = true AND deleted = false;

    -- Update 510 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3010-10-250' AND is_fabric = true AND deleted = false;

    -- Update 511 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm charcoal dark bronze"')
WHERE sku = 'SCR-3010-10-300' AND is_fabric = true AND deleted = false;

    -- Update 512 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 250cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3010-11-250' AND is_fabric = true AND deleted = false;

    -- Update 513 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen 3010"'), '{variant}', '"Screen 3010 10% 300cmx2740cm beige pearl grey"')
WHERE sku = 'SCR-3010-11-300' AND is_fabric = true AND deleted = false;

    -- Update 514 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Satine"'), '{variant}', '"Screen Satine 3% 300cmx2740cm Soft Grey / Ivory"')
WHERE sku = 'SCR3-SATINE-01-300' AND is_fabric = true AND deleted = false;

    -- Update 515 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Satine"'), '{variant}', '"Screen Satine 3% 300cmx2740cm Dark Bronze / Ivory"')
WHERE sku = 'SCR3-SATINE-02-300' AND is_fabric = true AND deleted = false;

    -- Update 516 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Satine"'), '{variant}', '"Screen Satine 3% 300cmx2740cm Ebony / Ivory"')
WHERE sku = 'SCR3-SATINE-03-300' AND is_fabric = true AND deleted = false;

    -- Update 517 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm pearl"')
WHERE sku = 'SCR5-EXPLORE-20-300' AND is_fabric = true AND deleted = false;

    -- Update 518 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm gold"')
WHERE sku = 'SCR5-EXPLORE-21-300' AND is_fabric = true AND deleted = false;

    -- Update 519 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm silver"')
WHERE sku = 'SCR5-EXPLORE-22-300' AND is_fabric = true AND deleted = false;

    -- Update 520 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm tin"')
WHERE sku = 'SCR5-EXPLORE-23-300' AND is_fabric = true AND deleted = false;

    -- Update 521 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm nickel"')
WHERE sku = 'SCR5-EXPLORE-24-300' AND is_fabric = true AND deleted = false;

    -- Update 522 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm bronze"')
WHERE sku = 'SCR5-EXPLORE-28-300' AND is_fabric = true AND deleted = false;

    -- Update 523 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm copper"')
WHERE sku = 'SCR5-EXPLORE-29-300' AND is_fabric = true AND deleted = false;

    -- Update 524 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm steel"')
WHERE sku = 'SCR5-EXPLORE-30-300' AND is_fabric = true AND deleted = false;

    -- Update 525 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Explore"'), '{variant}', '"Screen Explore 5% 300cmx2740cm lead"')
WHERE sku = 'SCR5-EXPLORE-31-300' AND is_fabric = true AND deleted = false;

    -- Update 526 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm white"')
WHERE sku = 'SCR5-GLOW-01-300' AND is_fabric = true AND deleted = false;

    -- Update 527 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm cream"')
WHERE sku = 'SCR5-GLOW-02-300' AND is_fabric = true AND deleted = false;

    -- Update 528 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm beige"')
WHERE sku = 'SCR5-GLOW-03-300' AND is_fabric = true AND deleted = false;

    -- Update 529 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm sand"')
WHERE sku = 'SCR5-GLOW-04-300' AND is_fabric = true AND deleted = false;

    -- Update 530 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm anthracite"')
WHERE sku = 'SCR5-GLOW-06-300' AND is_fabric = true AND deleted = false;

    -- Update 531 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm grey"')
WHERE sku = 'SCR5-GLOW-07-300' AND is_fabric = true AND deleted = false;

    -- Update 532 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Glow"'), '{variant}', '"Screen GLOW 5% 300cmx2740cm light grey"')
WHERE sku = 'SCR5-GLOW-08-300' AND is_fabric = true AND deleted = false;

    -- Update 533 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm mist"')
WHERE sku = 'SCR-AMAZON-31-300' AND is_fabric = true AND deleted = false;

    -- Update 534 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm white"')
WHERE sku = 'SCR-AMAZON-32-300' AND is_fabric = true AND deleted = false;

    -- Update 535 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm leaf"')
WHERE sku = 'SCR-AMAZON-33-300' AND is_fabric = true AND deleted = false;

    -- Update 536 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm mocca"')
WHERE sku = 'SCR-AMAZON-34-300' AND is_fabric = true AND deleted = false;

    -- Update 537 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm coffee"')
WHERE sku = 'SCR-AMAZON-36-300' AND is_fabric = true AND deleted = false;

    -- Update 538 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm charcoal"')
WHERE sku = 'SCR-AMAZON-37-300' AND is_fabric = true AND deleted = false;

    -- Update 539 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Amazon"'), '{variant}', '"Screen Amazon 300cmx2740cm dust"')
WHERE sku = 'SCR-AMAZON-38-300' AND is_fabric = true AND deleted = false;

    -- Update 540 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Noble"'), '{variant}', '"Noble Screen 300cmx2000cm pearl"')
WHERE sku = 'SCR-NOBLE-20-300' AND is_fabric = true AND deleted = false;

    -- Update 541 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Noble"'), '{variant}', '"Noble Screen 300cmx2000cm gold"')
WHERE sku = 'SCR-NOBLE-21-300' AND is_fabric = true AND deleted = false;

    -- Update 542 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Noble"'), '{variant}', '"Noble Screen 300cmx2000cm silver"')
WHERE sku = 'SCR-NOBLE-22-300' AND is_fabric = true AND deleted = false;

    -- Update 543 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Noble"'), '{variant}', '"Noble Screen 300cmx2000cm nickel"')
WHERE sku = 'SCR-NOBLE-24-300' AND is_fabric = true AND deleted = false;

    -- Update 544 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Noble"'), '{variant}', '"Noble Screen 300cmx2000cm coal"')
WHERE sku = 'SCR-NOBLE-25-300' AND is_fabric = true AND deleted = false;

    -- Update 545 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm chalk"')
WHERE sku = 'SCR-REFLECTION-01-24' AND is_fabric = true AND deleted = false;

    -- Update 546 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm chalk soft grey"')
WHERE sku = 'SCR-REFLECTION-03-24' AND is_fabric = true AND deleted = false;

    -- Update 547 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm charcoal iron grey"')
WHERE sku = 'SCR-REFLECTION-05-24' AND is_fabric = true AND deleted = false;

    -- Update 548 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm charcoal dark bronze"')
WHERE sku = 'SCR-REFLECTION-10-24' AND is_fabric = true AND deleted = false;

    -- Update 549 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm white linen"')
WHERE sku = 'SCR-REFLECTION-12-24' AND is_fabric = true AND deleted = false;

    -- Update 550 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Reflection"'), '{variant}', '"Screen REFLECTION 240cmx3000cm charcoal cream"')
WHERE sku = 'SCR-REFLECTION-13-24' AND is_fabric = true AND deleted = false;

    -- Update 551 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ring"'), '{variant}', '"Screen Rings 300cmx2740cm white"')
WHERE sku = 'SCR-RINGS-01-300' AND is_fabric = true AND deleted = false;

    -- Update 552 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ring"'), '{variant}', '"Screen Rings 300cmx2740cm silver"')
WHERE sku = 'SCR-RINGS-03-300' AND is_fabric = true AND deleted = false;

    -- Update 553 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ring"'), '{variant}', '"Screen Rings 300cmx2740cm bronze"')
WHERE sku = 'SCR-RINGS-04-300' AND is_fabric = true AND deleted = false;

    -- Update 554 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Ring"'), '{variant}', '"Screen Rings 300cmx2740cm iron"')
WHERE sku = 'SCR-RINGS-05-300' AND is_fabric = true AND deleted = false;

    -- Update 555 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm ivory"')
WHERE sku = 'SCR-STYLE-01-300' AND is_fabric = true AND deleted = false;

    -- Update 556 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm pearl"')
WHERE sku = 'SCR-STYLE-02-300' AND is_fabric = true AND deleted = false;

    -- Update 557 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm silver"')
WHERE sku = 'SCR-STYLE-03-300' AND is_fabric = true AND deleted = false;

    -- Update 558 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm warm beige"')
WHERE sku = 'SCR-STYLE-04-300' AND is_fabric = true AND deleted = false;

    -- Update 559 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm warm grey"')
WHERE sku = 'SCR-STYLE-06-300' AND is_fabric = true AND deleted = false;

    -- Update 560 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Style"'), '{variant}', '"Screen STYLE 3% 300cmx2740cm nearly black"')
WHERE sku = 'SCR-STYLE-08-300' AND is_fabric = true AND deleted = false;

    -- Update 561 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen Natural"'), '{variant}', '"Screen Natural 3% Trevira CS 285cm Aluback white metal"')
WHERE sku = 'SFN-20003-7100-285-M' AND is_fabric = true AND deleted = false;

    -- Update 562 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen Natural"'), '{variant}', '"Screen Natural 3% Trevira CS 285cm Aluback silver metal"')
WHERE sku = 'SFN-20003-7300-285-M' AND is_fabric = true AND deleted = false;

    -- Update 563 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen Natural"'), '{variant}', '"Screen Natural 3% Trevira CS 285cm Aluback grey metal"')
WHERE sku = 'SFN-20003-7400-285-M' AND is_fabric = true AND deleted = false;

    -- Update 564 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen Natural"'), '{variant}', '"Screen Natural 3% Trevira CS 285cm Aluback anthracite metal"')
WHERE sku = 'SFN-20003-7500-285-M' AND is_fabric = true AND deleted = false;

    -- Update 565 
    UPDATE "CatalogItems" SET metadata = jsonb_set(jsonb_set(COALESCE(metadata, '{}'::jsonb), '{collection}', '"Screen Natural"'), '{variant}', '"Screen Natural 3% Trevira CS 285cm Aluback black metal"')
WHERE sku = 'SFN-20003-7600-285-M' AND is_fabric = true AND deleted = false;
    
    RAISE NOTICE '✅ Metadata update completed';
END $$;

-- ====================================================
-- Now run: populate_collections_catalog_from_csv_data.sql
-- ====================================================
