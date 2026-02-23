/**
 * Stable scope key for Catalog to avoid refetches from unstable object refs.
 * Primitives only. Use same pattern as Directory (dealer may not affect catalog list depending on RLS).
 */
export function buildCatalogScopeKey(params: {
  orgId: string | null;
  activeDealerId?: string | null;
  userRole: string;
}): string {
  const { orgId, activeDealerId, userRole } = params;
  const dealer = activeDealerId != null && activeDealerId !== '' ? activeDealerId : 'ALL';
  return `${orgId ?? 'none'}:${dealer}:${userRole}`;
}
