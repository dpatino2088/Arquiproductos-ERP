/**
 * Script to create collections in CatalogCollections based on the collection column in CSV
 * This should be run BEFORE importing the catalog items
 * 
 * Usage: node scripts/create_collections_from_csv.js <csv_file_path> <organization_id> [supabase_url] [service_role_key]
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
    console.error('  node scripts/create_collections_from_csv.js <csv_file_path> <organization_id> [supabase_url] [service_role_key]');
    process.exit(1);
}

if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing Supabase credentials');
    console.error('\nSet environment variables:');
    console.error('  VITE_SUPABASE_URL=https://xxx.supabase.co');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJxxx...');
    process.exit(1);
}

// Create Supabase client
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

// Parse header
const headerLine = lines[0];
const headers = headerLine.split(',').map(h => h.trim());
const collectionIndex = headers.indexOf('collection');

if (collectionIndex === -1) {
    console.error('❌ Column "collection" not found in CSV header');
    console.error('   Available columns:', headers.join(', '));
    process.exit(1);
}

// Extract unique collections
const collectionsSet = new Set();
let fabricCount = 0;

console.log('\n🔍 Extracting collections from CSV...');

for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    
    // Parse CSV line
    const fields = [];
    let currentField = '';
    let inQuotes = false;
    
    for (let j = 0; j < line.length; j++) {
        const char = line[j];
        if (char === '"') {
            inQuotes = !inQuotes;
        } else if (char === ',' && !inQuotes) {
            fields.push(currentField.trim());
            currentField = '';
        } else {
            currentField += char;
        }
    }
    fields.push(currentField.trim());
    
    if (fields.length <= collectionIndex) continue;
    
    const itemType = fields[3]?.toLowerCase() || '';
    const isFabric = fields[6]?.toUpperCase() === 'TRUE' || itemType === 'fabric';
    const collection = fields[collectionIndex]?.trim().replace(/^["']|["']$/g, '') || '';
    
    if (isFabric && collection && collection !== '') {
        fabricCount++;
        collectionsSet.add(collection.toUpperCase());
    }
}

console.log(`\n✅ Found ${fabricCount} fabric items`);
console.log(`📦 Found ${collectionsSet.size} unique collections:`);
Array.from(collectionsSet).sort().forEach(name => {
    console.log(`   - ${name}`);
});

// Create collections
console.log('\n📝 Creating collections in CatalogCollections...');
let createdCount = 0;
let existingCount = 0;
let errorCount = 0;

for (const collectionName of Array.from(collectionsSet).sort()) {
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
        existingCount++;
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
            errorCount++;
        } else {
            console.log(`   ✓ Created collection "${collectionName}" (ID: ${newCollection.id})`);
            createdCount++;
        }
    }
}

// Summary
console.log('\n' + '='.repeat(60));
console.log('📊 SUMMARY');
console.log('='.repeat(60));
console.log(`   Collections found: ${collectionsSet.size}`);
console.log(`   Collections created: ${createdCount}`);
console.log(`   Collections already existing: ${existingCount}`);
console.log(`   Errors: ${errorCount}`);
console.log('='.repeat(60));
console.log('\n✅ Done!');
console.log('\n📋 Next step:');
console.log('   Run the catalog import script to assign collections to items\n');

