/**
 * Script to generate SQL files split into 13 batches for CatalogItems import
 * This makes it easier to upload to Supabase SQL Editor
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Papa from 'papaparse';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const csvPath = path.join(__dirname, '../../catalog_items_import_DP_COLLECTIONS.csv');
const outputDir = path.join(__dirname, '../database/migrations/catalog_items_batches');

// Create output directory if it doesn't exist
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

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

function generateBatchedSQL() {
  console.log('🚀 Generating SQL batches for CatalogItems import...\n');

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

  // Generate INSERT statements for CatalogItems
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

    // Map measure_basis from CSV to enum values
    // Enum values: 'unit', 'width_linear', 'height_linear', 'area', 'fabric'
    const measureBasis = row.measure_basis?.trim().toLowerCase() || 'unit';
    const measureBasisMap = {
      'unit': 'unit',
      'linear_m': 'width_linear',  // linear measurement by width
      'linear': 'width_linear',
      'fabric': 'fabric',
      'area': 'area',
      'sqm': 'area'
    };
    const mappedMeasureBasis = measureBasisMap[measureBasis] || 'unit';

    // Map fabric_pricing_mode - only for fabrics, and only if valid enum value
    let fabricPricingMode = null;
    if (isFabric && row.fabric_pricing_mode && row.fabric_pricing_mode.trim()) {
      const pricingMode = row.fabric_pricing_mode.trim().toLowerCase();
      if (pricingMode === 'per_linear_m' || pricingMode === 'per_sqm') {
        fabricPricingMode = pricingMode;
      } else if (pricingMode.includes('linear') || pricingMode.includes('m') && !pricingMode.includes('sqm')) {
        fabricPricingMode = 'per_linear_m';
      } else if (pricingMode.includes('sqm') || pricingMode.includes('area')) {
        fabricPricingMode = 'per_sqm';
      }
      // If it's a number or invalid, leave as NULL
    }
    const fabricPricingModeSQL = fabricPricingMode ? `'${fabricPricingMode}'::fabric_pricing_mode` : 'NULL';

    const insertSQL = `INSERT INTO "CatalogItems" (
    organization_id,
    sku,
    name,
    description,
    measure_basis,
    uom,
    is_fabric,
    roll_width_m,
    fabric_pricing_mode,
    unit_price,
    cost_price,
    active,
    discontinued,
    metadata,
    deleted,
    archived
) VALUES (
    target_org_id,
    ${sqlValue(sku)},
    ${sqlValue(name)},
    ${sqlValue(description)},
    '${mappedMeasureBasis}'::measure_basis,
    ${sqlValue(uom)},
    ${isFabric},
    ${sqlValue(isFabric && row.roll_width_m ? parseFloat(row.roll_width_m) : null, false)},
    ${fabricPricingModeSQL},
    ${sqlValue(unitPrice, false)},
    ${sqlValue(costPrice, false)},
    ${active},
    ${row.discontinued === 'TRUE' || row.discontinued === 'true'},
    ${metadataJSON},
    false,
    false
)
ON CONFLICT (organization_id, sku) WHERE deleted = false 
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    measure_basis = EXCLUDED.measure_basis,
    uom = EXCLUDED.uom,
    is_fabric = EXCLUDED.is_fabric,
    roll_width_m = EXCLUDED.roll_width_m,
    fabric_pricing_mode = EXCLUDED.fabric_pricing_mode,
    unit_price = EXCLUDED.unit_price,
    cost_price = EXCLUDED.cost_price,
    active = EXCLUDED.active,
    discontinued = EXCLUDED.discontinued,
    metadata = EXCLUDED.metadata,
    updated_at = now();`;

    catalogItemsInserts.push({ sku, sql: insertSQL });
  }

  console.log(`✅ Generated ${catalogItemsInserts.length} INSERT statements\n`);

  // Split into 13 batches
  const NUM_BATCHES = 13;
  const itemsPerBatch = Math.ceil(catalogItemsInserts.length / NUM_BATCHES);

  // Header SQL (setup - no DELETE needed, using ON CONFLICT instead)
  const headerSQL = `-- ====================================================
-- Catalog Items Import - Using ON CONFLICT DO UPDATE
-- ====================================================
-- This script will INSERT new items or UPDATE existing ones
-- No DELETE is performed - existing items will be updated
-- Items are matched by (organization_id, sku)
-- ====================================================
`;

  // Generate each batch
  for (let batchNum = 1; batchNum <= NUM_BATCHES; batchNum++) {
    const startIdx = (batchNum - 1) * itemsPerBatch;
    const endIdx = Math.min(startIdx + itemsPerBatch, catalogItemsInserts.length);
    const batchItems = catalogItemsInserts.slice(startIdx, endIdx);
    
    const batchSQL = `-- ====================================================
-- Batch ${batchNum} of ${NUM_BATCHES}: CatalogItems Import
-- ====================================================
-- Generated from: catalog_items_import_DP_COLLECTIONS.csv
-- Items in this batch: ${batchItems.length}
-- Range: ${startIdx + 1} to ${endIdx} of ${catalogItemsInserts.length} total items
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

${batchItems.map(item => '    ' + item.sql).join('\n\n')}

    RAISE NOTICE '✅ Batch ${batchNum}/${NUM_BATCHES}: Inserted ${batchItems.length} catalog items';
END $$;
`;

    // Write batch file
    const batchFileName = `batch_${String(batchNum).padStart(3, '0')}.sql`;
    const batchFilePath = path.join(outputDir, batchFileName);
    
    if (batchNum === 1) {
      // First batch includes the header comment
      fs.writeFileSync(batchFilePath, headerSQL + '\n\n' + batchSQL, 'utf-8');
      console.log(`✅ Created ${batchFileName} (${batchItems.length} items)`);
    } else {
      fs.writeFileSync(batchFilePath, batchSQL, 'utf-8');
      console.log(`✅ Created ${batchFileName} (${batchItems.length} items)`);
    }
  }

  console.log(`\n📁 All batches saved to: ${outputDir}`);
  console.log(`\n💡 IMPORTANT:`);
  console.log(`   1. Run batches 001-013 in order`);
  console.log(`   2. Items will be INSERTED (new) or UPDATED (existing) based on SKU`);
  console.log(`   3. No DELETE is performed - safe to run multiple times`);
  console.log(`   4. Set target_org_id to a specific UUID if needed`);
}

generateBatchedSQL();

