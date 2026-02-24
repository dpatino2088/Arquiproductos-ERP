import { normalizeRole } from '../../../lib/bom/roles';

export type BOMQtyType = 'fixed' | 'per_width' | 'per_height' | 'per_area';
export const BOM_QTY_TYPES = ['fixed', 'per_width', 'per_height', 'per_area'] as const;

export type SKUResolutionRule = 'EXACT_SKU' | 'SKU_SUFFIX_COLOR' | 'ROLE_AND_COLOR' | 'CATEGORY_FIRST_MATCH' | string;
export type HardwareColor = 'none' | 'white' | 'black' | 'silver' | 'bronze' | 'grey' | string;

export interface BOMComponentDraft {
  id: string;
  parent_component_id: string | null;
  component_item_id: string | null;
  component_role: string | null;
  component_sub_role?: string | null;
  qty_type: BOMQtyType | string;
  qty_value: number;
  qty_delta_mm: number;
  waste_pct: number;
  depends_on_role: string | null;
  cut_axis: string | null;
  cut_delta_mm: number;
  cut_delta_scope?: string | null;
  uom: string;
  sort_order: number;
  sequence_order: number;
  is_required: boolean;
  auto_select: boolean;
  component_mode?: string;
  catalog_item?: {
    id: string;
    sku: string;
    name: string | null;
  } | null;
}

export interface ComponentFormData {
  component_item_id: string;
  component_role: string;
  qty_type: BOMQtyType;
  qty_value: number | null;
  uom: string;
  sequence_order: number;
  is_required: boolean;
}

export interface EngineeringData {
  depends_on_role: string;
  cut_axis: 'length' | 'width' | 'height' | 'none';
  cut_delta_mm: number | null;
  cut_delta_scope: 'per_side' | 'per_item' | 'none';
}

export interface ChildFormData {
  child_item_id: string;
  child_role: string;
  qty: number;
  uom: string;
  required: boolean;
  notes: string;
}

export interface BOMTemplateFormState {
  productTypeId: string;
  templateCode: string;
  templateName: string;
  templateDescription: string;
  templateHardwareColor: string;
  templatePanelCount: 1 | 2 | 3;
}

export interface ComponentGroupedByCategory {
  category_id: string | null;
  category_name: string;
  category_code: string | null;
  components: BOMComponentDraft[];
}

export const INITIAL_FORM_DATA: ComponentFormData = {
  component_item_id: '',
  component_role: '',
  qty_type: 'fixed',
  qty_value: null,
  uom: 'ea',
  sequence_order: 0,
  is_required: true,
};

export const INITIAL_ENGINEERING_DATA: EngineeringData = {
  depends_on_role: '',
  cut_axis: 'none',
  cut_delta_mm: null,
  cut_delta_scope: 'none',
};

export const INITIAL_CHILD_FORM_DATA: ChildFormData = {
  child_item_id: '',
  child_role: '',
  qty: 1,
  uom: 'ea',
  required: true,
  notes: '',
};

export function shouldShowHardwareColor(role: string | null | undefined): boolean {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  if (['drive_manual', 'drive_motorized', 'operating_system'].includes(normalized)) return false;
  return ['bracket', 'cassette', 'bottom_bar', 'end_cap', 'hardware'].includes(normalized);
}

export function isQtyAlwaysFixed(role: string | null | undefined): boolean {
  if (!role) return false;
  const normalized = normalizeRole(role);
  if (!normalized) return false;
  return ['drive_manual', 'drive_motorized', 'remote_control', 'battery', 'tool', 'accessory'].includes(normalized);
}
