/**
 * Script to add a "collection" column to the CSV file based on SKU patterns
 * This will help you manually review and adjust collections before importing
 * 
 * Usage: node scripts/add_collection_column_to_csv.js <input_csv> <output_csv>
 * 
 * Example: node scripts/add_collection_column_to_csv.js ../catalog_items_import_DP.csv ../catalog_items_import_DP_with_collections.csv
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const inputCsvPath = process.argv[2];
const outputCsvPath = process.argv[3];

if (!inputCsvPath) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/add_collection_column_to_csv.js <input_csv> [output_csv]');
    console.error('\nExample:');
    console.error('  node scripts/add_collection_column_to_csv.js ../catalog_items_import_DP.csv ../catalog_items_import_DP_with_collections.csv');
    process.exit(1);
}

const outputPath = outputCsvPath || inputCsvPath.replace('.csv', '_with_collections.csv');

// Read CSV file
console.log(`\n📖 Reading CSV file: ${inputCsvPath}`);
const csvContent = fs.readFileSync(inputCsvPath, 'utf-8');
const lines = csvContent.split('\n').filter(line => line.trim() !== '');

// Parse header
const headerLine = lines[0];
const headers = headerLine.split(',').map(h => h.trim());

// Check if collection column already exists
if (headers.includes('collection')) {
    console.log('⚠️  Column "collection" already exists in CSV. Skipping...');
    process.exit(0);
}

// Add collection column after family (or at the end if family doesn't exist)
const familyIndex = headers.indexOf('family');
const insertIndex = familyIndex >= 0 ? familyIndex + 1 : headers.length;
headers.splice(insertIndex, 0, 'collection');

// Function to extract collection from SKU
function extractCollectionFromSku(sku) {
    if (!sku || sku === '') return '';
    
    // Pattern 1: DRF-{COLLECTION}-{VARIANT} (e.g., DRF-BLOCK-0100)
    let match = sku.match(/^DRF-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 2: RF-{COLLECTION}-{VARIANT}
    match = sku.match(/^RF-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 3: F-{COLLECTION}-{VARIANT}
    match = sku.match(/^F-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 4: PF-HC45-{COLLECTION}-{VARIANT} (e.g., PF-HC45-DEVON-0300)
    match = sku.match(/^PF-HC45-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 5: SCR-{COLLECTION}-{VARIANT} (e.g., SCR-AMAZON-31-300)
    match = sku.match(/^SCR-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 6: SCA5-{COLLECTION}-{VARIANT} (e.g., SCA5-LINEN-01-250)
    match = sku.match(/^SCA5-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 7: SCR3-{COLLECTION}-{VARIANT} (e.g., SCR3-SATINE-01-300)
    match = sku.match(/^SCR3-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 8: SCR5-{COLLECTION}-{VARIANT} (e.g., SCR5-EXPLORE-20-300)
    match = sku.match(/^SCR5-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // Pattern 9: SFN-{COLLECTION}-{VARIANT} (e.g., SFN-20003-7100-285-M)
    match = sku.match(/^SFN-([A-Z0-9]+(?:-[A-Z0-9]+)*?)-/i);
    if (match) {
        return match[1].toUpperCase();
    }
    
    // If no pattern matches, return empty string (user can fill manually)
    return '';
}

// Process data lines
console.log('\n🔍 Processing lines and extracting collections...');
const newLines = [headers.join(',')];
let fabricCount = 0;
let collectionCount = 0;
let noCollectionCount = 0;

for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    
    // Parse CSV line (handling quoted fields)
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
    fields.push(currentField.trim()); // Last field
    
    if (fields.length < 1) {
        newLines.push(line);
        continue;
    }
    
    const sku = fields[0] || '';
    const itemType = fields[3]?.toLowerCase() || '';
    const isFabric = fields[6]?.toUpperCase() === 'TRUE' || itemType === 'fabric';
    
    // Extract collection
    let collection = '';
    if (isFabric) {
        fabricCount++;
        collection = extractCollectionFromSku(sku);
        if (collection) {
            collectionCount++;
        } else {
            noCollectionCount++;
        }
    }
    
    // Insert collection field at the correct position
    fields.splice(insertIndex, 0, collection);
    
    // Rebuild line with proper CSV formatting (handle commas in fields)
    const formattedFields = fields.map(field => {
        if (field.includes(',') || field.includes('"') || field.includes('\n')) {
            return `"${field.replace(/"/g, '""')}"`;
        }
        return field;
    });
    
    newLines.push(formattedFields.join(','));
}

// Write new CSV
console.log(`\n💾 Writing new CSV to: ${outputPath}`);
fs.writeFileSync(outputPath, newLines.join('\n'));

// Summary
console.log('\n' + '='.repeat(60));
console.log('📊 SUMMARY');
console.log('='.repeat(60));
console.log(`   Total lines processed: ${lines.length - 1}`);
console.log(`   Fabric items found: ${fabricCount}`);
console.log(`   Collections extracted: ${collectionCount}`);
console.log(`   Fabrics without collection: ${noCollectionCount}`);
console.log(`   Output file: ${outputPath}`);
console.log('='.repeat(60));
console.log('\n✅ Done!');
console.log('\n📋 Next steps:');
console.log('   1. Review the CSV file and fill in empty "collection" values');
console.log('   2. Adjust collection names if needed');
console.log('   3. Use the updated CSV for import\n');

