import { useMemo } from 'react';
import { useActiveDealer } from './useActiveDealer';
import { useOrganizationContext } from '../context/OrganizationContext';

const LAST_ACTIVE_ORG_KEY = 'last_active_org_id';
const LAST_ACTIVE_DEALER_KEY = 'last_active_dealer_id';

/**
 * Centralized hook for dealer scope used by list hooks (Contacts, Customers, Quotes, Proposals, Orders).
 * Returns a stable scopeKey that changes only when org or dealer changes; list hooks use it as
 * the single dependency for their fetch effect.
 * Scope depends only on activeOrganizationId and activeDealerId (from RPC); useDealers() is for UI only.
 * Literal 'all' means all dealers for the current org (no dealer_id filter); fetchers must interpret it consistently.
 * Optimistic scope: when RPC has not resolved, use lastKnownDealerId from localStorage only if lastKnownOrgId === activeOrganizationId (guardrail).
 */
export function useDealerScope() {
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId, hasHydrated } = useActiveDealer();

  const { effectiveDealerId, scopeKey } = useMemo(() => {
    const orgId = activeOrganizationId ?? 'none';
    const lastKnownOrgId = typeof window !== 'undefined' ? localStorage.getItem(LAST_ACTIVE_ORG_KEY) : null;
    const lastKnownDealerId = typeof window !== 'undefined' ? localStorage.getItem(LAST_ACTIVE_DEALER_KEY) : null;
    const useOptimistic = activeDealerId == null && lastKnownOrgId != null && lastKnownOrgId === activeOrganizationId && lastKnownDealerId != null && lastKnownDealerId !== '';
    const effective = activeDealerId ?? (useOptimistic ? lastKnownDealerId : null) ?? null;
    const key = `${orgId}:${effective ?? 'all'}`;
    return { effectiveDealerId: effective, scopeKey: key };
  }, [activeOrganizationId, activeDealerId]);

  return { activeDealerId, effectiveDealerId, scopeKey, hasHydrated };
}
