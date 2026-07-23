/**
 * Canonical Inventory submodule tabs (secondary nav).
 * Deliveries is the outbound counterpart to Receipts: everything ready to
 * dispatch (manufactured, purchased/MTM, or stock) is delivered from here.
 */
export const INVENTORY_SUBMODULES = [
  { id: 'warehouse', label: 'Warehouse', href: '/inventory/warehouse' },
  { id: 'locations', label: 'Locations', href: '/inventory/locations' },
  { id: 'purchase-orders', label: 'Purchase Orders', href: '/inventory/purchase-orders' },
  { id: 'receipts', label: 'Receipts', href: '/inventory/receipts' },
  { id: 'deliveries', label: 'Deliveries', href: '/inventory/deliveries' },
  { id: 'transactions', label: 'Transactions', href: '/inventory/transactions' },
  { id: 'adjustments', label: 'Adjustments', href: '/inventory/adjustments' },
  { id: 'material-demand', label: 'Material Demand', href: '/inventory/material-demand' },
];
