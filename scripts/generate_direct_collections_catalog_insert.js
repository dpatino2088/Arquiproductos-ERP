/**
 * Script to generate direct INSERT SQL for CollectionsCatalog
 * Uses SKU to find catalog_item_id (FK) and inserts collection/variant from CSV
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Papa from 'papaparse';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const csvPath = path.join(__dirname, '../../catalog_items_import_DP_COLLECTIONS.csv');

function generateDirectInsertSQL() {
  console.log('🚀 Generating direct INSERT SQL for CollectionsCatalog...\n');

  if (!fs.existsSync(csvPath)) {
    console.error(`❌ CSV file not found: ${csvPath}`);
    process.exit(1);
  }

  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  
  const parseResult = Papa.parse(csvContent, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => {
      if (header.toLowerCase() === 'colletion') return 'collection';
      return header.toLowerCase().trim();
    }
  });

  const rows = parseResult.data;
  console.log(`📊 Found ${rows.length} rows in CSV\n`);

  let insertStatements = [];
  let fabricsProcessed = 0;

  for (const row of rows) {
    if (row.is_fabric !== 'TRUE' && row.is_fabric !== 'true') {
      continue;
    }

    const sku = row.sku?.trim();
    const collection = (row.collection?.trim() || row.colletion?.trim()) || '';
    const variant = row.variant?.trim() || '';

    if (!sku || !collection || !variant) {
      continue;
    }

    fabricsProcessed++;

    // Escape single quotes for SQL
    const skuEscaped = sku.replace(/'/g, "''");
    const collectionEscaped = collection.replace(/'/g, "''");
    const variantEscaped = variant.replace(/'/g, "''");

    // Generate INSERT using subquery to find catalog_item_id by SKU
    const insertSQL = `INSERT INTO "CollectionsCatalog" (
    organization_id,
    catalog_item_id,
    fabric_id,
    item_type,
    sku,
    name,
    description,
    collection_name,
    variant_name,
    roll_width,
    roll_length,
    roll_uom,
    grammage_gsm,
    openness_pct,
    material,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    COALESCE(ci.item_type, 'fabric'),
    ci.sku,
    ci.name,
    ci.description,
    '${collectionEscaped}',
    '${variantEscaped}',
    ci.roll_width_m,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'roll_length' 
        THEN (ci.metadata->>'roll_length')::numeric 
        ELSE NULL 
    END,
    COALESCE(ci.uom, 'm'),
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'grammage_gsm' 
        THEN (ci.metadata->>'grammage_gsm')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'openness_pct' 
        THEN (ci.metadata->>'openness_pct')::numeric 
        ELSE NULL 
    END,
    CASE 
        WHEN ci.metadata IS NOT NULL AND ci.metadata ? 'material' 
        THEN ci.metadata->>'material' 
        ELSE NULL 
    END,
    ci.cost_price,
    COALESCE(ci.uom, 'm'),
    true
FROM "CatalogItems" ci
WHERE ci.sku = '${skuEscaped}' 
  AND ci.is_fabric = true 
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;`;

    insertStatements.push({ sku, collection, variant, sql: insertSQL });
  }

  // Generate complete SQL file
  const completeSQL = `-- ====================================================
-- Direct Insert: Populate CollectionsCatalog from CSV
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total fabrics: ${fabricsProcessed}
-- Uses SKU to find catalog_item_id (FK to CatalogItems)
-- Collection and Variant come directly from CSV (NO metadata)
-- ====================================================

DO $$
DECLARE
    inserted_count integer := 0;
    not_found_count integer := 0;
    error_count integer := 0;
    total_inserted integer := 0;
BEGIN
    RAISE NOTICE '🚀 Starting direct insert into CollectionsCatalog...';
    RAISE NOTICE '   Processing ${fabricsProcessed} fabrics from CSV...';
    RAISE NOTICE '';

${insertStatements.map((item, idx) => {
  return `    -- Insert ${idx + 1}/${fabricsProcessed}: ${item.sku} | ${item.collection} | ${item.variant}
    BEGIN
        ${item.sql.replace(/\n/g, '\n        ')}
        GET DIAGNOSTICS inserted_count = ROW_COUNT;
        total_inserted := total_inserted + inserted_count;
        IF inserted_count = 0 THEN
            not_found_count := not_found_count + 1;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            error_count := error_count + 1;
            RAISE WARNING '   ❌ Error inserting %: %', '${item.sku.replace(/'/g, "''")}', SQLERRM;
    END;`;
}).join('\n\n')}

    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary:';
    RAISE NOTICE '   ✅ Inserted: % fabrics', total_inserted;
    RAISE NOTICE '   ⚠️  Not found/Skipped: % fabrics', not_found_count;
    RAISE NOTICE '   ❌ Errors: % fabrics', error_count;
    RAISE NOTICE '';
    RAISE NOTICE '✅ CollectionsCatalog population completed!';
END $$;

-- ====================================================
-- Verification Query
-- ====================================================

SELECT 
    collection_name,
    COUNT(*) as total_items,
    COUNT(DISTINCT variant_name) as unique_variants
FROM "CollectionsCatalog"
WHERE deleted = false
GROUP BY collection_name
ORDER BY collection_name;
`;

  // Write to file
  const outputPath = path.join(__dirname, '../database/migrations/direct_insert_collections_catalog.sql');
  fs.writeFileSync(outputPath, completeSQL, 'utf-8');

  console.log(`✅ Generated SQL file: ${outputPath}`);
  console.log(`   Total fabrics: ${fabricsProcessed}`);
  console.log(`   File size: ${(completeSQL.length / 1024).toFixed(2)} KB`);
  console.log(`\n💡 Ready to execute in Supabase SQL Editor!`);
}

generateDirectInsertSQL();

