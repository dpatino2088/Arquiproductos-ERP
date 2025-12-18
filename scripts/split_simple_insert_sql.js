/**
 * Split simple INSERT SQL into smaller batches
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const inputFile = path.join(__dirname, '../database/migrations/simple_insert_collections_catalog.sql');
const outputDir = path.join(__dirname, '../database/migrations/collections_catalog_simple_batches');

// Create output directory
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const content = fs.readFileSync(inputFile, 'utf-8');

// Split by INSERT statements (each INSERT is one fabric)
// Pattern: -- Insert X: SKU | Collection | Variant\nINSERT INTO...\nON CONFLICT...\n;
const lines = content.split('\n');
const inserts = [];
let currentInsert = '';

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  // Start of new INSERT
  if (line.startsWith('-- Insert ')) {
    // Save previous INSERT if exists
    if (currentInsert.trim()) {
      inserts.push(currentInsert.trim());
    }
    currentInsert = line + '\n';
  } else if (currentInsert) {
    // Continue building current INSERT
    currentInsert += line + '\n';
    
    // End of INSERT (semicolon on its own line or after ON CONFLICT)
    if (line.trim() === ';' && currentInsert.includes('ON CONFLICT')) {
      inserts.push(currentInsert.trim());
      currentInsert = '';
    }
  }
}

// Don't forget the last one
if (currentInsert.trim()) {
  inserts.push(currentInsert.trim());
}

console.log(`📊 Found ${inserts.length} INSERT statements`);
console.log(`   Splitting into batches of 50...\n`);

const batchSize = 50; // Smaller batches for easier execution
const batches = [];

for (let i = 0; i < inserts.length; i += batchSize) {
  batches.push(inserts.slice(i, i + batchSize));
}

// Generate batch files
batches.forEach((batch, batchIdx) => {
  const batchNum = batchIdx + 1;
  const startIdx = batchIdx * batchSize + 1;
  const endIdx = Math.min(startIdx + batch.length - 1, inserts.length);
  
  const batchSQL = `-- ====================================================
-- SIMPLE Direct Insert: Populate CollectionsCatalog (Batch ${batchNum}/${batches.length})
-- ====================================================
-- Fabrics ${startIdx} to ${endIdx} of ${inserts.length}
-- ====================================================
-- 
-- INSTRUCCIONES:
-- 1. Ejecuta este batch en Supabase SQL Editor
-- 2. Si hay errores, verás exactamente qué INSERT falló
-- 3. El ON CONFLICT evitará duplicados automáticamente
-- ====================================================

${batch.join('\n\n')}

-- ====================================================
-- Verification Query (for this batch)
-- ====================================================

SELECT 
    'Batch ${batchNum} completed' as status,
    COUNT(*) as total_inserted
FROM "CollectionsCatalog"
WHERE deleted = false;
`;

  const outputFile = path.join(outputDir, `simple_batch_${String(batchNum).padStart(3, '0')}.sql`);
  fs.writeFileSync(outputFile, batchSQL, 'utf-8');
  
  console.log(`   ✅ Created: simple_batch_${String(batchNum).padStart(3, '0')}.sql (${batch.length} fabrics)`);
});

console.log(`\n✅ Created ${batches.length} batch files in: ${outputDir}`);
console.log(`\n💡 Execute batches in order (simple_batch_001.sql, simple_batch_002.sql, etc.)`);
console.log(`   Each batch has 50 fabrics - easier to debug if something fails!`);

