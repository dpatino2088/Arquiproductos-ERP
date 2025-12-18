/**
 * Direct catalog import from CSV using Supabase client
 * This script reads the CSV and inserts directly via Supabase client
 * 
 * Usage: node scripts/import_catalog_direct.js [supabase_url] [service_role_key]
 */

import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const supabaseUrl = process.argv[2] || process.env.VITE_SUPABASE_URL || '';
const serviceRoleKey = process.argv[3] || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/import_catalog_direct.js <supabase_url> <service_role_key>');
    console.error('\nOr set environment variables:');
    console.error('  VITE_SUPABASE_URL=https://xxx.supabase.co');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJxxx...');
    console.error('\n⚠️  Get Service Role Key from: Supabase Dashboard > Settings > API > Service Role Key');
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
const csvPath = '/Users/diomedespatino/Documents/6.PROGRAMACION/catalog_items_import_DP.csv';
const organizationId = '4de856e8-36ce-480a-952b-a2f5083c69d6';

if (!fs.existsSync(csvPath)) {
    console.error(`❌ CSV file not found: ${csvPath}`);
    process.exit(1);
}

// Parse CSV
function parseCSVLine(line) {
    const fields = [];
    let currentField = '';
    let inQuotes = false;
    let quoteChar = '';

    for (let i = 0; i < line.length; i++) {
        const char = line[i];
        
        if ((char === '"' || char === "'") && (i === 0 || line[i - 1] !== '\\')) {
            if (!inQuotes) {
                inQuotes = true;
                quoteChar = char;
            } else if (char === quoteChar) {
                inQuotes = false;
                quoteChar = '';
            }
            currentField += char;
        } else if (char === ',' && !inQuotes) {
            fields.push(currentField.trim().replace(/^["']|["']$/g, ''));
            currentField = '';
        } else {
            currentField += char;
        }
    }
    fields.push(currentField.trim().replace(/^["']|["']$/g, ''));
    return fields;
}

// Transform row to catalog item
function transformRow(fields) {
    const sku = fields[0] || '';
    const name = fields[1] || '';
    const description = fields[2] || '';
    const itemType = fields[3] || 'component';
    const measureBasis = fields[4] || 'unit';
    const uom = fields[5] || 'unit';
    const isFabric = fields[6] === 'TRUE' || fields[6] === 'true' || fields[6] === '1';
    const rollWidthM = fields[7] || '';
    const fabricPricingMode = fields[8] || '';
    
    // Handle extra value after cost_price
    let unitPrice = fields[8] || '0';
    let costPrice = fields[9] || '0';
    let field10 = fields[10] || '';
    let field11 = fields[11] || '';
    
    // Check if field 10 is extra numeric value
    const isField10Extra = field10 && !isNaN(parseFloat(field10)) && 
        field10.trim() !== 'TRUE' && field10.trim() !== 'FALSE';
    
    let active, discontinued, manufacturer, category, family;
    
    if (isField10Extra) {
        unitPrice = fields[8] || '0';
        costPrice = fields[9] || '0';
        active = fields[11] || 'TRUE';
        discontinued = fields[12] || 'FALSE';
        manufacturer = fields[13] || '';
        category = fields[14] || '';
        family = fields.slice(15).join(' ').trim();
    } else {
        unitPrice = fields[8] || '0';
        costPrice = fields[9] || '0';
        active = fields[10] || 'TRUE';
        discontinued = fields[11] || 'FALSE';
        manufacturer = fields[12] || '';
        category = fields[13] || '';
        family = fields.slice(14).join(' ').trim();
    }
    
    // Build metadata
    const metadata = {};
    if (itemType) metadata.item_type = itemType.toLowerCase();
    if (manufacturer) metadata.manufacturer = manufacturer.trim();
    if (category) metadata.category = category.trim();
    if (family) {
        metadata.family = family.trim();
        if (family.includes(',')) {
            const types = family.split(',').map(t => t.trim()).filter(t => t);
            if (types.length > 0) {
                metadata.compatible_product_types = types;
            }
        }
    }
    
    // Map item_type to valid enum values
    const validItemTypes = ['component', 'fabric', 'linear', 'service', 'accessory'];
    let mappedItemType = itemType.toLowerCase();
    if (!validItemTypes.includes(mappedItemType)) {
        // Auto-determine based on other fields
        if (isFabric) {
            mappedItemType = 'fabric';
        } else if (measureBasis === 'linear_m') {
            mappedItemType = 'linear';
        } else {
            mappedItemType = 'component';
        }
    }

    return {
        organization_id: organizationId,
        sku: sku.trim(),
        name: name.trim(),
        description: description || null,
        item_type: mappedItemType, // Add item_type column
        measure_basis: measureBasis.toLowerCase(),
        uom: uom.trim(),
        is_fabric: isFabric,
        roll_width_m: rollWidthM ? parseFloat(rollWidthM) : null,
        fabric_pricing_mode: fabricPricingMode || null,
        unit_price: parseFloat(unitPrice) || 0,
        cost_price: parseFloat(costPrice) || 0,
        active: active === 'TRUE' || active === 'true' || active === '1' || active === '',
        discontinued: discontinued === 'TRUE' || discontinued === 'true' || discontinued === '1',
        metadata,
    };
}

// Main execution
async function main() {
    console.log('🚀 Starting direct catalog import...');
    console.log(`📍 Supabase URL: ${supabaseUrl}`);
    console.log(`🔑 Using Service Role Key: ${serviceRoleKey.substring(0, 20)}...\n`);

    const csvContent = fs.readFileSync(csvPath, 'utf-8');
    const lines = csvContent.split('\n').filter(line => line.trim() !== '');
    
    // Skip header
    const dataLines = lines.slice(1);
    
    console.log(`📊 Total rows to process: ${dataLines.length}\n`);

    const batchSize = 100;
    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < dataLines.length; i += batchSize) {
        const batch = dataLines.slice(i, i + batchSize);
        const batchNum = Math.floor(i / batchSize) + 1;
        const totalBatches = Math.ceil(dataLines.length / batchSize);

        console.log(`📦 Processing batch ${batchNum}/${totalBatches} (rows ${i + 1}-${Math.min(i + batchSize, dataLines.length)})...`);

        const items = [];
        for (const line of batch) {
            try {
                const fields = parseCSVLine(line);
                if (fields[0] && fields[1]) { // SKU and name required
                    const item = transformRow(fields);
                    items.push(item);
                }
            } catch (error) {
                console.error(`   ⚠️  Error parsing row: ${error.message}`);
                failCount++;
            }
        }

        if (items.length > 0) {
            try {
                const { error } = await supabase
                    .from('CatalogItems')
                    .upsert(items, { onConflict: 'organization_id,sku' });

                if (error) {
                    console.error(`   ❌ Error inserting batch: ${error.message}`);
                    failCount += items.length;
                } else {
                    successCount += items.length;
                    console.log(`   ✅ Inserted ${items.length} items`);
                }
            } catch (error) {
                console.error(`   ❌ Fatal error in batch: ${error.message}`);
                failCount += items.length;
            }
        }

        // Small delay between batches
        if (i + batchSize < dataLines.length) {
            await new Promise(resolve => setTimeout(resolve, 500));
        }
    }

    console.log(`\n📊 Final Summary:`);
    console.log(`   ✅ Successful: ${successCount} items`);
    console.log(`   ❌ Failed: ${failCount} items`);
    console.log(`   📈 Success rate: ${((successCount / (successCount + failCount)) * 100).toFixed(2)}%`);

    if (failCount > 0) {
        console.log(`\n⚠️  Some items failed to import. Review errors above.`);
        process.exit(1);
    } else {
        console.log(`\n🎉 All items imported successfully!`);
    }
}

main().catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
});

