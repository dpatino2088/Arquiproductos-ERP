/**
 * Query key versioning and builders.
 * When you change fetcher logic (columns, joins, filters), bump the version
 * so React Query does not reuse stale cache from the previous shape.
 */

/** Bump when list fetcher/response shape changes (e.g. after migrations). */
export const LIST_QUERY_VERSION = 'v1' as const;

/** Bump when detail fetcher/response shape changes (roles, components, tiers, etc.). */
export const DETAIL_QUERY_VERSION = 'v2' as const;

/** Detail key convention: ['module','resource','detail', DETAIL_QUERY_VERSION, scopeKey, id] */
export function catalogItemDetailKey(scopeKey: string, id: string): unknown[] {
  return ['catalog', 'items', 'detail', DETAIL_QUERY_VERSION, scopeKey, id];
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

/** BOM Templates list for an organization */
export function bomTemplatesListKey(scopeKey: string): unknown[] {
  return ['catalog', 'bom-templates', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** BOM Template detail (template + components) */
export function bomTemplateDetailKey(scopeKey: string, templateId: string): unknown[] {
  return ['catalog', 'bom-templates', 'detail', DETAIL_QUERY_VERSION, scopeKey, templateId];
}

/** Sales Orders list */
export function salesOrdersListKey(scopeKey: string): unknown[] {
  return ['sales', 'orders', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Sales Order detail */
export function salesOrderDetailKey(scopeKey: string, soId: string): unknown[] {
  return ['sales', 'orders', 'detail', DETAIL_QUERY_VERSION, scopeKey, soId];
}

/** Manufacturing Orders list */
export function manufacturingOrdersListKey(scopeKey: string): unknown[] {
  return ['manufacturing', 'orders', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Manufacturing Order detail */
export function manufacturingOrderDetailKey(scopeKey: string, moId: string): unknown[] {
  return ['manufacturing', 'orders', 'detail', DETAIL_QUERY_VERSION, scopeKey, moId];
}

/** Payments for a Sales Order */
export function paymentsListKey(scopeKey: string, soId: string): unknown[] {
  return ['sales', 'payments', 'list', LIST_QUERY_VERSION, scopeKey, soId];
}

/** Activity timeline for an entity */
export function timelineKey(entityType: string, entityId: string): unknown[] {
  return ['timeline', entityType, entityId, LIST_QUERY_VERSION];
}

/** Purchase Orders list */
export function purchaseOrdersListKey(scopeKey: string): unknown[] {
  return ['inventory', 'purchase-orders', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Purchase Order detail */
export function purchaseOrderDetailKey(scopeKey: string, poId: string): unknown[] {
  return ['inventory', 'purchase-orders', 'detail', DETAIL_QUERY_VERSION, scopeKey, poId ?? ''];
}

/** Vendors list */
export function vendorsListKey(scopeKey: string): unknown[] {
  return ['partners', 'vendors', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Vendor detail */
export function vendorDetailKey(scopeKey: string, vendorId: string): unknown[] {
  return ['partners', 'vendors', 'detail', DETAIL_QUERY_VERSION, scopeKey, vendorId];
}

/** Warehouse stock list (MRP availability columns) */
export function warehouseStockListKey(scopeKey: string, warehouseId: string): unknown[] {
  return ['inventory', 'warehouse', 'stock', 'list', LIST_QUERY_VERSION, scopeKey, warehouseId ?? 'all'];
}

/** Inventory item operational detail */
export function inventoryItemDetailKey(scopeKey: string, itemId: string): unknown[] {
  return ['inventory', 'items', 'detail', DETAIL_QUERY_VERSION, scopeKey, itemId ?? ''];
}

/** Warehouse locations (bins) list, scoped to org and (optional) warehouse */
export function warehouseLocationsListKey(scopeKey: string, warehouseId: string | null): unknown[] {
  return ['inventory', 'warehouse-locations', 'list', LIST_QUERY_VERSION, scopeKey, warehouseId ?? 'all'];
}

/** Dealer financial cockpit list */
export function dealerFinancialAccountsListKey(
  scopeKey: string,
  filters: { q: string; risk: string; sortKey: string; page: number; pageSize: number }
): unknown[] {
  return [
    'financials',
    'dealer-accounts',
    'list',
    LIST_QUERY_VERSION,
    scopeKey,
    filters.q,
    filters.risk,
    filters.sortKey,
    filters.page,
    filters.pageSize,
  ];
}

/** Dealer financial detail summary */
export function dealerFinancialDetailKey(scopeKey: string, dealerId: string): unknown[] {
  return ['financials', 'dealer-accounts', 'detail', DETAIL_QUERY_VERSION, scopeKey, dealerId];
}

/** Dealer financial timeline */
export function dealerFinancialTimelineKey(scopeKey: string, dealerId: string): unknown[] {
  return ['financials', 'dealer-accounts', 'timeline', LIST_QUERY_VERSION, scopeKey, dealerId];
}

/** Vendor Bills list */
export function vendorBillsListKey(
  scopeKey: string,
  filters: { q: string; status: string; sortKey: string; page: number; pageSize: number }
): unknown[] {
  return [
    'financials',
    'vendor-bills',
    'list',
    LIST_QUERY_VERSION,
    scopeKey,
    filters.q,
    filters.status,
    filters.sortKey,
    filters.page,
    filters.pageSize,
  ];
}

/** Vendor Bill detail */
export function vendorBillDetailKey(scopeKey: string, billId: string): unknown[] {
  return ['financials', 'vendor-bills', 'detail', DETAIL_QUERY_VERSION, scopeKey, billId];
}

/** Vendor Payments list */
export function vendorPaymentsListKey(
  scopeKey: string,
  filters: { q: string; status: string; sortKey: string; page: number; pageSize: number }
): unknown[] {
  return [
    'financials',
    'vendor-payments',
    'list',
    LIST_QUERY_VERSION,
    scopeKey,
    filters.q,
    filters.status,
    filters.sortKey,
    filters.page,
    filters.pageSize,
  ];
}

/** Vendor Payment detail */
export function vendorPaymentDetailKey(scopeKey: string, paymentId: string): unknown[] {
  return ['financials', 'vendor-payments', 'detail', DETAIL_QUERY_VERSION, scopeKey, paymentId];
}

/** Vendor financial accounts list (AP cockpit) */
export function vendorFinancialAccountsListKey(
  scopeKey: string,
  filters: { q: string; risk: string; sortKey: string; page: number; pageSize: number }
): unknown[] {
  return [
    'financials',
    'vendor-accounts',
    'list',
    LIST_QUERY_VERSION,
    scopeKey,
    filters.q,
    filters.risk,
    filters.sortKey,
    filters.page,
    filters.pageSize,
  ];
}

/** Vendor financial detail summary */
export function vendorFinancialDetailKey(scopeKey: string, vendorId: string): unknown[] {
  return ['financials', 'vendor-accounts', 'detail', DETAIL_QUERY_VERSION, scopeKey, vendorId];
}

/** Vendor financial timeline */
export function vendorFinancialTimelineKey(scopeKey: string, vendorId: string): unknown[] {
  return ['financials', 'vendor-accounts', 'timeline', LIST_QUERY_VERSION, scopeKey, vendorId];
}

/** Manufacturing Dashboard overview */
export function dashboardOverviewKey(scopeKey: string): unknown[] {
  return ['manufacturing', 'dashboard', 'overview', LIST_QUERY_VERSION, scopeKey];
}

/** Commercial dashboard overview (org/dealer scoped) */
export function commercialDashboardOverviewKey(scopeKey: string): unknown[] {
  return ['dashboard', 'commercial', 'overview', LIST_QUERY_VERSION, scopeKey];
}

/** Manufacturing Dispatch Board */
export function dispatchBoardKey(scopeKey: string, days: number): unknown[] {
  return ['manufacturing', 'dispatch', LIST_QUERY_VERSION, scopeKey, days];
}

/** Manufacturing Global Capacity */
export function globalCapacityKey(scopeKey: string, days: number, from: string): unknown[] {
  return ['manufacturing', 'capacity', LIST_QUERY_VERSION, scopeKey, days, from];
}

/** Bottleneck analysis */
export function bottleneckKey(scopeKey: string): unknown[] {
  return ['manufacturing', 'bottleneck', LIST_QUERY_VERSION, scopeKey];
}

/** Schedule changelog for a task */
export function scheduleChangelogKey(taskId: string): unknown[] {
  return ['manufacturing', 'schedule-changelog', LIST_QUERY_VERSION, taskId];
}

/** Service Claims list */
export function serviceClaimsListKey(scopeKey: string): unknown[] {
  return ['service', 'claims', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Service Claim detail */
export function serviceClaimDetailKey(scopeKey: string, claimId: string): unknown[] {
  return ['service', 'claims', 'detail', DETAIL_QUERY_VERSION, scopeKey, claimId];
}

/** Organization Address Directory list */
export function organizationAddressesListKey(scopeKey: string): unknown[] {
  return ['settings', 'organization-addresses', 'list', LIST_QUERY_VERSION, scopeKey];
}

/** Accounting: chart of accounts list */
export function accountingAccountsListKey(orgId: string): unknown[] {
  return ['accounting', 'accounts', 'list', LIST_QUERY_VERSION, orgId];
}

/** Accounting: journal entries list */
export function accountingJournalEntriesListKey(
  orgId: string,
  filters: { q: string; status: string; sourceType: string; from: string; to: string; page: number; pageSize: number }
): unknown[] {
  return [
    'accounting',
    'journal-entries',
    'list',
    LIST_QUERY_VERSION,
    orgId,
    filters.q,
    filters.status,
    filters.sourceType,
    filters.from,
    filters.to,
    filters.page,
    filters.pageSize,
  ];
}

/** Accounting: journal entry detail */
export function accountingJournalEntryDetailKey(orgId: string, entryId: string): unknown[] {
  return ['accounting', 'journal-entries', 'detail', DETAIL_QUERY_VERSION, orgId, entryId];
}

/** Accounting reports */
export function accountingTrialBalanceKey(orgId: string, asOf: string): unknown[] {
  return ['accounting', 'reports', 'trial-balance', LIST_QUERY_VERSION, orgId, asOf];
}

export function accountingGeneralLedgerKey(
  orgId: string,
  accountId: string | null,
  from: string | null,
  to: string
): unknown[] {
  return ['accounting', 'reports', 'general-ledger', LIST_QUERY_VERSION, orgId, accountId ?? '', from ?? '', to];
}

export function accountingProfitLossKey(orgId: string, from: string, to: string): unknown[] {
  return ['accounting', 'reports', 'profit-loss', LIST_QUERY_VERSION, orgId, from, to];
}

export function accountingBalanceSheetKey(orgId: string, asOf: string): unknown[] {
  return ['accounting', 'reports', 'balance-sheet', LIST_QUERY_VERSION, orgId, asOf];
}

/** Reports module: one aggregated payload per tab and date window (from/to = 'YYYY-MM-DD') */
export function reportsTabKey(scopeKey: string, tab: string, from: string, to: string): unknown[] {
  return ['reports', tab, 'list', LIST_QUERY_VERSION, scopeKey, from, to];
}
