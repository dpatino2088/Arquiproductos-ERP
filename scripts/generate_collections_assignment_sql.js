/**
 * Script to generate SQL for assigning collections to fabric items
 * This generates SQL that can be executed directly in Supabase SQL Editor
 * 
 * Usage: node scripts/generate_collections_assignment_sql.js <csv_file_path> <organization_id>
 * 
 * Example: node scripts/generate_collections_assignment_sql.js ../catalog_items_import_DP.csv '4de856e8-36ce-480a-952b-a2f5083c69d6'
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const csvFilePath = process.argv[2];
const organizationId = process.argv[3];

if (!csvFilePath || !organizationId) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/generate_collections_assignment_sql.js <csv_file_path> <organization_id>');
    console.error('\nExample:');
    console.error('  node scripts/generate_collections_assignment_sql.js ../catalog_items_import_DP.csv "4de856e8-36ce-480a-952b-a2f5083c69d6"');
    process.exit(1);
}

// Read CSV file
console.log(`\n📖 Reading CSV file: ${csvFilePath}`);
const csvContent = fs.readFileSync(csvFilePath, 'utf-8');
const lines = csvContent.split('\n').filter(line => line.trim() !== '');

// Skip header
const dataLines = lines.slice(1);

// Extract collections from fabric SKUs (pattern: DRF-{COLLECTION}-{VARIANT})
const collectionMap = new Map(); // collection_name -> { skus: [], name: collection_name }

console.log('\n🔍 Extracting collections from fabric SKUs...');
let fabricCount = 0;

for (const line of dataLines) {
    // Parse CSV line (handle quoted fields with commas)
    const fields = [];
    let currentField = '';
    let inQuotes = false;
    
    for (let i = 0; i < line.length; i++) {
        const char = line[i];
        if (char === '"') {
            inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
            fields.push(currentField.trim());
            currentField = '';
        } else {
            currentField += char;
        }
    }
    fields.push(currentField.trim()); // Last field
    
    if (fields.length < 1) continue;
    
    const sku = fields[0];
    const itemType = fields[3]?.toLowerCase() || '';
    const isFabric = fields[6]?.toUpperCase() === 'TRUE' || itemType === 'fabric';
    
    // Only process fabrics
    if (!isFabric) continue;
    
    fabricCount++;
    
    // Extract collection from SKU pattern: DRF-{COLLECTION}-{VARIANT}
    // Also handle other patterns like: RF-{COLLECTION}-{VARIANT}, etc.
    const match = sku.match(/^(?:DRF|RF|F)-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        const collectionName = match[1].toUpperCase();
        
        if (!collectionMap.has(collectionName)) {
            collectionMap.set(collectionName, {
                name: collectionName,
                skus: []
            });
        }
        
        collectionMap.get(collectionName).skus.push(sku);
    } else {
        // If pattern doesn't match, log warning
        console.warn(`⚠️  Could not extract collection from SKU: ${sku}`);
    }
}

console.log(`\n✅ Found ${fabricCount} fabric items`);
console.log(`📦 Found ${collectionMap.size} unique collections:`);
collectionMap.forEach((collection, name) => {
    console.log(`   - ${name}: ${collection.skus.length} fabrics`);
});

// Generate SQL
console.log('\n📝 Generating SQL...');

let sql = `-- ====================================================
-- Assign Collections to Fabric Items
-- Generated from: ${path.basename(csvFilePath)}
-- Organization ID: ${organizationId}
-- ====================================================

DO $$
DECLARE
    org_id uuid := '${organizationId}';
    collection_id_var uuid;
    collection_name_var text;
    sku_var text;
    updated_count int := 0;
BEGIN
`;

// Generate SQL for each collection
for (const [collectionName, collectionData] of collectionMap) {
    const escapedName = collectionName.replace(/'/g, "''");
    
    sql += `
    -- Collection: ${collectionName} (${collectionData.skus.length} fabrics)
    collection_name_var := '${escapedName}';
    
    -- Get or create collection
    SELECT id INTO collection_id_var
    FROM "CatalogCollections"
    WHERE organization_id = org_id
      AND name = collection_name_var
      AND deleted = false
    LIMIT 1;
    
    IF collection_id_var IS NULL THEN
        -- Create collection if it doesn't exist
        INSERT INTO "CatalogCollections" (
            organization_id,
            name,
            code,
            description,
            active,
            sort_order,
            deleted,
            archived
        ) VALUES (
            org_id,
            collection_name_var,
            collection_name_var,
            'Collection ' || collection_name_var || ' from Coulisse',
            true,
            0,
            false,
            false
        ) RETURNING id INTO collection_id_var;
        
        RAISE NOTICE 'Created collection: %', collection_name_var;
    ELSE
        RAISE NOTICE 'Found existing collection: %', collection_name_var;
    END IF;
    
    -- Assign collection to fabrics
`;

    for (const sku of collectionData.skus) {
        const escapedSku = sku.replace(/'/g, "''");
        sql += `
    sku_var := '${escapedSku}';
    UPDATE "CatalogItems"
    SET collection_id = collection_id_var
    WHERE organization_id = org_id
      AND sku = sku_var
      AND item_type = 'fabric'
      AND deleted = false;
    
    IF FOUND THEN
        updated_count := updated_count + 1;
    END IF;
`;
    }
}

sql += `
    RAISE NOTICE 'Total fabrics updated: %', updated_count;
END $$;

-- Verify results
SELECT 
    c.name AS collection_name,
    COUNT(ci.id) AS fabric_count
FROM "CatalogCollections" c
LEFT JOIN "CatalogItems" ci ON ci.collection_id = c.id AND ci.item_type = 'fabric' AND ci.deleted = false
WHERE c.organization_id = '${organizationId}'
  AND c.deleted = false
GROUP BY c.id, c.name
ORDER BY c.name;
`;

// Write SQL to file
const outputPath = path.join(__dirname, '..', 'database', 'migrations', 'assign_collections_to_fabrics.sql');
fs.writeFileSync(outputPath, sql);

console.log(`\n✅ SQL generated successfully!`);
console.log(`📄 Output file: ${outputPath}`);
console.log(`\n📋 Next steps:`);
console.log(`   1. Execute the migration: database/migrations/add_collection_id_to_catalog_items.sql`);
console.log(`   2. Execute the generated SQL: ${outputPath}`);
console.log(`   3. Verify the results in Supabase SQL Editor\n`);

