/**
 * Shared helpers to defeat PostgREST's default 1000-row cap.
 *
 * - `fetchAllPaginated` pages a query with `.range()` until a short page is seen.
 * - `chunkArray` splits large id arrays so `.in(...)` / RPC `any(...)` calls
 *   also stay under the cap.
 *
 * Used by list hooks (useQuotes, useProposals) so totals/enrichment never get
 * silently truncated no matter how many rows exist.
 */

export const SUPABASE_PAGE_SIZE = 1000;

/** Page through a Supabase query with .range() so results are never capped at the
 *  default 1000-row PostgREST limit. `makeQuery` must return a fresh query each call. */
export async function fetchAllPaginated<T>(
  makeQuery: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>,
  signal?: AbortSignal,
): Promise<T[]> {
  const out: T[] = [];
  let from = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    if (signal?.aborted) return out;
    const { data, error } = await makeQuery(from, from + SUPABASE_PAGE_SIZE - 1);
    if (error) throw error;
    const rows = (data ?? []) as T[];
    out.push(...rows);
    if (rows.length < SUPABASE_PAGE_SIZE) break;
    from += SUPABASE_PAGE_SIZE;
  }
  return out;
}

export function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) chunks.push(arr.slice(i, i + size));
  return chunks;
}
