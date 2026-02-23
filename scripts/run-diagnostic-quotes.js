#!/usr/bin/env node
/**
 * Run DIAGNOSTIC_QUOTES_DEALER_FILTER.sql against Postgres.
 * Uses DATABASE_URL (default: local Supabase from supabase status).
 *
 * From repo root:
 *   node scripts/run-diagnostic-quotes.js
 * Or with production DB (from Supabase Dashboard → Settings → Database → Connection string):
 *   DATABASE_URL="postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres" node scripts/run-diagnostic-quotes.js
 */

import pg from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const sqlPath = join(root, 'database', 'DIAGNOSTIC_QUOTES_DEALER_FILTER.sql');

const databaseUrl =
  process.env.DATABASE_URL ||
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

async function main() {
  const client = new pg.Client({ connectionString: databaseUrl });
  try {
    await client.connect();
    const sql = readFileSync(sqlPath, 'utf8');
    const statements = sql
      .split(/;\s*\n/)
      .map((s) =>
        s
          .replace(/^\s*--[^\n]*\n?/gm, '')
          .replace(/\n\s*--[^\n]*/g, '\n')
          .trim()
      )
      .filter((s) => s.length > 0 && /^\s*SELECT/i.test(s));

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      if (!stmt) continue;
      try {
        const res = await client.query(stmt + ';');
        console.log('\n--- Query', i + 1, '---');
        if (res.rows && res.rows.length > 0) {
          console.table(res.rows);
        } else {
          console.log('(0 rows)');
        }
      } catch (err) {
        console.error('\n--- Query', i + 1, 'error ---', err.message);
      }
    }
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
