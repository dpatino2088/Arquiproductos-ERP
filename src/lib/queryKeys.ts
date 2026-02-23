/**
 * Query key versioning and builders.
 * When you change fetcher logic (columns, joins, filters), bump the version
 * so React Query does not reuse stale cache from the previous shape.
 */

/** Bump when list fetcher/response shape changes (e.g. after migrations). */
export const LIST_QUERY_VERSION = 'v1' as const;

/** Bump when detail fetcher/response shape changes (roles, components, tiers, etc.). */
export const DETAIL_QUERY_VERSION = 'v1' as const;

/** Detail key convention: ['module','resource','detail', DETAIL_QUERY_VERSION, scopeKey, id] */
export function catalogItemDetailKey(scopeKey: string, id: string): unknown[] {
  return ['catalog', 'items', 'detail', DETAIL_QUERY_VERSION, scopeKey, id];
}

export function directoryContactsListKey(scopeKey: string): unknown[] {
  return ['directory', 'contacts', LIST_QUERY_VERSION, scopeKey];
}

export function directoryCustomersListKey(scopeKey: string): unknown[] {
  return ['directory', 'customers', LIST_QUERY_VERSION, scopeKey];
}

export function catalogItemsListKey(
  scopeKey: string,
  filters: { q: string; categoryId: string; status: string; sortKey: string; page: number; pageSize: number }
): unknown[] {
  return [
    'catalog',
    'items',
    'list',
    LIST_QUERY_VERSION,
    scopeKey,
    filters.q,
    filters.categoryId,
    filters.status,
    filters.sortKey,
    filters.page,
    filters.pageSize,
  ];
}

export function proposalsListKey(scopeKey: string): unknown[] {
  return ['sales', 'proposals', 'list', LIST_QUERY_VERSION, scopeKey];
}

export function proposalDetailKey(scopeKey: string, proposalId: string | null): unknown[] {
  return ['sales', 'proposals', 'detail', DETAIL_QUERY_VERSION, scopeKey, proposalId ?? ''];
}

/** Terms templates list for dealer + doc_type */
export function termsTemplatesListKey(dealerId: string | null, docType: string): unknown[] {
  return ['settings', 'terms-templates', LIST_QUERY_VERSION, dealerId ?? '', docType];
}

/** Default terms template for dealer + doc_type */
export function dealerTermsDefaultKey(dealerId: string | null, docType: string): unknown[] {
  return ['settings', 'dealer-terms-default', LIST_QUERY_VERSION, dealerId ?? '', docType];
}
