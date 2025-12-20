/**
 * Script to execute catalog import batches using Supabase client
 * This script parses INSERT statements and executes them via Supabase client
 * 
 * Usage: node scripts/execute_catalog_import.js [supabase_url] [service_role_key]
 */

import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments or use environment variables
const supabaseUrl = process.argv[2] || process.env.VITE_SUPABASE_URL || '';
const serviceRoleKey = process.argv[3] || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/execute_catalog_import.js <supabase_url> <service_role_key>');
    console.error('\nOr set environment variables:');
    console.error('  VITE_SUPABASE_URL=https://xxx.supabase.co');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJxxx...');
    console.error('\n⚠️  Note: You need the SERVICE ROLE KEY (not anon key)');
    console.error('   Get it from: Supabase Dashboard > Settings > API > Service Role Key');
    process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false,
    },
});

// Find all batch files
const batchesDir = path.join(__dirname, '..', 'database', 'migrations', 'import_batches');
const batchFiles = fs.readdirSync(batchesDir)
    .filter(file => file.startsWith('import_catalog_items_batch_') && file.endsWith('.sql'))
    .sort();

if (batchFiles.length === 0) {
    console.error(`❌ No batch files found in ${batchesDir}`);
    process.exit(1);
}

console.log(`📦 Found ${batchFiles.length} batch files to execute\n`);

// Function to parse INSERT statement and extract values
function parseInsertStatement(sql) {
    // Extract VALUES clause
    const valuesMatch = sql.match(/VALUES\s*\((.*?)\)/s);
    if (!valuesMatch) return null;

    const valuesStr = valuesMatch[1];
    
    // Parse values (handling nested structures)
    const values = [];
    let current = '';
    let depth = 0;
    let inQuotes = false;
    let quoteChar = '';

    for (let i = 0; i < valuesStr.length; i++) {
        const char = valuesStr[i];
        const nextChar = valuesStr[i + 1];

        if ((char === "'" || char === '"') && (i === 0 || valuesStr[i - 1] !== '\\')) {
            if (!inQuotes) {
                inQuotes = true;
                quoteChar = char;
            } else if (char === quoteChar) {
                inQuotes = false;
                quoteChar = '';
            }
            current += char;
        } else if (char === '(' && !inQuotes) {
            depth++;
            current += char;
        } else if (char === ')' && !inQuotes) {
            depth--;
            current += char;
        } else if (char === ',' && depth === 0 && !inQuotes) {
            values.push(current.trim());
            current = '';
        } else {
            current += char;
        }
    }
    if (current.trim()) {
        values.push(current.trim());
    }

    // Convert to proper types
    return values.map(v => {
        v = v.trim();
        if (v === 'NULL' || v === '') return null;
        if (v === 'true') return true;
        if (v === 'false') return false;
        if (v.startsWith("'") && v.endsWith("'")) {
            return v.slice(1, -1).replace(/''/g, "'");
        }
        if (v.startsWith('"') && v.endsWith('"')) {
            return v.slice(1, -1);
        }
        if (!isNaN(v) && v !== '') {
            return parseFloat(v);
        }
        // Handle ::uuid, ::measure_basis, ::jsonb casts
        if (v.includes('::')) {
            const [value, type] = v.split('::');
            if (type === 'uuid') {
                return value.replace(/['"]/g, '');
            }
            if (type === 'jsonb') {
                try {
                    return JSON.parse(value.replace(/['"]/g, ''));
                } catch {
                    return value.replace(/['"]/g, '');
                }
            }
            return value.replace(/['"]/g, '');
        }
        return v;
    });
}

// Function to execute a single INSERT statement
async function executeInsert(sql) {
    try {
        // Extract table name and columns
        const tableMatch = sql.match(/INSERT INTO\s+"?(\w+)"?\s*\(([^)]+)\)/i);
        if (!tableMatch) {
            throw new Error('Could not parse INSERT statement');
        }

        const tableName = tableMatch[1];
        const columnsStr = tableMatch[2];
        const columns = columnsStr.split(',').map(c => c.trim().replace(/"/g, ''));

        // Parse values
        const values = parseInsertStatement(sql);
        if (!values || values.length !== columns.length) {
            throw new Error(`Value count mismatch: ${values?.length} vs ${columns.length}`);
        }

        // Build data object
        const data = {};
        columns.forEach((col, idx) => {
            data[col] = values[idx];
        });

        // Check for ON CONFLICT clause
        const hasConflict = sql.includes('ON CONFLICT');
        
        if (hasConflict) {
            // Use upsert
            const { error } = await supabase
                .from(tableName)
                .upsert(data, { onConflict: 'organization_id,sku' });
            
            if (error) throw error;
        } else {
            // Use insert
            const { error } = await supabase
                .from(tableName)
                .insert(data);
            
            if (error) throw error;
        }

        return true;
    } catch (error) {
        throw new Error(`Failed to execute INSERT: ${error.message}`);
    }
}

// Function to execute batch file
async function executeBatch(batchFile, batchNum, totalBatches) {
    const batchPath = path.join(batchesDir, batchFile);
    const sql = fs.readFileSync(batchPath, 'utf-8');
    const fileSizeKB = (fs.statSync(batchPath).size / 1024).toFixed(2);

    console.log(`\n📄 Processing ${batchFile} (${batchNum}/${totalBatches}, ${fileSizeKB} KB)...`);

    // Extract INSERT statements
    const insertStatements = [];
    const lines = sql.split('\n');
    let currentStatement = '';
    let inStatement = false;

    for (const line of lines) {
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

    if (currentStatement) {
        insertStatements.push(currentStatement.trim());
    }

    console.log(`   Found ${insertStatements.length} INSERT statements`);

    // Execute each INSERT
    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < insertStatements.length; i++) {
        try {
            await executeInsert(insertStatements[i]);
            successCount++;
            
            // Progress indicator
            if ((i + 1) % 50 === 0) {
                process.stdout.write(`   Progress: ${i + 1}/${insertStatements.length}\r`);
            }
        } catch (error) {
            failCount++;
            console.error(`\n   ❌ Error in statement ${i + 1}: ${error.message}`);
            // Continue with next statement
        }
    }

    console.log(`\n   ✅ Completed: ${successCount} successful, ${failCount} failed`);

    return failCount === 0;
}

// Main execution
async function main() {
    console.log('🚀 Starting catalog import execution...');
    console.log(`📍 Supabase URL: ${supabaseUrl}`);
    console.log(`🔑 Using Service Role Key: ${serviceRoleKey.substring(0, 20)}...\n`);

    let totalSuccess = 0;
    let totalFail = 0;

    for (let i = 0; i < batchFiles.length; i++) {
        const batchFile = batchFiles[i];
        const batchNum = i + 1;
        const totalBatches = batchFiles.length;

        const success = await executeBatch(batchFile, batchNum, totalBatches);
        
        if (success) {
            totalSuccess++;
        } else {
            totalFail++;
            // Continue with next batch even if one fails
        }

        // Small delay between batches
        if (i < batchFiles.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }

    console.log(`\n📊 Final Summary:`);
    console.log(`   ✅ Successful batches: ${totalSuccess}/${batchFiles.length}`);
    console.log(`   ❌ Failed batches: ${totalFail}/${batchFiles.length}`);

    if (totalFail > 0) {
        console.log(`\n⚠️  Some batches failed. Review the errors above.`);
        process.exit(1);
    } else {
        console.log(`\n🎉 All batches executed successfully!`);
    }
}

// Run main function
main().catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
});





