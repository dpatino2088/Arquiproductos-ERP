/**
 * Script to assign collections to fabric items based on their SKU pattern
 * Pattern: DRF-{COLLECTION}-{VARIANT} (e.g., DRF-BLOCK-0100 → Collection: "BLOCK")
 * 
 * Usage: node scripts/assign_collections_to_fabrics.js <csv_file_path> <organization_id> [supabase_url] [service_role_key]
 * 
 * Example: node scripts/assign_collections_to_fabrics.js ../catalog_items_import_DP.csv '4de856e8-36ce-480a-952b-a2f5083c69d6'
 */

import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const csvFilePath = process.argv[2];
const organizationId = process.argv[3];
const supabaseUrl = process.argv[4] || process.env.VITE_SUPABASE_URL || '';
const serviceRoleKey = process.argv[5] || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!csvFilePath || !organizationId) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/assign_collections_to_fabrics.js <csv_file_path> <organization_id> [supabase_url] [service_role_key]');
    console.error('\nExample:');
    console.error('  node scripts/assign_collections_to_fabrics.js ../catalog_items_import_DP.csv "4de856e8-36ce-480a-952b-a2f5083c69d6"');
    process.exit(1);
}

if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing Supabase credentials');
    console.error('\nSet environment variables:');
    console.error('  VITE_SUPABASE_URL=https://xxx.supabase.co');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJxxx...');
    console.error('\nOr pass as arguments:');
    console.error('  node scripts/assign_collections_to_fabrics.js <csv> <org_id> <url> <key>');
    process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false,
    },
});

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
        // If pattern doesn't match, try to extract from name or use a default
        console.warn(`⚠️  Could not extract collection from SKU: ${sku}`);
    }
}

console.log(`\n✅ Found ${fabricCount} fabric items`);
console.log(`📦 Found ${collectionMap.size} unique collections:`);
collectionMap.forEach((collection, name) => {
    console.log(`   - ${name}: ${collection.skus.length} fabrics`);
});

// Step 1: Create collections in CatalogCollections
console.log('\n📝 Creating collections in CatalogCollections...');
const collectionIdMap = new Map(); // collection_name -> collection_id

for (const [collectionName, collectionData] of collectionMap) {
    // Check if collection already exists
    const { data: existing } = await supabase
        .from('CatalogCollections')
        .select('id, name')
        .eq('organization_id', organizationId)
        .eq('name', collectionName)
        .eq('deleted', false)
        .single();
    
    if (existing) {
        console.log(`   ✓ Collection "${collectionName}" already exists (ID: ${existing.id})`);
        collectionIdMap.set(collectionName, existing.id);
    } else {
        // Create new collection
        const { data: newCollection, error } = await supabase
            .from('CatalogCollections')
            .insert({
                organization_id: organizationId,
                name: collectionName,
                code: collectionName,
                description: `Collection ${collectionName} from Coulisse`,
                active: true,
                sort_order: 0,
                deleted: false,
                archived: false
            })
            .select()
            .single();
        
        if (error) {
            console.error(`   ❌ Error creating collection "${collectionName}":`, error.message);
            continue;
        }
        
        console.log(`   ✓ Created collection "${collectionName}" (ID: ${newCollection.id})`);
        collectionIdMap.set(collectionName, newCollection.id);
    }
}

// Step 2: Assign collections to fabric items
console.log('\n🔗 Assigning collections to fabric items...');
let assignedCount = 0;
let errorCount = 0;

for (const [collectionName, collectionData] of collectionMap) {
    const collectionId = collectionIdMap.get(collectionName);
    if (!collectionId) {
        console.warn(`   ⚠️  No collection ID for "${collectionName}", skipping...`);
        continue;
    }
    
    // Update all fabrics with this collection
    for (const sku of collectionData.skus) {
        const { error } = await supabase
            .from('CatalogItems')
            .update({ collection_id: collectionId })
            .eq('organization_id', organizationId)
            .eq('sku', sku)
            .eq('item_type', 'fabric');
        
        if (error) {
            console.error(`   ❌ Error assigning collection to SKU "${sku}":`, error.message);
            errorCount++;
        } else {
            assignedCount++;
        }
    }
    
    console.log(`   ✓ Assigned "${collectionName}" to ${collectionData.skus.length} fabrics`);
}

// Summary
console.log('\n' + '='.repeat(60));
console.log('📊 SUMMARY');
console.log('='.repeat(60));
console.log(`   Collections found: ${collectionMap.size}`);
console.log(`   Collections created/found: ${collectionIdMap.size}`);
console.log(`   Fabrics processed: ${fabricCount}`);
console.log(`   Fabrics assigned: ${assignedCount}`);
console.log(`   Errors: ${errorCount}`);
console.log('='.repeat(60));
console.log('\n✅ Done!\n');

