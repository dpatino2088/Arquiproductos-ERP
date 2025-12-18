/**
 * Script to generate SQL for importing CatalogItems and CollectionsCatalog from CSV
 * This script generates:
 * 1. DELETE statements to clear existing data
 * 2. INSERT statements for CatalogItems (all rows)
 * 3. INSERT statements for CollectionsCatalog (only fabrics with collections)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Papa from 'papaparse';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const csvPath = path.join(__dirname, '../../catalog_items_import_DP_COLLECTIONS.csv');
const outputDir = path.join(__dirname, '../database/migrations');

// Map CSV UOM to database enum values
function mapUOM(csvUOM) {
  const uomMap = {
    'PCS': 'ea',
    'SET': 'ea',
    'FT': 'm',
    'YD': 'm',
    'FT2': 'sqm',
    'M': 'm',
    'M2': 'sqm',
    'SQM': 'sqm',
  };
  return uomMap[csvUOM?.toUpperCase()] || 'ea';
}

// Map CSV item_type to database enum (already lowercase)
function mapItemType(csvType) {
  const validTypes = ['component', 'fabric', 'linear', 'service', 'accessory'];
  const type = csvType?.toLowerCase().trim();
  return validTypes.includes(type) ? type : 'component';
}

// Escape SQL strings
function escapeSQL(str) {
  if (!str) return null;
  return str.replace(/'/g, "''");
}

// Format SQL value (null, number, or escaped string)
function sqlValue(value, isString = true) {
  if (value === null || value === undefined || value === '') {
    return 'NULL';
  }
  if (!isString) {
    const num = parseFloat(value);
    return isNaN(num) ? 'NULL' : num.toString();
  }
  return `'${escapeSQL(String(value))}'`;
}

function generateImportSQL() {
  console.log('🚀 Generating SQL for CatalogItems and CollectionsCatalog import...\n');

  if (!fs.existsSync(csvPath)) {
    console.error(`❌ CSV file not found: ${csvPath}`);
    process.exit(1);
  }

  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  
  const parseResult = Papa.parse(csvContent, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => {
      // Handle typo in CSV header
      if (header.toLowerCase() === 'colletion') return 'collection';
      return header.toLowerCase().trim();
    }
  });

  const rows = parseResult.data;
  console.log(`📊 Found ${rows.length} rows in CSV\n`);

  // Part 1: Generate DELETE statements
  const deleteSQL = `-- ====================================================
-- DELETE existing data from CatalogItems and CollectionsCatalog
-- ====================================================
-- WARNING: This will delete ALL data from these tables
-- Make sure you have a backup before running this!
-- ====================================================
-- Set your organization_id here (or use the first organization)
DO $$
DECLARE
    target_org_id uuid;
BEGIN
    -- Replace this with your specific organization_id UUID, or use the query below
    -- target_org_id := 'your-organization-uuid-here';
    
    -- Or use the first organization (uncomment to use):
    SELECT id INTO target_org_id FROM "Organizations" LIMIT 1;
    
    IF target_org_id IS NULL THEN
        RAISE EXCEPTION 'No organization found. Please set target_org_id manually.';
    END IF;
    
    RAISE NOTICE 'Using organization_id: %', target_org_id;
    
    -- Delete CollectionsCatalog first (due to FK constraint)
    DELETE FROM "CollectionsCatalog" WHERE organization_id = target_org_id;
    
    -- Delete CatalogItems
    DELETE FROM "CatalogItems" WHERE organization_id = target_org_id;
    
    RAISE NOTICE '✅ Deleted all data from CollectionsCatalog and CatalogItems for organization %', target_org_id;
END $$;
`;

  // Part 2: Generate INSERT statements for CatalogItems
  const catalogItemsInserts = [];
  let catalogItemsCount = 0;

  for (const row of rows) {
    const sku = row.sku?.trim();
    if (!sku) continue;

    catalogItemsCount++;

    // Name should be description if available, otherwise SKU
    const description = row.description?.trim() || null;
    const name = description || sku;
    const itemType = mapItemType(row.item_type);
    const uom = mapUOM(row.uom);
    
    // Note: CSV has cost_price and unit_price, but columns might be swapped
    // CSV format: unit_price, cost_price (check actual CSV structure)
    const costPrice = row.cost_price ? parseFloat(row.cost_price) : null;
    const unitPrice = row.unit_price ? parseFloat(row.unit_price) : null;
    const active = row.active === 'TRUE' || row.active === 'true';
    
    // Metadata for additional fields
    const metadata = {};
    const isFabric = row.is_fabric === 'TRUE' || row.is_fabric === 'true';
    if (isFabric && row.roll_width_m) metadata.roll_width_m = parseFloat(row.roll_width_m);
    if (row.fabric_pricing_mode && row.fabric_pricing_mode.trim()) metadata.fabric_pricing_mode = row.fabric_pricing_mode.trim();
    if (row.manufacturer && row.manufacturer.trim()) metadata.manufacturer = row.manufacturer.trim();
    if (row.category && row.category.trim()) metadata.category = row.category.trim();
    if (row.family && row.family.trim()) metadata.family = row.family.trim();

    const metadataJSON = Object.keys(metadata).length > 0 
      ? `'${JSON.stringify(metadata).replace(/'/g, "''")}'::jsonb` 
      : 'NULL';

    // Use a variable for organization_id (will be set in DO block)
    const insertSQL = `INSERT INTO "CatalogItems" (
    organization_id,
    manufacturer_id,
    category_id,
    sku,
    name,
    description,
    item_type,
    uom,
    purchase_uom,
    sales_uom,
    cost,
    price,
    active,
    deleted,
    archived,
    metadata
) VALUES (
    target_org_id, -- Set in DO block above
    NULL, -- TODO: Replace with manufacturer_id if available
    NULL, -- TODO: Replace with category_id if available
    ${sqlValue(sku)},
    ${sqlValue(name)},
    ${sqlValue(description)},
    '${itemType}'::catalog_item_type,
    '${uom}'::catalog_uom,
    '${uom}'::catalog_uom,
    '${uom}'::catalog_uom,
    ${sqlValue(costPrice, false)},
    ${sqlValue(unitPrice, false)},
    ${active},
    false,
    false,
    ${metadataJSON}
);`;

    catalogItemsInserts.push({ sku, sql: insertSQL });
  }

  const catalogItemsSQL = `-- ====================================================
-- INSERT CatalogItems from CSV
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total items: ${catalogItemsCount}
-- ====================================================

DO $$
DECLARE
    target_org_id uuid;
BEGIN
    -- Get organization_id (same as in DELETE section)
    SELECT id INTO target_org_id FROM "Organizations" LIMIT 1;
    
    IF target_org_id IS NULL THEN
        RAISE EXCEPTION 'No organization found. Please set target_org_id manually.';
    END IF;

${catalogItemsInserts.map(item => '    ' + item.sql.replace(/target_org_id/g, 'target_org_id')).join('\n\n')}

    RAISE NOTICE '✅ Inserted % catalog items', ${catalogItemsCount};
END $$;
`;

  // Part 3: Generate INSERT statements for CollectionsCatalog (only fabrics with collections)
  const collectionsInserts = [];
  let fabricsCount = 0;

  for (const row of rows) {
    const isFabric = row.is_fabric === 'TRUE' || row.is_fabric === 'true';
    if (!isFabric) continue;

    const collection = (row.collection?.trim() || '') || '';
    const variant = row.variant?.trim() || '';
    const sku = row.sku?.trim() || '';

    if (!sku || !collection || !variant) {
      continue;
    }

    fabricsCount++;

    const rollWidth = row.roll_width_m ? parseFloat(row.roll_width_m) : null;

    // Generate INSERT using subquery to find catalog_item_id by SKU
    // Note: organization_id filter will be added in the DO block
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
    roll_uom,
    cost_value,
    cost_uom,
    active
)
SELECT 
    ci.organization_id,
    ci.id,
    ci.id,
    'fabric'::text,
    ci.sku,
    ci.name,
    ci.description,
    ${sqlValue(collection)},
    ${sqlValue(variant)},
    ${sqlValue(rollWidth, false)},
    'm',
    ci.cost,
    ci.uom::text,
    ci.active
FROM "CatalogItems" ci
WHERE ci.organization_id = target_org_id
  AND ci.sku = ${sqlValue(sku)}
  AND ci.item_type = 'fabric'
  AND ci.deleted = false
ON CONFLICT (organization_id, catalog_item_id) WHERE deleted = false DO NOTHING;`;

    collectionsInserts.push({ sku, collection, variant, sql: insertSQL });
  }

  const collectionsSQL = `-- ====================================================
-- INSERT CollectionsCatalog from CSV (fabrics with collections only)
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Total fabrics: ${fabricsCount}
-- Only includes items with is_fabric=TRUE and non-empty collection/variant
-- ====================================================

DO $$
DECLARE
    target_org_id uuid;
    inserted_count integer;
    total_inserted integer := 0;
BEGIN
    -- Get organization_id (same as in DELETE section)
    SELECT id INTO target_org_id FROM "Organizations" LIMIT 1;
    
    IF target_org_id IS NULL THEN
        RAISE EXCEPTION 'No organization found. Please set target_org_id manually.';
    END IF;

${collectionsInserts.map(item => {
  return `    -- Insert: ${item.sku} | ${item.collection} | ${item.variant}\n    ${item.sql}`;
}).join('\n\n')}

    RAISE NOTICE '✅ Inserted collections catalog items';
END $$;
`;

  // Combine all SQL
  const completeSQL = `${deleteSQL}

${catalogItemsSQL}

${collectionsSQL}

-- ====================================================
-- Verification Queries
-- ====================================================

SELECT COUNT(*) as total_catalog_items FROM "CatalogItems" WHERE deleted = false;
SELECT COUNT(*) as total_collections FROM "CollectionsCatalog" WHERE deleted = false;
SELECT collection_name, COUNT(*) as items_count 
FROM "CollectionsCatalog" 
WHERE deleted = false 
GROUP BY collection_name 
ORDER BY collection_name;
`;

  // Write complete SQL file
  const outputPath = path.join(outputDir, 'import_catalog_items_and_collections.sql');
  fs.writeFileSync(outputPath, completeSQL, 'utf-8');

  console.log(`✅ Generated SQL file: ${outputPath}`);
  console.log(`   - CatalogItems: ${catalogItemsCount} items`);
  console.log(`   - CollectionsCatalog: ${fabricsCount} fabrics`);
  console.log(`   - File size: ${(completeSQL.length / 1024 / 1024).toFixed(2)} MB`);
  console.log(`\n⚠️  IMPORTANT: Review the SQL file and replace NULL organization_id with your actual organization_id!`);
  console.log(`\n💡 Ready to execute in Supabase SQL Editor!`);
}

generateImportSQL();
