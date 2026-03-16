import { normalizeRole } from '../../../lib/bom/roles';

export { CASCADE_PRIORITY, getCascadeOrder, getCascadeLabel, getCascadeAxis, getDefaultDependsOn } from '../../../lib/bom/cascadePriority';

export type BOMQtyType = 'fixed' | 'per_width' | 'per_height' | 'per_spacing' | 'per_joint';
export const BOM_QTY_TYPES = ['fixed', 'per_width', 'per_height', 'per_spacing', 'per_joint'] as const;

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
  affects_role: string | null;
  cut_axis: string | null;
  cut_delta_mm: number;
  cut_delta_scope?: string | null;
  engineering_delta_source?: string | null;
  engineering_attr_key?: string | null;
  engineering_scope?: string | null;
  engineering_source_role?: string | null;
  qty_spacing_mm?: number | null;
  qty_min?: number | null;
  uom: string;
  sort_order: number;
  sequence_order: number;
  is_required: boolean;
  auto_select: boolean;
  per_panel: boolean;
  condition_key?: string | null;
  condition_value?: string | null;
  component_mode?: string;
  catalog_item?: {
    id: string;
    sku: string;
    name: string | null;
    delta_x_mm?: number | null;
    delta_y_mm?: number | null;
    measure_basis?: string | null;
  } | null;
}

export interface ComponentFormData {
  component_item_id: string;
  component_role: string;
  qty_type: BOMQtyType;
  qty_value: number | null;
  qty_spacing_mm: number | null;
  qty_min: number | null;
  uom: string;
  sequence_order: number;
  is_required: boolean;
  per_panel: boolean;
  condition_key: string;
  condition_value: string;
}

export interface EngineeringData {
  depends_on_role: string;
  affects_role: string;
  cut_axis: 'length' | 'width' | 'height' | 'none';
  cut_delta_mm: number | null;
  cut_delta_scope: 'per_side' | 'per_item' | 'none';
  engineering_delta_source: 'fixed' | 'derived';
  engineering_attr_key: string;
  engineering_scope: 'total' | 'per_side';
  engineering_source_role: string;
}

export interface ChildFormData {
  child_item_id: string;
  child_role: string;
  qty_type: BOMQtyType;
  qty: number;
  qty_spacing_mm: number | null;
  qty_min: number | null;
  uom: string;
  required: boolean;
  per_panel: boolean;
  condition_key: string;
  condition_value: string;
  notes: string;
}

export interface BOMTemplateFormState {
  productTypeId: string;
  templateCode: string;
  templateName: string;
  templateDescription: string;
  templateHardwareColor: string;
  templatePanelCount: number;
  templateDriveType: 'manual' | 'motor' | null;
  templateDriveSide: 'left' | 'right' | 'both' | null;
  templateOpeningDirection: 'left' | 'right' | 'center' | null;
  templateManufacturer: string | null;
  templateProductLine: string | null;
  templateSystemSize: string | null;
}

export interface ComponentGroupedByCategory {
  category_id: string | null;
  category_name: string;
  category_code: string | null;
  components: BOMComponentDraft[];
}

export const CONDITION_KEY_OPTIONS = [
  { value: '', label: '-- None --' },
  { value: 'system_size', label: 'System Size (glider spacing)' },
  { value: 'gear_ratio', label: 'Gear Ratio (clutch type)' },
] as const;

export const CONDITION_VALUE_OPTIONS: Record<string, { value: string; label: string }[]> = {
  system_size: [
    { value: '48mm', label: '48mm' },
    { value: '54mm', label: '54mm' },
    { value: '60mm', label: '60mm' },
    { value: '80mm', label: '80mm' },
  ],
  gear_ratio: [
    { value: 'standard', label: 'Standard (1:1)' },
    { value: '1:1.5', label: '1:1.5' },
    { value: '1:3', label: '1:3' },
  ],
};

export const INITIAL_FORM_DATA: ComponentFormData = {
  component_item_id: '',
  component_role: '',
  qty_type: 'fixed',
  qty_value: null,
  qty_spacing_mm: null,
  qty_min: null,
  uom: 'ea',
  sequence_order: 0,
  is_required: true,
  per_panel: false,
  condition_key: '',
  condition_value: '',
};

export const INITIAL_ENGINEERING_DATA: EngineeringData = {
  depends_on_role: '',
  affects_role: '',
  cut_axis: 'none',
  cut_delta_mm: null,
  cut_delta_scope: 'none',
  engineering_delta_source: 'fixed',
  engineering_attr_key: '',
  engineering_scope: 'total',
  engineering_source_role: '',
};

export const INITIAL_CHILD_FORM_DATA: ChildFormData = {
  child_item_id: '',
  child_role: '',
  qty_type: 'fixed',
  qty: 1,
  qty_spacing_mm: null,
  qty_min: null,
  uom: 'ea',
  required: true,
  per_panel: false,
  condition_key: '',
  condition_value: '',
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
