/**
 * Split large CollectionsCatalog SQL into smaller batches
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const inputFile = path.join(__dirname, '../database/migrations/direct_insert_collections_catalog.sql');
const outputDir = path.join(__dirname, '../database/migrations/collections_catalog_batches');

// Create output directory
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const content = fs.readFileSync(inputFile, 'utf-8');

// Extract the DO block content
const doBlockMatch = content.match(/DO \$\$([\s\S]*?)\$\$;/);
if (!doBlockMatch) {
  console.error('❌ Could not find DO $$ block');
  process.exit(1);
}

const doBlockContent = doBlockMatch[1];

// Split by "-- Insert" comments, but keep the comment with each block
// Use a regex that captures the comment and the block
const parts = doBlockContent.split(/(-- Insert \d+\/\d+: [^\n]+)/);

const inserts = [];
for (let i = 1; i < parts.length; i += 2) {
  if (parts[i] && parts[i + 1]) {
    const comment = parts[i].trim();
    let block = parts[i + 1].trim();
    
    // Remove the "BEGIN" line and extract just the SQL
    // The block starts with "BEGIN" and contains the INSERT statement
    // We need everything from after "BEGIN" until the "EXCEPTION" or "END;"
    const beginMatch = block.match(/BEGIN\s*\n(.*?)(?=\s*EXCEPTION|\s*END;)/s);
    if (beginMatch) {
      const sqlBlock = beginMatch[1].trim();
      inserts.push({ comment, sqlBlock });
    }
  }
}

console.log(`📊 Found ${inserts.length} INSERT statements`);
console.log(`   Splitting into batches of 100...\n`);

const batchSize = 100;
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
-- Direct Insert: Populate CollectionsCatalog (Batch ${batchNum}/${batches.length})
-- ====================================================
-- Fabrics ${startIdx} to ${endIdx} of ${inserts.length}
-- ====================================================

DO $$
DECLARE
    inserted_count integer := 0;
    not_found_count integer := 0;
    error_count integer := 0;
    total_inserted integer := 0;
BEGIN
    RAISE NOTICE '🚀 Processing batch ${batchNum}/${batches.length} (fabrics ${startIdx}-${endIdx})...';
    RAISE NOTICE '';

${batch.map((item, idx) => {
  const globalIdx = batchIdx * batchSize + idx + 1;
  return `    ${item.comment}
    BEGIN
        ${item.sqlBlock}
        GET DIAGNOSTICS inserted_count = ROW_COUNT;
        total_inserted := total_inserted + inserted_count;
        IF inserted_count = 0 THEN
            not_found_count := not_found_count + 1;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            error_count := error_count + 1;
            RAISE WARNING '   ❌ Error: %', SQLERRM;
    END;`;
}).join('\n\n')}

    RAISE NOTICE '';
    RAISE NOTICE '📊 Batch ${batchNum} Summary:';
    RAISE NOTICE '   ✅ Inserted: % fabrics', total_inserted;
    RAISE NOTICE '   ⚠️  Not found/Skipped: % fabrics', not_found_count;
    RAISE NOTICE '   ❌ Errors: % fabrics', error_count;
END $$;
`;

  const outputFile = path.join(outputDir, `batch_${String(batchNum).padStart(3, '0')}.sql`);
  fs.writeFileSync(outputFile, batchSQL, 'utf-8');
  
  console.log(`   ✅ Created: batch_${String(batchNum).padStart(3, '0')}.sql (${batch.length} fabrics)`);
});

console.log(`\n✅ Created ${batches.length} batch files in: ${outputDir}`);
console.log(`\n💡 Execute batches in order (batch_001.sql, batch_002.sql, etc.)`);

