/**
 * Script to update CatalogItems with Collection and Variant from CSV
 * This updates the metadata field in CatalogItems before populating CollectionsCatalog
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import Papa from 'papaparse';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../.env.local') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env.local');
  console.error('   Required: VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// CSV file path
const csvPath = path.join(__dirname, '../../catalog_items_import_DP_COLLECTIONS.csv');

async function updateCatalogItems() {
  console.log('🚀 Starting to update CatalogItems with Collection and Variant...\n');

  // Read CSV file
  if (!fs.existsSync(csvPath)) {
    console.error(`❌ CSV file not found: ${csvPath}`);
    process.exit(1);
  }

  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  
  // Parse CSV
  const parseResult = Papa.parse(csvContent, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => {
      // Normalize header names (handle typo "Colletion")
      if (header.toLowerCase() === 'colletion') return 'collection';
      return header.toLowerCase().trim();
    }
  });

  if (parseResult.errors.length > 0) {
    console.warn('⚠️  CSV parsing warnings:');
    parseResult.errors.forEach(err => console.warn('   ', err));
  }

  const rows = parseResult.data;
  console.log(`📊 Found ${rows.length} rows in CSV\n`);

  let updated = 0;
  let skipped = 0;
  let errors = 0;
  let fabricsFound = 0;

  // Process each row
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    
    // Skip if not a fabric
    if (row.is_fabric !== 'TRUE' && row.is_fabric !== 'true') {
      continue;
    }

    fabricsFound++;

    const sku = row.sku?.trim();
    const collection = row.collection?.trim() || row.colletion?.trim(); // Handle typo
    const variant = row.variant?.trim();

    if (!sku) {
      console.warn(`⚠️  Row ${i + 1}: Missing SKU, skipping`);
      skipped++;
      continue;
    }

    // Only process if we have collection or variant
    if (!collection && !variant) {
      if (updated + errors < 10) {
        console.log(`   ⏭️  Skipping ${sku}: No collection or variant`);
      }
      skipped++;
      continue;
    }

    try {
      // Find the CatalogItem by SKU
      const { data: items, error: findError } = await supabase
        .from('CatalogItems')
        .select('id, sku, name, metadata, organization_id')
        .eq('sku', sku)
        .eq('deleted', false)
        .limit(1);

      if (findError) {
        console.error(`❌ Error finding item with SKU ${sku}:`, findError.message);
        errors++;
        continue;
      }

      if (!items || items.length === 0) {
        if (updated + errors < 10) {
          console.log(`   ⏭️  SKU ${sku} not found in CatalogItems`);
        }
        skipped++;
        continue;
      }

      const item = items[0];
      
      // Prepare metadata update
      const currentMetadata = item.metadata || {};
      const updatedMetadata = {
        ...currentMetadata,
        ...(collection && { collection: collection, collection_name: collection }),
        ...(variant && { variant: variant, variant_name: variant })
      };

      // Update CatalogItem metadata
      const { error: updateError } = await supabase
        .from('CatalogItems')
        .update({
          metadata: updatedMetadata
        })
        .eq('id', item.id);

      if (updateError) {
        console.error(`❌ Error updating ${sku}:`, updateError.message);
        errors++;
        continue;
      }

      updated++;

      if (updated <= 10) {
        console.log(`   ✅ Updated: ${sku} | Collection: ${collection || 'N/A'} | Variant: ${variant || 'N/A'}`);
      } else if (updated % 100 === 0) {
        console.log(`   📊 Updated ${updated} fabrics...`);
      }

    } catch (error) {
      console.error(`❌ Error processing ${sku}:`, error.message);
      errors++;
    }
  }

  console.log('\n📊 Summary:');
  console.log(`   Total fabrics in CSV: ${fabricsFound}`);
  console.log(`   ✅ Updated: ${updated}`);
  console.log(`   ⏭️  Skipped: ${skipped}`);
  console.log(`   ❌ Errors: ${errors}`);
  console.log('\n✅ Update completed!');
  console.log('\n💡 Next step: Run populate_collections_catalog_from_csv_data.sql to populate CollectionsCatalog');
}

// Run the script
updateCatalogItems().catch(console.error);





