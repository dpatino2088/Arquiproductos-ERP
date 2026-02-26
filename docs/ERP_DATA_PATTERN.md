# ERP Data Pattern (full reference)

This document expands on the rules in `.cursor/rules/erp-data-pattern.mdc`. Follow that rule when editing list/detail data, React Query cache, or module tabs.

## Scope convention

- **Literal `'all'`** in scopeKey means "all dealers for the current org". Fetchers: for org users, do not apply `dealer_id` filter; for portal, dealer is fixed by RLS.
- **scopeKey** format: `"${orgId}:${effectiveDealerId ?? 'all'}"`. When `orgId === 'none'`, do not run fetch (no org).
- When optimistic scope briefly shows another dealer's data: show overlay "Switching dealer…", not fullscreen skeleton; hooks keep previous rows until refetch.

## Hydration & acting-as

- Never block **layout** by hydration (no early-return to blank screen due to `!hasHydrated`).
- Skeleton only inside table container when `!hasData && isInitialLoading`; overlay "Updating… / Switching dealer…" when `hasData && isFetching`.
- Effective scope: `effectiveDealerId = activeDealerId ?? lastKnownDealerId ?? null`; scopeKey uses `effectiveDealerId ?? 'all'` so list fetch does not wait for RPC.
- Reconcile: when `current_dealer_id()` returns, if it differs from the one used → overlay "Switching dealer…" + refetch; keep previous rows.
- **Guardrail (localStorage):** use `lastKnownDealerId` only if `lastKnownOrgId === activeOrganizationId`; otherwise fallback to `'all'`.

## List cache policies (when using React Query)

- `staleTime`: at least 10–30s so first navigation does not refetch immediately.
- `gcTime`: 5–15 min so returning to a dealer is instant.
- `refetchOnWindowFocus`: false for lists (avoids flicker in ERP).

## warmModuleQueries / warmListScope

Can include **lists** (Contacts, Customers, Quotes, Proposals, Orders), not only details. Trigger when entering Directory/Sales with a valid scopeKey (org + effectiveDealerId or 'all'). For list hooks that don't use React Query, use `warmListScope(scopeKey, loadFns, cooldownMs)` from `src/lib/zeroLoading.ts` to throttle explicit prefetch (e.g. one per scopeKey per 15s).

## Enabled / scope ready

- Prefer: `enabled: hasOrg && hasEffectiveScope` where `hasEffectiveScope` may be provisional (e.g. from localStorage or 'all').
- `!isHydratingUser` should not block fetch when a fallback scope exists (e.g. 'all').
