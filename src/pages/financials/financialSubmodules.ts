import { Building2, FileText, DollarSign, Truck, Receipt, CreditCard, ShoppingCart } from 'lucide-react';

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
  { id: 'accounts', label: 'Accounts', href: '/financials/accounts', icon: Building2 },
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments Received', href: '/financials/payments', icon: DollarSign },
];

export const AP_SUBTABS = [
  { id: 'vendor-accounts', label: 'Vendor Accounts', href: '/financials/vendor-accounts', icon: Truck },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/financials/purchase-orders', icon: ShoppingCart },
  { id: 'bills', label: 'Bills', href: '/financials/bills', icon: Receipt },
  { id: 'vendor-payments', label: 'Payments Made', href: '/financials/vendor-payments', icon: CreditCard },
];

const AR_PATHS = new Set(['/financials/accounts', '/financials/invoices', '/financials/payments']);

export function getFinancialGroup(pathname: string): 'ar' | 'ap' {
  const base = '/' + pathname.split('/').slice(1, 3).join('/');
  return AR_PATHS.has(base) ? 'ar' : 'ap';
}

export function getFinancialSubTabs(group: 'ar' | 'ap') {
  return group === 'ar' ? AR_SUBTABS : AP_SUBTABS;
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
