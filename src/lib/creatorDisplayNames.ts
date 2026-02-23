/**
 * Resuelve nombres de creadores para Proposals, Quotes, Contacts y Customers.
 *
 * Modelo: solo created_by_user_id (auth.users.id).
 * created_by_portal_user_id es legacy y fue eliminada.
 *
 * Resolución: auth_user_id → AppUsers (display_name/email) o DealerUsers (portal_user_name)
 * si no existe en AppUsers (usuarios portal).
 */

import { supabase } from './supabase/client';

const cache = new Map<string, string>();

export interface CreatorDisplayNames {
  /** auth_user_id (auth.users.id) → display name */
  byAuthUserId: Map<string, string>;
}

export async function getCreatorDisplayNames(params: {
  authUserIds: string[];
}): Promise<CreatorDisplayNames> {
  const authIds = [...new Set(params.authUserIds)].filter((id): id is string => !!id);
  const byAuthUserId = new Map<string, string>();

  const missing: string[] = [];
  for (const id of authIds) {
    const cached = cache.get(id);
    if (cached !== undefined) {
      byAuthUserId.set(id, cached);
    } else {
      missing.push(id);
    }
  }

  if (missing.length > 0) {
    // 1. Intentar AppUsers
    const { data: appData } = await supabase
      .from('AppUsers')
      .select('auth_user_id, display_name, email')
      .in('auth_user_id', missing);

    for (const id of missing) {
      const row = (appData || []).find((r: { auth_user_id: string }) => r.auth_user_id === id);
      if (row) {
        const value = row?.display_name?.trim() || row?.email?.trim() || null;
        const display = value || '—';
        cache.set(id, display);
        byAuthUserId.set(id, display);
      }
    }

    // 2. Fallback: DealerUsers (user_id = auth.users.id) para usuarios portal
    const stillMissing = missing.filter((id) => !byAuthUserId.has(id));
    if (stillMissing.length > 0) {
      const { data: dealerData } = await supabase
        .from('DealerUsers')
        .select('user_id, portal_user_name, portal_user_email')
        .in('user_id', stillMissing);

      for (const id of stillMissing) {
        const row = (dealerData || []).find((r: { user_id: string }) => r.user_id === id);
        const value = row?.portal_user_name?.trim() || row?.portal_user_email?.trim() || null;
        const display = value || '—';
        cache.set(id, display);
        byAuthUserId.set(id, display);
      }
    }

    // IDs no encontrados
    for (const id of missing) {
      if (!byAuthUserId.has(id)) {
        byAuthUserId.set(id, '—');
      }
    }
  }

  return { byAuthUserId };
}
