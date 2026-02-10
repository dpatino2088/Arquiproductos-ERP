import type { SupabaseClient } from '@supabase/supabase-js';

export type EffectiveOrgAndDealer = {
  orgId: string | null;
  dealerId: string | null;
};

const cache: Map<string, EffectiveOrgAndDealer> = new Map();
const CACHE_KEY_PREFIX = 'dir_effective_';

/**
 * Source of truth para organization_id y dealer_id del usuario actual.
 * Para portal: llama link_portal_user (una vez) y current_dealer_id; cachea por sesión.
 * Para internal: devuelve activeOrgId y activeDealerId (acting-as) si aplica.
 */
export async function getEffectiveOrgAndDealer(
  supabase: SupabaseClient,
  params: {
    activeOrgId: string | null;
    userType: 'internal' | 'portal' | 'unknown';
    activeDealerId?: string | null;
  }
): Promise<EffectiveOrgAndDealer> {
  const { activeOrgId, userType, activeDealerId } = params;
  if (!activeOrgId) {
    return { orgId: null, dealerId: null };
  }

  const cacheKey = `${CACHE_KEY_PREFIX}${activeOrgId}_${userType}_${activeDealerId ?? ''}`;
  const cached = cache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }

  if (userType === 'portal') {
    try {
      await supabase.rpc('link_portal_user', { p_org_id: activeOrgId });
      const { data: dealerId } = await supabase.rpc('current_dealer_id', { p_org_id: activeOrgId });
      const result: EffectiveOrgAndDealer = { orgId: activeOrgId, dealerId: dealerId ?? null };
      cache.set(cacheKey, result);
      return result;
    } catch (e) {
      if (import.meta.env.DEV) {
        console.warn('[getEffectiveOrgAndDealer] portal RPC failed', e);
      }
      const { data: dealerId } = await supabase.rpc('current_dealer_id', { p_org_id: activeOrgId });
      const result: EffectiveOrgAndDealer = { orgId: activeOrgId, dealerId: dealerId ?? null };
      cache.set(cacheKey, result);
      return result;
    }
  }

  const result: EffectiveOrgAndDealer = {
    orgId: activeOrgId,
    dealerId: activeDealerId ?? null,
  };
  cache.set(cacheKey, result);
  return result;
}

/** Limpiar caché (p. ej. al cerrar sesión). */
export function clearDirectoryContextCache(): void {
  cache.clear();
}
