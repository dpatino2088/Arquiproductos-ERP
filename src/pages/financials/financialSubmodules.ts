import { Building2, FileText, DollarSign, Truck, Receipt, CreditCard, ShoppingCart } from 'lucide-react';
import type { PortalRole } from '../../hooks/useAccessContext';

export const FINANCIAL_GROUP_TABS = [
  {
    id: 'ar',
    label: 'Accounts Receivable',
    href: '/financials/accounts',
    matchPaths: ['/financials/accounts', '/financials/invoices', '/financials/payments'],
  },
  {
    id: 'ap',
    label: 'Accounts Payable',
    href: '/financials/vendor-accounts',
    matchPaths: ['/financials/vendor-accounts', '/financials/bills', '/financials/vendor-payments', '/financials/purchase-orders'],
  },
];

export const AR_SUBTABS = [
  { id: 'accounts', label: 'Accounts', href: '/financials/accounts', icon: Building2, readPerm: 'financials.accounts.read' },
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText, readPerm: 'financials.invoices.read' },
  { id: 'payments', label: 'Payments Received', href: '/financials/payments', icon: DollarSign, readPerm: 'financials.payments.read' },
];

export const AP_SUBTABS = [
  { id: 'vendor-accounts', label: 'Vendor Accounts', href: '/financials/vendor-accounts', icon: Truck, readPerm: 'financials.vendor_accounts.read' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/financials/purchase-orders', icon: ShoppingCart, readPerm: 'financials.purchase_orders.read' },
  { id: 'bills', label: 'Bills', href: '/financials/bills', icon: Receipt, readPerm: 'financials.bills.read' },
  { id: 'vendor-payments', label: 'Payments Made', href: '/financials/vendor-payments', icon: CreditCard, readPerm: 'financials.vendor_payments.read' },
];

export const PORTAL_FINANCIAL_SUBTABS = [
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', readPerm: 'portal.financials.invoices.read' },
  { id: 'payments', label: 'Payments', href: '/financials/payments', readPerm: 'portal.financials.payments.read' },
  { id: 'statement', label: 'Statement', href: '/financials/statement', readPerm: 'portal.financials.statement.read' },
];

const AR_PATHS = new Set(['/financials/accounts', '/financials/invoices', '/financials/payments']);

export function getFinancialGroup(pathname: string): 'ar' | 'ap' {
  const base = '/' + pathname.split('/').slice(1, 3).join('/');
  return AR_PATHS.has(base) ? 'ar' : 'ap';
}

export function getFinancialSubTabs(group: 'ar' | 'ap') {
  return group === 'ar' ? AR_SUBTABS : AP_SUBTABS;
}

export function getVisibleFinancialSubTabs(
  group: 'ar' | 'ap',
  can: (permissionCode: string) => boolean,
) {
  return getFinancialSubTabs(group).filter((tab) => can(tab.readPerm));
}

export function getVisibleFinancialGroupTabs(can: (permissionCode: string) => boolean) {
  const hasAR = AR_SUBTABS.some((tab) => can(tab.readPerm));
  const hasAP = AP_SUBTABS.some((tab) => can(tab.readPerm));
  return FINANCIAL_GROUP_TABS.filter((tab) => (tab.id === 'ar' ? hasAR : hasAP));
}

export function getFirstAllowedFinancialRoute(can: (permissionCode: string) => boolean): string | null {
  const firstAR = AR_SUBTABS.find((tab) => can(tab.readPerm));
  if (firstAR) return firstAR.href;
  const firstAP = AP_SUBTABS.find((tab) => can(tab.readPerm));
  return firstAP?.href ?? null;
}

export function getVisiblePortalFinancialSubTabs(
  can: (permissionCode: string) => boolean,
  portalRole: PortalRole | null | undefined,
  basePath: '/financials' | '/my-financials' = '/financials',
) {
  // dealer_member keeps a basic scope (no statement tab).
  const roleFiltered = PORTAL_FINANCIAL_SUBTABS.filter((tab) => {
    if (portalRole === 'dealer_member' && tab.id === 'statement') return false;
    return true;
  });
  return roleFiltered
    .filter((tab) => can(tab.readPerm) || can('portal.financials.read'))
    .map((tab) => ({
      ...tab,
      href: tab.href.replace('/financials', basePath),
    }));
}

export function getFirstAllowedPortalFinancialRoute(
  can: (permissionCode: string) => boolean,
  portalRole: PortalRole | null | undefined,
): string | null {
  const first = getVisiblePortalFinancialSubTabs(can, portalRole)[0];
  return first?.href ?? null;
}

/** @deprecated Use FINANCIAL_GROUP_TABS + FinancialSubTabs instead */
export const FINANCIAL_SUBMODULES = [
  { id: 'accounts', label: 'Accounts', href: '/financials/accounts', icon: Building2, group: 'AR' },
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText, group: 'AR' },
  { id: 'payments', label: 'Payments Received', href: '/financials/payments', icon: DollarSign, group: 'AR' },
  { id: 'vendor-accounts', label: 'Vendor Accounts', href: '/financials/vendor-accounts', icon: Truck, group: 'AP' },
  { id: 'bills', label: 'Bills', href: '/financials/bills', icon: Receipt, group: 'AP' },
  { id: 'vendor-payments', label: 'Payments Made', href: '/financials/vendor-payments', icon: CreditCard, group: 'AP' },
];
