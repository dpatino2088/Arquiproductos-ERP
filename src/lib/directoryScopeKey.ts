/**
 * Stable scope key for Directory (and other modules) to avoid refetches from unstable object refs.
 * Use only primitives so queryKey does not change unless scope actually changes.
 */
export function buildDirectoryScopeKey(params: {
  orgId: string | null;
  activeDealerId: string | null;
  userRole: string;
}): string {
  const { orgId, activeDealerId, userRole } = params;
  const dealer = activeDealerId != null && activeDealerId !== '' ? activeDealerId : 'ALL';
  return `${orgId ?? 'none'}:${dealer}:${userRole}`;
}
