/**
 * Helper reutilizable: fetch AppUsers display_name by ids (batch + cache).
 * Usado por Quotes, QuoteLines y Proposals para columnas "Created by" / "Quote created by".
 *
 * - Dedupe de ids (Set); si ids vacío retorna Map vacío y no llama a Supabase.
 * - Una sola query: .in('id', ids) a public."AppUsers".
 * - Cache en memoria (Map) por sesión para no pedir AppUsers repetido.
 * - Fallback: map.get(id) ?? 'Legacy / Imported' (null o no encontrado).
 *
 * Regla: ERP internal usa created_by_user_id; portal puede usar created_by_portal_user_id después.
 * Verificación manual: docs/CREATED_BY_VERIFICATION.md
 */

import { supabase } from './supabase/client';

const cache = new Map<string, string>();

export async function getAppUsersDisplayNames(ids: string[]): Promise<Map<string, string>> {
  const deduped = [...new Set(ids)].filter((id): id is string => !!id);
  if (deduped.length === 0) return new Map();

  const result = new Map<string, string>();
  const missing: string[] = [];

  for (const id of deduped) {
    const cached = cache.get(id);
    if (cached !== undefined) {
      result.set(id, cached);
    } else {
      missing.push(id);
    }
  }

  if (missing.length > 0) {
    const { data } = await supabase
      .from('AppUsers')
      .select('id, display_name')
      .in('id', missing);

    for (const id of missing) {
      const row = (data || []).find((r: { id: string }) => r.id === id);
      const value = row?.display_name ?? 'Legacy / Imported';
      cache.set(id, value);
      result.set(id, value);
    }
  }

  return result;
}
