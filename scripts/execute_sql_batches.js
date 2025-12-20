/**
 * Script to execute SQL batches directly in Supabase
 * Usage: node scripts/execute_sql_batches.js [supabase_url] [service_role_key]
 * 
 * Example: node scripts/execute_sql_batches.js https://xxx.supabase.co eyJxxx...
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments or use environment variables
const supabaseUrl = process.argv[2] || process.env.VITE_SUPABASE_URL || '';
const serviceRoleKey = process.argv[3] || process.env.SUPABASE_SERVICE_ROLE_KEY || '';

if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing required parameters');
    console.error('\nUsage:');
    console.error('  node scripts/execute_sql_batches.js <supabase_url> <service_role_key>');
    console.error('\nOr set environment variables:');
    console.error('  VITE_SUPABASE_URL=https://xxx.supabase.co');
    console.error('  SUPABASE_SERVICE_ROLE_KEY=eyJxxx...');
    console.error('\n⚠️  Note: You need the SERVICE ROLE KEY (not anon key) to execute SQL');
    console.error('   Get it from: Supabase Dashboard > Settings > API > Service Role Key');
    process.exit(1);
}

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

// Function to execute SQL via Supabase REST API
async function executeSQL(sql) {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'apikey': serviceRoleKey,
            'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({ query: sql }),
    });

    if (!response.ok) {
        // Try alternative method: direct SQL execution via PostgREST
        // Since exec_sql might not exist, we'll use a different approach
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return await response.json();
}

// Alternative: Execute SQL using Supabase Management API
async function executeSQLDirect(sql) {
    // Split SQL into individual statements
    const statements = sql
        .split(';')
        .map(s => s.trim())
        .filter(s => s && !s.startsWith('--') && s !== 'BEGIN' && s !== 'COMMIT');

    // For now, we'll use a simpler approach: execute via psql or use Supabase CLI
    // Since direct SQL execution via REST API is limited, we'll provide instructions
    throw new Error('Direct SQL execution via REST API is not available. Please use Supabase CLI or SQL Editor.');
}

// Function to execute batch file
async function executeBatch(batchFile, batchNum, totalBatches) {
    const batchPath = path.join(batchesDir, batchFile);
    const sql = fs.readFileSync(batchPath, 'utf-8');
    const fileSizeKB = (fs.statSync(batchPath).size / 1024).toFixed(2);

    console.log(`\n📄 Executing ${batchFile} (${batchNum}/${totalBatches}, ${fileSizeKB} KB)...`);

    try {
        // Use Supabase Management API or direct HTTP request
        const response = await fetch(`${supabaseUrl}/rest/v1/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': serviceRoleKey,
                'Authorization': `Bearer ${serviceRoleKey}`,
                'Prefer': 'return=minimal',
            },
            body: sql,
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP ${response.status}: ${errorText}`);
        }

        console.log(`✅ Batch ${batchNum} completed successfully`);
        return true;
    } catch (error) {
        console.error(`❌ Error executing batch ${batchNum}:`, error.message);
        
        // If REST API doesn't work, provide alternative instructions
        if (error.message.includes('HTTP 404') || error.message.includes('not available')) {
            console.error('\n⚠️  Direct SQL execution via REST API is not available.');
            console.error('   Please use one of these alternatives:');
            console.error('\n   1. Supabase SQL Editor (recommended):');
            console.error('      - Open Supabase Dashboard > SQL Editor');
            console.error('      - Copy and paste each batch file content');
            console.error('      - Execute sequentially');
            console.error('\n   2. Supabase CLI:');
            console.error('      - Install: npm install -g supabase');
            console.error('      - Run: supabase db execute < batch_file.sql');
            console.error('\n   3. psql (PostgreSQL client):');
            console.error('      - Connect to your Supabase database');
            console.error('      - Run: \\i batch_file.sql');
        }
        
        return false;
    }
}

// Main execution
async function main() {
    console.log('🚀 Starting batch execution...');
    console.log(`📍 Supabase URL: ${supabaseUrl}`);
    console.log(`🔑 Using Service Role Key: ${serviceRoleKey.substring(0, 20)}...\n`);

    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < batchFiles.length; i++) {
        const batchFile = batchFiles[i];
        const batchNum = i + 1;
        const totalBatches = batchFiles.length;

        const success = await executeBatch(batchFile, batchNum, totalBatches);
        
        if (success) {
            successCount++;
        } else {
            failCount++;
            console.error(`\n⚠️  Stopping execution due to error in batch ${batchNum}`);
            break; // Stop on first error
        }

        // Small delay between batches to avoid rate limiting
        if (i < batchFiles.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 500));
        }
    }

    console.log(`\n📊 Execution Summary:`);
    console.log(`   ✅ Successful: ${successCount}/${batchFiles.length}`);
    console.log(`   ❌ Failed: ${failCount}/${batchFiles.length}`);

    if (failCount > 0) {
        process.exit(1);
    }
}

// Run main function
main().catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
});





