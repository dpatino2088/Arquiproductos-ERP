/**
 * Script to split large SQL file into smaller batches
 * Usage: node scripts/split_sql_into_batches.js <sql_file_path> <batch_size>
 * 
 * Example: node scripts/split_sql_into_batches.js database/migrations/import_catalog_items_generated.sql 200
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const sqlFilePath = process.argv[2];
const batchSize = parseInt(process.argv[3]) || 200; // Default 200 INSERTs per batch

if (!sqlFilePath) {
    console.error('Usage: node scripts/split_sql_into_batches.js <sql_file_path> [batch_size]');
    process.exit(1);
}

// Read SQL file
const sqlContent = fs.readFileSync(sqlFilePath, 'utf-8');
const lines = sqlContent.split('\n');

// Find BEGIN and COMMIT lines
const beginLine = lines.findIndex(line => line.trim() === 'BEGIN;');
const commitLine = lines.findIndex(line => line.trim() === 'COMMIT;');

if (beginLine === -1 || commitLine === -1) {
    console.error('❌ Could not find BEGIN or COMMIT statements in SQL file');
    process.exit(1);
}

// Extract header (everything before BEGIN)
const header = lines.slice(0, beginLine + 1).join('\n');

// Extract INSERT statements (everything between BEGIN and COMMIT)
const insertStatements = [];
let currentStatement = '';
let inStatement = false;

for (let i = beginLine + 1; i < commitLine; i++) {
    const line = lines[i];
    
    if (line.trim().startsWith('INSERT INTO')) {
        if (currentStatement) {
            insertStatements.push(currentStatement.trim());
        }
        currentStatement = line;
        inStatement = true;
    } else if (inStatement) {
        currentStatement += '\n' + line;
        if (line.trim().endsWith(';')) {
            insertStatements.push(currentStatement.trim());
            currentStatement = '';
            inStatement = false;
        }
    }
}

// Add last statement if exists
if (currentStatement) {
    insertStatements.push(currentStatement.trim());
}

console.log(`📊 Total INSERT statements: ${insertStatements.length}`);
console.log(`📦 Batch size: ${batchSize} statements per file`);
console.log(`📁 Will create ${Math.ceil(insertStatements.length / batchSize)} batch files\n`);

// Create output directory
const outputDir = path.join(path.dirname(sqlFilePath), 'import_batches');
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

// Split into batches
const totalBatches = Math.ceil(insertStatements.length / batchSize);

for (let batchNum = 0; batchNum < totalBatches; batchNum++) {
    const startIdx = batchNum * batchSize;
    const endIdx = Math.min(startIdx + batchSize, insertStatements.length);
    const batchStatements = insertStatements.slice(startIdx, endIdx);
    
    // Create batch file
    const batchContent = `${header}

-- Batch ${batchNum + 1} of ${totalBatches}
-- Items ${startIdx + 1} to ${endIdx} of ${insertStatements.length}

${batchStatements.join('\n\n')}

COMMIT;
`;

    const batchFileName = `import_catalog_items_batch_${String(batchNum + 1).padStart(3, '0')}.sql`;
    const batchFilePath = path.join(outputDir, batchFileName);
    
    fs.writeFileSync(batchFilePath, batchContent, 'utf-8');
    
    const fileSizeKB = (fs.statSync(batchFilePath).size / 1024).toFixed(2);
    console.log(`✅ Created: ${batchFileName} (${batchStatements.length} statements, ${fileSizeKB} KB)`);
}

console.log(`\n✅ All batches created in: ${outputDir}`);
console.log(`\n💡 Next steps:`);
console.log(`   1. Go to Supabase SQL Editor`);
console.log(`   2. Execute each batch file sequentially (batch_001, batch_002, etc.)`);
console.log(`   3. Wait for each batch to complete before running the next one`);













