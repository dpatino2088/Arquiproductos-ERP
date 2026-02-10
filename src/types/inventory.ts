/**
 * Types for inventory_availability view (dump V4).
 * Column names must match the view exactly. Do not change.
 */

export type InventoryAvailabilityStatus = 'IN_STOCK' | 'ON_ORDER' | 'OUT_OF_STOCK';

export type InventoryRiskLevel = 'low' | 'medium' | 'high' | 'critical' | null;

export type InventoryAvailabilityRow = {
  organization_id: string;
  warehouse_id: string;
  catalog_item_id: string;
  on_hand_qty: number | null;
  on_order_qty: number | null;
  next_eta: string | null;
  availability: InventoryAvailabilityStatus | null;
  risk_level: string | null;
  is_risk: boolean | null;
  is_special_order: boolean | null;
  import_lead_time_min_days: number | null;
  import_lead_time_max_days: number | null;
  preferred_supplier_id: string | null;
  updated_at: string | null;
};
