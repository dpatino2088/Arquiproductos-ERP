/**
 * Script to generate SQL UPDATE statements from CSV
 * This generates SQL that you can copy/paste into Supabase SQL Editor
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Papa from 'papaparse';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const csvPath = path.join(__dirname, '../../catalog_items_import_DP_COLLECTIONS.csv');

function generateSQL() {
  console.log('🚀 Generating SQL UPDATE statements from CSV...\n');

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

  let sqlStatements = [];
  let fabricsProcessed = 0;

  // Generate UPDATE statements for fabrics only
  for (const row of rows) {
    if (row.is_fabric !== 'TRUE' && row.is_fabric !== 'true') {
      continue;
    }

    const sku = row.sku?.trim();
    const collection = (row.collection?.trim() || row.colletion?.trim()) || '';
    const variant = row.variant?.trim() || '';

    if (!sku) continue;
    if (!collection && !variant) continue;

    fabricsProcessed++;

    // Escape quotes in collection and variant
    const collectionEscaped = collection.replace(/'/g, "''");
    const variantEscaped = variant.replace(/'/g, "''");

    // Build JSONB update
    let jsonbUpdate = "COALESCE(metadata, '{}'::jsonb)";
    
    if (collection) {
      jsonbUpdate = `jsonb_set(${jsonbUpdate}, '{collection}', '"${collectionEscaped}"')`;
    }
    
    if (variant) {
      jsonbUpdate = `jsonb_set(${jsonbUpdate}, '{variant}', '"${variantEscaped}"')`;
    }

    const sql = `UPDATE "CatalogItems" 
SET metadata = ${jsonbUpdate}
WHERE sku = '${sku.replace(/'/g, "''")}' AND is_fabric = true AND deleted = false;`;

    sqlStatements.push(sql);
  }

  // Generate the complete SQL script
  const completeSQL = `-- ====================================================
-- Auto-generated SQL: Update CatalogItems with Collection and Variant
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total fabrics to update: ${fabricsProcessed}
-- ====================================================

DO $$
DECLARE
    updated_count integer := 0;
BEGIN
    RAISE NOTICE '📝 Updating CatalogItems metadata with collection/variant...';
    RAISE NOTICE '   Processing ${fabricsProcessed} fabrics...';
    
${sqlStatements.map((sql, idx) => {
  // Convert UPDATE to work inside DO block
  const updatePart = sql.replace('UPDATE "CatalogItems"', '    -- Update ' + (idx + 1));
  return updatePart.replace('SET metadata =', '    UPDATE "CatalogItems" SET metadata =');
}).join('\n\n')}
    
    RAISE NOTICE '✅ Metadata update completed';
END $$;

-- ====================================================
-- Now run: populate_collections_catalog_from_csv_data.sql
-- ====================================================
`;

  // Write to file
  const outputPath = path.join(__dirname, '../database/migrations/update_catalog_items_collections_variants.sql');
  fs.writeFileSync(outputPath, completeSQL, 'utf-8');

  console.log(`✅ Generated SQL file: ${outputPath}`);
  console.log(`   Total fabrics: ${fabricsProcessed}`);
  console.log(`   SQL statements: ${sqlStatements.length}`);
  console.log('\n💡 Next steps:');
  console.log('   1. Review the generated SQL file');
  console.log('   2. Execute it in Supabase SQL Editor');
  console.log('   3. Then run: populate_collections_catalog_from_csv_data.sql');
}

generateSQL();





