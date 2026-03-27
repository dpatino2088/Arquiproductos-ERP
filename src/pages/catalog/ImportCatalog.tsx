import React, { useState, useRef, useEffect } from 'react';
import { X, Upload, FileSpreadsheet, FileText, AlertCircle, CheckCircle2, Loader2, Download } from 'lucide-react';
import * as XLSX from 'xlsx';
import Papa from 'papaparse';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUpsertCatalogItemBySku } from '../../hooks/useCatalog';
import { useUIStore } from '../../stores/ui-store';
import { CatalogItem } from '../../types/catalog';
import { supabase } from '../../lib/supabase/client';
import { syncCatalogItemProductTypes } from '../../lib/catalog-item-helpers';
import { upsertCatalogItemSupply, type SupplyType, type SupplyOrigin } from '../../services/catalogItemSupply';
import { upsertCatalogItemRollSpecs } from '../../services/catalogItemRollSpecs';

interface ImportCatalogProps {
  isOpen: boolean;
  onClose: () => void;
  onImportComplete: () => void;
}

interface ParsedRow {
  [key: string]: unknown;
  sku: string;
  name: string;
  description?: string;
  category_group?: string;
  subcategory?: string;
  product_types?: string;
  item_type?: string; // backward compatibility
  measure_basis?: string;
  unit_of_measure?: string;
  uom?: string;
  is_roll?: boolean | string;
  is_fabric?: boolean | string; // backward compatibility
  roll_type?: string;
  roll_width_value?: number | string;
  roll_width_uom?: string;
  roll_width_m?: number | string; // backward compatibility
  roll_length_value?: number | string;
  roll_length_uom?: string;
  roll_pricing_mode?: string;
  fabric_pricing_mode?: string; // backward compatibility
  cost_exw?: number | string;
  cost_price?: number | string; // backward compatibility
  unit_price?: number | string; // backward compatibility
  is_active?: boolean | string;
  active?: boolean | string; // backward compatibility
  manufacturer?: string;
  collection_name?: string;
  variant_name?: string;
  color?: string;
  purchase_unit?: string;
  units_per_purchase_unit?: number | string;
  supply_type?: string;
  supply_origin?: string;
  can_rotate?: boolean | string;
  weldable?: boolean | string;
  raw_material?: string;
  openness_factor?: number | string;
  weight_gsm?: number | string;
  notes?: string;
  category?: string; // backward compatibility
  family?: string; // backward compatibility
  collection?: string; // backward compatibility (legacy alias for collection_name)
  variant?: string; // backward compatibility (legacy alias for variant_name)
}

interface ValidationError {
  row: number;
  field: string;
  message: string;
}

interface ImportResult {
  success: number;
  inserted: number;
  updated: number;
  failed: number;
  mappingFailed: number;
  recomputeFailed: number;
  errors: ValidationError[];
}

interface ImportLookups {
  categoryByParentAndLeaf: Map<string, string>;
  leafCategoryIdsByName: Map<string, string[]>;
  parentCategoryIdsByName: Map<string, string[]>;
  categoryById: Map<string, { id: string; name: string; parent_id: string | null; is_group: boolean }>;
  manufacturerIdsByName: Map<string, string[]>;
  productTypeIdsByToken: Map<string, string[]>;
}

function getErrorMessage(error: unknown): string {
  if (!error) return 'Unknown error';
  if (error instanceof Error) return error.message;
  if (typeof error === 'object') {
    const err = error as { message?: string; details?: string; hint?: string; code?: string };
    const parts = [err.message, err.details, err.hint].filter(Boolean);
    if (parts.length > 0) return parts.join(' | ');
    if (err.code) return `Database error (${err.code})`;
  }
  return String(error);
}

function normalizeToken(value: unknown): string {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function parseBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  const raw = String(value ?? '').trim().toLowerCase();
  if (!raw) return fallback;
  return ['true', '1', 'yes', 'y', 't'].includes(raw);
}

function parseNumber(value: unknown): number | null {
  const raw = String(value ?? '').trim();
  if (!raw) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeRollUom(value: unknown): string {
  const raw = String(value ?? '').trim().toLowerCase();
  if (!raw) return '';
  if (['m', 'meter', 'meters', 'metre', 'metres'].includes(raw)) return 'm';
  if (['yd', 'yard', 'yards'].includes(raw)) return 'yd';
  if (['ft', 'foot', 'feet'].includes(raw)) return 'ft';
  if (['in', 'inch', 'inches', '"'].includes(raw)) return 'in';
  return raw;
}

function splitMultiValue(value: unknown): string[] {
  const raw = String(value ?? '').trim();
  if (!raw) return [];
  return raw
    .split(/[|,;]/g)
    .map((v) => v.trim())
    .filter(Boolean);
}

function normalizeImportedText(value: unknown): string {
  return String(value ?? '')
    .replace(/\u0000/g, '')
    .trim();
}

function looksMojibake(value: string): boolean {
  // Typical double-encoded UTF-8 artifacts seen in CSV exports.
  return /Ã.|Â.|â.|�/.test(value);
}

function pickBestImportedText(primaryRaw: unknown, fallbackRaw: unknown): string {
  const primary = normalizeImportedText(primaryRaw);
  const fallback = normalizeImportedText(fallbackRaw);
  if (!primary) return fallback;
  if (!fallback) return primary;
  if (looksMojibake(primary) && !looksMojibake(fallback)) return fallback;
  return primary;
}

export default function ImportCatalog({ isOpen, onClose, onImportComplete }: ImportCatalogProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { upsertItemBySku } = useUpsertCatalogItemBySku();
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [file, setFile] = useState<File | null>(null);
  const [parsedData, setParsedData] = useState<ParsedRow[]>([]);
  const [validationErrors, setValidationErrors] = useState<ValidationError[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);
  const [currentStep, setCurrentStep] = useState<'upload' | 'preview' | 'result'>('upload');
  const [useLegacyImport, setUseLegacyImport] = useState(false);

  // Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setFile(null);
      setParsedData([]);
      setValidationErrors([]);
      setImportResult(null);
      setCurrentStep('upload');
      setIsProcessing(false);
      setUseLegacyImport(false);
      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) return;

    setFile(selectedFile);
    setParsedData([]);
    setValidationErrors([]);
    setImportResult(null);
    setCurrentStep('upload');
    setUseLegacyImport(false);

    try {
      const data = await parseFile(selectedFile);
      setParsedData(data);
      
      // Validate data
      const errors = validateData(data);
      setValidationErrors(errors);
      
      if (errors.length === 0) {
        setCurrentStep('preview');
      } else {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Validation Errors',
          message: `Found ${errors.length} validation errors. Please review and fix them.`,
        });
      }
    } catch (error) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error parsing file',
        message: error instanceof Error ? error.message : 'Unknown error occurred',
      });
    }
  };

  const parseFile = async (file: File): Promise<ParsedRow[]> => {
    return new Promise((resolve, reject) => {
      const fileExtension = file.name.split('.').pop()?.toLowerCase();

      if (fileExtension === 'csv') {
        Papa.parse(file, {
          header: true,
          skipEmptyLines: true,
          complete: (results: any) => {
            if (results.errors.length > 0) {
              reject(new Error(`CSV parsing errors: ${results.errors.map((e: any) => e.message).join(', ')}`));
              return;
            }
            resolve(results.data as ParsedRow[]);
          },
          error: (error: any) => {
            reject(new Error(`CSV parsing error: ${error.message}`));
          },
        });
      } else if (fileExtension === 'xlsx' || fileExtension === 'xls') {
        const reader = new FileReader();
        reader.onload = (e) => {
          try {
            const data = new Uint8Array(e.target?.result as ArrayBuffer);
            const workbook = XLSX.read(data, { type: 'array' });
          const firstSheetName = workbook.SheetNames[0];
          if (!firstSheetName) {
            reject(new Error('Workbook has no sheets'));
            return;
          }
          const worksheet = workbook.Sheets[firstSheetName];
          if (!worksheet) {
            reject(new Error('Worksheet not found'));
            return;
          }
          const jsonData = XLSX.utils.sheet_to_json(worksheet);
            resolve(jsonData as ParsedRow[]);
          } catch (error) {
            reject(new Error(`Excel parsing error: ${error instanceof Error ? error.message : 'Unknown error'}`));
          }
        };
        reader.onerror = () => {
          reject(new Error('Error reading Excel file'));
        };
        reader.readAsArrayBuffer(file);
      } else {
        reject(new Error('Unsupported file format. Please use CSV or Excel (.xlsx, .xls)'));
      }
    });
  };

  const validateData = (data: ParsedRow[]): ValidationError[] => {
    const errors: ValidationError[] = [];

    data.forEach((row, index) => {
      const rowNum = index + 2; // +2 because index is 0-based and we skip header

      const sku = String(row.sku ?? '').trim();
      const name = String(row.name ?? '').trim();
      const measureBasis = String(row.measure_basis ?? '').trim().toLowerCase();
      const unitOfMeasure = String(row.unit_of_measure ?? '').trim().toLowerCase();
      const costExw = parseNumber(row.cost_exw);
      const categoryGroup = String(row.category_group ?? '').trim();
      const subcategory = String(row.subcategory ?? '').trim();

      if (!sku) {
        errors.push({ row: rowNum, field: 'sku', message: 'SKU is required' });
      }

      if (!name) {
        errors.push({ row: rowNum, field: 'name', message: 'Name is required' });
      }

      if (!categoryGroup) {
        errors.push({ row: rowNum, field: 'category_group', message: 'Category group is required' });
      }

      if (!subcategory) {
        errors.push({ row: rowNum, field: 'subcategory', message: 'Subcategory is required' });
      }

      const validBasis = ['unit', 'linear', 'linear_m', 'area', 'fabric'];
      if (!measureBasis || !validBasis.includes(measureBasis)) {
        errors.push({
          row: rowNum,
          field: 'measure_basis',
          message: `Invalid measure_basis. Must be one of: ${validBasis.join(', ')}`,
        });
      }

      if (!unitOfMeasure) {
        errors.push({ row: rowNum, field: 'unit_of_measure', message: 'Unit of measure is required' });
      }

      if (costExw == null || costExw < 0) {
        errors.push({ row: rowNum, field: 'cost_exw', message: 'cost_exw (or cost_price) must be a valid number >= 0' });
      }

      const purchaseUnit = String(row.purchase_unit ?? '').trim().toLowerCase();
      if (purchaseUnit) {
        const validPurchaseUnits = ['each', 'box', 'pack', 'set', 'roll', 'case', 'bag', 'bundle', 'carton', 'kit', 'pair', 'm', 'ft', 'yd'];
        if (!validPurchaseUnits.includes(purchaseUnit)) {
          errors.push({
            row: rowNum,
            field: 'purchase_unit',
            message: `Invalid purchase_unit. Must be one of: ${validPurchaseUnits.join(', ')}`,
          });
        }
      }

      const unitsPerPurchase = parseNumber(row.units_per_purchase_unit);
      if (unitsPerPurchase != null && unitsPerPurchase < 1) {
        errors.push({
          row: rowNum,
          field: 'units_per_purchase_unit',
          message: 'units_per_purchase_unit must be >= 1',
        });
      }

      const isRoll = parseBoolean(row.is_roll, false);
      const rollPricingMode = String(row.roll_pricing_mode ?? '').trim().toLowerCase();
      if (rollPricingMode) {
        const validModes = ['per_linear_m', 'per_sqm', 'per_linear_meter', 'per_square_meter', 'per_unit'];
        if (!validModes.includes(rollPricingMode)) {
          errors.push({
            row: rowNum,
            field: 'roll_pricing_mode',
            message: `Invalid roll_pricing_mode. Must be one of: ${validModes.join(', ')}`,
          });
        }
      }

      if (isRoll) {
        const rollWidthVal = parseNumber(row.roll_width_value) ?? parseNumber(row.roll_width_m);
        if (rollWidthVal == null || rollWidthVal <= 0) {
          errors.push({
            row: rowNum,
            field: 'roll_width_value',
            message: 'roll_width_value is required for roll items (> 0)',
          });
        }
        const rollWidthUom = normalizeRollUom(row.roll_width_uom);
        if (rollWidthUom && !['m', 'yd', 'ft', 'in'].includes(rollWidthUom)) {
          errors.push({
            row: rowNum,
            field: 'roll_width_uom',
            message: 'roll_width_uom must be one of: m, yd, ft, in (also accepts inch/inches)',
          });
        }

        const rollLengthUom = normalizeRollUom(row.roll_length_uom);
        if (rollLengthUom && !['m', 'yd', 'ft', 'in'].includes(rollLengthUom)) {
          errors.push({
            row: rowNum,
            field: 'roll_length_uom',
            message: 'roll_length_uom must be one of: m, yd, ft, in (also accepts inch/inches)',
          });
        }

        const explicitCollection = pickBestImportedText(row.collection_name, row.collection);
        const fallbackCollection = String(row.category_group ?? '').trim();
        if (!explicitCollection && !fallbackCollection) {
          errors.push({
            row: rowNum,
            field: 'collection_name',
            message: 'For roll items, provide collection_name (or category_group as fallback)',
          });
        }

        const explicitVariant = pickBestImportedText(row.variant_name, row.variant);
        const fallbackVariant = String(row.name ?? '').trim();
        if (!explicitVariant && !fallbackVariant) {
          errors.push({
            row: rowNum,
            field: 'variant_name',
            message: 'For roll items, provide variant_name (or name as fallback)',
          });
        }
      }

      const supplyTypeRaw = String(row.supply_type ?? '').trim().toLowerCase();
      if (supplyTypeRaw && !['stock', 'order'].includes(supplyTypeRaw)) {
        errors.push({
          row: rowNum,
          field: 'supply_type',
          message: 'supply_type must be one of: stock, order',
        });
      }
      const supplyOriginRaw = String(row.supply_origin ?? '').trim().toLowerCase();
      if (supplyOriginRaw && !['local', 'import'].includes(supplyOriginRaw)) {
        errors.push({
          row: rowNum,
          field: 'supply_origin',
          message: 'supply_origin must be one of: local, import',
        });
      }
    });

    return errors;
  };

  const loadImportLookups = async (): Promise<ImportLookups> => {
    const [categoriesRes, manufacturersRes, productTypesRes] = await Promise.all([
      supabase
        .from('CatalogCategories')
        .select('id, name, parent_id, is_group, deleted')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false),
      supabase
        .from('Manufacturers')
        .select('id, name, deleted')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false),
      supabase
        .from('ProductTypes')
        .select('id, name, code, organization_id')
        .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`),
    ]);

    if (categoriesRes.error) throw categoriesRes.error;
    if (manufacturersRes.error) throw manufacturersRes.error;
    if (productTypesRes.error) throw productTypesRes.error;

    const categoryByParentAndLeaf = new Map<string, string>();
    const leafCategoryIdsByName = new Map<string, string[]>();
    const parentCategoryIdsByName = new Map<string, string[]>();
    const categoryById = new Map<string, { id: string; name: string; parent_id: string | null; is_group: boolean }>();

    const categories = (categoriesRes.data || []) as Array<{
      id: string;
      name: string;
      parent_id: string | null;
      is_group: boolean;
      deleted?: boolean;
    }>;

    categories.forEach((cat) => {
      categoryById.set(cat.id, {
        id: cat.id,
        name: cat.name,
        parent_id: cat.parent_id,
        is_group: Boolean(cat.is_group),
      });
    });

    categories.forEach((cat) => {
      const normName = normalizeToken(cat.name);
      if (!cat.parent_id || cat.is_group) {
        const current = parentCategoryIdsByName.get(normName) || [];
        parentCategoryIdsByName.set(normName, [...current, cat.id]);
        return;
      }

      const parent = categoryById.get(cat.parent_id);
      const parentNorm = parent ? normalizeToken(parent.name) : '';
      const key = `${parentNorm}::${normName}`;
      categoryByParentAndLeaf.set(key, cat.id);

      const byLeaf = leafCategoryIdsByName.get(normName) || [];
      leafCategoryIdsByName.set(normName, [...byLeaf, cat.id]);
    });

    const manufacturerIdsByName = new Map<string, string[]>();
    ((manufacturersRes.data || []) as Array<{ id: string; name: string }>).forEach((mfg) => {
      const key = normalizeToken(mfg.name);
      const current = manufacturerIdsByName.get(key) || [];
      manufacturerIdsByName.set(key, [...current, mfg.id]);
    });

    const ptByToken = new Map<string, Array<{ id: string; orgId: string | null }>>();
    ((productTypesRes.data || []) as Array<{ id: string; name: string; code?: string | null; organization_id?: string | null }>).forEach((pt) => {
      const tokens = [normalizeToken(pt.name), normalizeToken(pt.code)].filter(Boolean);
      tokens.forEach((token) => {
        const current = ptByToken.get(token) || [];
        ptByToken.set(token, [...current, { id: pt.id, orgId: pt.organization_id ?? null }]);
      });
    });

    const productTypeIdsByToken = new Map<string, string[]>();
    ptByToken.forEach((rows, token) => {
      const deduped = Array.from(new Map(rows.map((r) => [r.id, r])).values());
      const orgScoped = deduped.filter((r) => r.orgId === activeOrganizationId);
      const winners = orgScoped.length > 0 ? orgScoped : deduped;
      productTypeIdsByToken.set(token, winners.map((r) => r.id));
    });

    return {
      categoryByParentAndLeaf,
      leafCategoryIdsByName,
      parentCategoryIdsByName,
      categoryById,
      manufacturerIdsByName,
      productTypeIdsByToken,
    };
  };

  const resolveCategoryId = (row: ParsedRow, lookups: ImportLookups): { categoryId: string | null; error?: string } => {
    const groupRawFromCategory = String(row.category_group ?? '').trim();
    const subRawFromSubcategory = String(row.subcategory ?? '').trim();

    let groupRaw = groupRawFromCategory;
    let subRaw = subRawFromSubcategory;

    if (!groupRaw && subRaw.includes('>')) {
      const parts = subRaw.split('>').map((p) => p.trim()).filter(Boolean);
      if (parts.length >= 2) {
        groupRaw = parts[0];
        subRaw = parts[parts.length - 1];
      }
    }

    if (!groupRaw || !subRaw) {
      return { categoryId: null, error: 'category_group and subcategory are required' };
    }

    const group = normalizeToken(groupRaw);
    const sub = normalizeToken(subRaw);
    const directKey = `${group}::${sub}`;
    const direct = lookups.categoryByParentAndLeaf.get(directKey);
    if (direct) return { categoryId: direct };

    const parentIds = lookups.parentCategoryIdsByName.get(group) || [];
    const candidates: string[] = [];
    parentIds.forEach((parentId) => {
      const candidate = lookups.categoryByParentAndLeaf.get(`${group}::${sub}`);
      if (candidate) candidates.push(candidate);
      const parent = lookups.categoryById.get(parentId);
      if (parent) {
        const fromParent = lookups.categoryByParentAndLeaf.get(`${normalizeToken(parent.name)}::${sub}`);
        if (fromParent) candidates.push(fromParent);
      }
    });
    const unique = Array.from(new Set(candidates));
    if (unique.length === 1) return { categoryId: unique[0] };
    if (unique.length > 1) return { categoryId: null, error: `Ambiguous subcategory '${subRaw}' under '${groupRaw}'` };

    return { categoryId: null, error: `Subcategory '${subRaw}' under '${groupRaw}' not found` };
  };

  const resolveManufacturerId = (row: ParsedRow, lookups: ImportLookups): { manufacturerId: string | null; error?: string } => {
    const manufacturerRaw = String(row.manufacturer ?? '').trim();
    if (!manufacturerRaw) return { manufacturerId: null };
    const ids = lookups.manufacturerIdsByName.get(normalizeToken(manufacturerRaw)) || [];
    if (ids.length === 1) return { manufacturerId: ids[0] };
    if (ids.length > 1) return { manufacturerId: null, error: `Ambiguous manufacturer '${manufacturerRaw}'` };
    return { manufacturerId: null, error: `Manufacturer '${manufacturerRaw}' not found` };
  };

  const resolveProductTypeIds = (row: ParsedRow, lookups: ImportLookups): { productTypeIds: string[]; error?: string } => {
    const raw = row.product_types;
    const tokens = splitMultiValue(raw);
    if (tokens.length === 0) return { productTypeIds: [] };

    const resolved: string[] = [];
    for (const token of tokens) {
      const ids = lookups.productTypeIdsByToken.get(normalizeToken(token)) || [];
      if (ids.length === 0) {
        return { productTypeIds: [], error: `ProductType '${token}' not found` };
      }
      if (ids.length > 1) {
        return { productTypeIds: [], error: `Ambiguous ProductType '${token}'` };
      }
      resolved.push(ids[0]);
    }
    return { productTypeIds: Array.from(new Set(resolved)) };
  };

  const transformRowToCatalogItem = (
    row: ParsedRow,
    categoryId: string,
    manufacturerId: string | null
  ): Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'> => {
    const isRoll = parseBoolean(row.is_roll, false);
    const incomingBasis = String(row.measure_basis ?? '').trim().toLowerCase();
    let measureBasis: 'unit' | 'linear' | 'area' = 'unit';
    if (incomingBasis === 'linear' || incomingBasis === 'linear_m' || incomingBasis === 'fabric') {
      measureBasis = 'linear';
    } else if (incomingBasis === 'area') {
      measureBasis = 'area';
    }
    if (isRoll && measureBasis === 'unit') {
      measureBasis = 'linear';
    }

    const unitOfMeasure = String(row.unit_of_measure ?? 'ea').trim().toLowerCase() || 'ea';
    const parsedCostExw = parseNumber(row.cost_exw) ?? 0;

    // Roll dimensions: prefer roll_width_value + roll_width_uom; fallback to roll_width_m (legacy)
    const rollWidthValue = parseNumber(row.roll_width_value) ?? parseNumber(row.roll_width_m);
    const rollWidthUom = normalizeRollUom(row.roll_width_uom) || 'm';
    const rollLengthValue = parseNumber(row.roll_length_value) ?? (isRoll ? 29.965 : null);
    const rollLengthUom = normalizeRollUom(row.roll_length_uom) || 'yd';

    const rollPricingModeRaw = String(row.roll_pricing_mode ?? '').trim().toLowerCase();
    const rollPricingMode =
      rollPricingModeRaw === 'per_sqm' || rollPricingModeRaw === 'per_square_meter' ? 'per_square_meter'
      : rollPricingModeRaw === 'per_linear_m' || rollPricingModeRaw === 'per_linear_meter' ? 'per_linear_meter'
      : rollPricingModeRaw === 'per_unit' ? 'per_unit'
      : null;

    const VALID_ROLL_TYPES = new Set(['fabric','window_film','vinyl','mesh','paper','other']);
    const rawRollType = String(row.roll_type ?? '').trim().toLowerCase();
    const rollType = VALID_ROLL_TYPES.has(rawRollType) ? rawRollType : 'fabric';

    const VALID_PURCHASE_UNITS = new Set(['each','box','pack','set','roll','case','bag','bundle','carton','kit','pair','m','ft','yd']);
    const rawPurchaseUnit = String(row.purchase_unit ?? '').trim().toLowerCase();
    const purchaseUnit = VALID_PURCHASE_UNITS.has(rawPurchaseUnit) ? rawPurchaseUnit : 'each';
    const unitsPerPurchase = Math.max(1, parseNumber(row.units_per_purchase_unit) ?? 1);

    const manufacturerName = String(row.manufacturer ?? '').trim() || null;
    const explicitCollection = pickBestImportedText(row.collection_name, row.collection);
    const explicitVariant = pickBestImportedText(row.variant_name, row.variant);
    const explicitColor = normalizeImportedText(row.color);

    return {
      sku: String(row.sku ?? '').trim(),
      name: String(row.name ?? '').trim(),
      description: String(row.description ?? '').trim() || null,
      category_id: categoryId,
      manufacturer_id: manufacturerId,
      manufacturer: manufacturerName,
      measure_basis: measureBasis,
      unit_of_measure: unitOfMeasure,
      is_roll: isRoll,
      roll_type: isRoll ? rollType : null,
      roll_width_value: isRoll && rollWidthValue && rollWidthValue > 0 ? rollWidthValue : null,
      roll_width_uom: isRoll && rollWidthValue && rollWidthValue > 0 ? rollWidthUom : null,
      roll_length_value: isRoll && rollLengthValue && rollLengthValue > 0 ? rollLengthValue : null,
      roll_length_uom: isRoll && rollLengthValue && rollLengthValue > 0 ? rollLengthUom : null,
      roll_pricing_mode: isRoll ? rollPricingMode : null,
      // Support explicit columns first, then keep backward-compatible fallbacks.
      collection_name: isRoll ? (explicitCollection || String(row.category_group ?? '').trim() || null) : null,
      variant_name: isRoll ? (explicitVariant || String(row.name ?? '').trim() || null) : null,
      color: !isRoll ? (explicitColor || null) : null,
      cost_exw: parsedCostExw,
      purchase_unit: purchaseUnit as any,
      units_per_purchase_unit: unitsPerPurchase,
      is_active: parseBoolean(row.is_active, parseBoolean(row.active, true)),
    } as unknown as Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>;
  };

  const runRecompute = async (catalogItemId: string) => {
    const direct = await supabase.rpc('msrp_compute_for_item', { p_item_id: catalogItemId });
    if (!direct.error) return;
    const fallback = await supabase.rpc('recompute_catalog_item_msrp', {
      p_organization_id: activeOrganizationId,
      p_catalog_item_id: catalogItemId,
    });
    if (fallback.error) {
      throw fallback.error;
    }
  };

  const transformLegacyRow = (
    row: ParsedRow
  ): Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'> => {
    const isRoll = parseBoolean(row.is_roll, parseBoolean(row.is_fabric, false));
    const incomingBasis = String(row.measure_basis ?? '').trim().toLowerCase();
    let measureBasis: 'unit' | 'linear' | 'area' = 'unit';
    if (incomingBasis === 'linear' || incomingBasis === 'linear_m' || incomingBasis === 'fabric') {
      measureBasis = 'linear';
    } else if (incomingBasis === 'area') {
      measureBasis = 'area';
    }
    const VALID_PURCHASE_UNITS = new Set(['each','box','pack','set','roll','case','bag','bundle','carton','kit','pair','m','ft','yd']);
    const rawPurchaseUnit = String(row.purchase_unit ?? '').trim().toLowerCase();
    const purchaseUnit = VALID_PURCHASE_UNITS.has(rawPurchaseUnit) ? rawPurchaseUnit : 'each';
    const unitsPerPurchase = Math.max(1, parseNumber(row.units_per_purchase_unit) ?? 1);
    const legacyRollPricingRaw = String(row.roll_pricing_mode ?? row.fabric_pricing_mode ?? '').trim().toLowerCase();
    const legacyRollPricingMode =
      legacyRollPricingRaw === 'per_sqm' || legacyRollPricingRaw === 'per_square_meter' ? 'per_square_meter'
      : legacyRollPricingRaw === 'per_linear_m' || legacyRollPricingRaw === 'per_linear_meter' ? 'per_linear_meter'
      : legacyRollPricingRaw === 'per_unit' ? 'per_unit'
      : null;

    return {
      sku: String(row.sku ?? '').trim(),
      name: String(row.name ?? '').trim(),
      description: String(row.description ?? '').trim() || null,
      measure_basis: measureBasis,
      unit_of_measure: String(row.unit_of_measure ?? row.uom ?? 'ea').trim().toLowerCase() || 'ea',
      is_roll: isRoll,
      roll_width_m: parseNumber(row.roll_width_m),
      roll_pricing_mode: legacyRollPricingMode,
      cost_exw: parseNumber(row.cost_exw ?? row.cost_price) ?? 0,
      purchase_unit: purchaseUnit as any,
      units_per_purchase_unit: unitsPerPurchase,
      is_active: parseBoolean(row.is_active, parseBoolean(row.active, true)),
    } as unknown as Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>;
  };

  const handleImport = async () => {
    if (!activeOrganizationId || parsedData.length === 0) return;

    setIsProcessing(true);
    setImportResult(null);

    const result: ImportResult = {
      success: 0,
      inserted: 0,
      updated: 0,
      failed: 0,
      mappingFailed: 0,
      recomputeFailed: 0,
      errors: [],
    };

    try {
      if (useLegacyImport) {
        for (let index = 0; index < parsedData.length; index += 1) {
          const row = parsedData[index];
          const rowNum = index + 2;
          try {
            const payload = transformLegacyRow(row);
            const upserted = await upsertItemBySku(payload);
            const catalogItemId = upserted?.id as string | undefined;
            if (!catalogItemId) {
              throw new Error('Legacy upsert returned no item id');
            }
            result.success += 1;
            result.updated += 1;
          } catch (error) {
            result.failed += 1;
            result.errors.push({
              row: rowNum,
              field: 'general',
              message: `Legacy import: ${getErrorMessage(error)}`,
            });
          }
        }
      } else {
        const lookups = await loadImportLookups();
        const existingSkuSet = new Set<string>();
        const skuList = Array.from(new Set(parsedData.map((r) => String(r.sku ?? '').trim()).filter(Boolean)));
        const chunkSize = 1000;
        for (let i = 0; i < skuList.length; i += chunkSize) {
          const chunk = skuList.slice(i, i + chunkSize);
          const { data, error } = await supabase
            .from('CatalogItems')
            .select('sku')
            .eq('organization_id', activeOrganizationId)
            .in('sku', chunk);
          if (error) throw error;
          (data || []).forEach((row: { sku: string }) => existingSkuSet.add(String(row.sku).trim()));
        }

        for (let index = 0; index < parsedData.length; index += 1) {
          const row = parsedData[index];
          const rowNum = index + 2;
          try {
            const categoryResolved = resolveCategoryId(row, lookups);
            if (!categoryResolved.categoryId) {
              result.mappingFailed += 1;
              throw new Error(categoryResolved.error || 'Category mapping failed');
            }

            const manufacturerResolved = resolveManufacturerId(row, lookups);
            if (manufacturerResolved.error) {
              result.mappingFailed += 1;
              throw new Error(manufacturerResolved.error);
            }

            const productTypeResolved = resolveProductTypeIds(row, lookups);
            if (productTypeResolved.error) {
              result.mappingFailed += 1;
              throw new Error(productTypeResolved.error);
            }

            const payload = transformRowToCatalogItem(
              row,
              categoryResolved.categoryId,
              manufacturerResolved.manufacturerId
            );

            const wasExisting = existingSkuSet.has(String(payload.sku).trim());
            const upserted = await upsertItemBySku(payload);
            const catalogItemId = upserted?.id as string | undefined;
            if (!catalogItemId) {
              throw new Error('Upsert returned no item id');
            }

            const productTypesColumnProvided = Object.prototype.hasOwnProperty.call(row, 'product_types');
            if (productTypesColumnProvided) {
              await syncCatalogItemProductTypes(
                catalogItemId,
                productTypeResolved.productTypeIds,
                null,
                activeOrganizationId
              );
            }

            const supplyTypeRaw = String(row.supply_type ?? '').trim().toLowerCase();
            const supplyOriginRaw = String(row.supply_origin ?? '').trim().toLowerCase();
            const supplyType: SupplyType = supplyTypeRaw === 'order' ? 'order' : 'stock';
            const supplyOrigin: SupplyOrigin = supplyOriginRaw === 'import' ? 'import' : 'local';
            await upsertCatalogItemSupply({
              catalog_item_id: catalogItemId,
              organization_id: activeOrganizationId!,
              supply_type: supplyType,
              supply_origin: supplyOrigin,
              lead_time_min_days: supplyOrigin === 'import' ? 45 : 8,
              lead_time_max_days: supplyOrigin === 'import' ? 60 : 15,
              notes: null,
            });

            if (payload.is_roll) {
              const weightGsm = parseNumber(row.weight_gsm);
              await upsertCatalogItemRollSpecs({
                catalog_item_id: catalogItemId,
                organization_id: activeOrganizationId!,
                can_rotate: parseBoolean(row.can_rotate, false),
                is_weldable: parseBoolean(row.weldable, false),
                raw_material: String(row.raw_material ?? '').trim() || null,
                openness_factor_pct: parseNumber(row.openness_factor) ?? null,
                weight_g_m2: weightGsm ?? null,
                weight_kg_m2: weightGsm != null ? weightGsm / 1000 : null,
                notes: String(row.notes ?? '').trim() || null,
              });
            }

            try {
              await runRecompute(catalogItemId);
            } catch (recomputeError) {
              result.recomputeFailed += 1;
              result.errors.push({
                row: rowNum,
                field: 'recompute',
                message: `Recompute failed: ${getErrorMessage(recomputeError)}`,
              });
            }

            if (wasExisting) {
              result.updated += 1;
            } else {
              result.inserted += 1;
              existingSkuSet.add(String(payload.sku).trim());
            }
            result.success += 1;
          } catch (error) {
            result.failed += 1;
            result.errors.push({
              row: rowNum,
              field: 'general',
              message: getErrorMessage(error),
            });
          }
        }
      }
    } catch (error) {
      result.failed = parsedData.length;
      result.errors.push({
        row: 0,
        field: 'general',
        message: getErrorMessage(error),
      });
    } finally {
      setImportResult(result);
      setCurrentStep('result');
      setIsProcessing(false);
    }

    if (result.success > 0) {
      useUIStore.getState().addNotification({
        type: result.failed === 0 ? 'success' : 'warning',
        title: 'Import Complete',
        message: `Inserted ${result.inserted}, updated ${result.updated}, failed ${result.failed}`,
      });
      onImportComplete();
    } else {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Import Failed',
        message: `No items imported. ${result.errors.length} errors occurred.`,
      });
    }
  };

  const handleReset = () => {
    setFile(null);
    setParsedData([]);
    setValidationErrors([]);
    setImportResult(null);
    setCurrentStep('upload');
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="relative bg-white rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">Import Catalog Items</h2>
            <p className="text-sm text-gray-600 mt-1">Upload an Excel or CSV file to import catalog items</p>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {currentStep === 'upload' && (
            <div className="space-y-4">
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-primary transition-colors">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv,.xlsx,.xls"
                  onChange={handleFileSelect}
                  className="hidden"
                  id="file-upload"
                />
                <label
                  htmlFor="file-upload"
                  className="cursor-pointer flex flex-col items-center"
                >
                  <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                    <Upload className="w-6 h-6 text-gray-600" />
                  </div>
                  <p className="text-sm font-medium text-gray-900 mb-1">
                    Click to upload or drag and drop
                  </p>
                  <p className="text-xs text-gray-500">
                    CSV or Excel files (.csv, .xlsx, .xls)
                  </p>
                </label>
              </div>

              {file && (
                <div className="bg-gray-50 rounded-lg p-4 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    {file.name.endsWith('.csv') ? (
                      <FileText className="w-5 h-5 text-gray-600" />
                    ) : (
                      <FileSpreadsheet className="w-5 h-5 text-gray-600" />
                    )}
                    <div>
                      <p className="text-sm font-medium text-gray-900">{file.name}</p>
                      <p className="text-xs text-gray-500">{(file.size / 1024).toFixed(2)} KB</p>
                    </div>
                  </div>
                  <button
                    onClick={handleReset}
                    className="text-xs text-gray-500 hover:text-gray-700"
                  >
                    Remove
                  </button>
                </div>
              )}

              {/* Expected columns info */}
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p className="text-xs font-medium text-blue-900 mb-2">Expected Columns:</p>
                <div className="text-xs text-blue-800 space-y-1">
                  <p><strong>Required:</strong> sku, name, category_group, subcategory, measure_basis, unit_of_measure, cost_exw</p>
                  <p><strong>Optional:</strong> description, product_types, manufacturer, collection_name, variant_name, color, purchase_unit, units_per_purchase_unit, is_roll, roll_type, roll_width_value, roll_width_uom, roll_length_value, roll_length_uom, roll_pricing_mode, supply_type, supply_origin, is_active</p>
                  <p><strong>Valid enums:</strong> supply_type = stock | order (default: stock). supply_origin = local | import (default: local)</p>
                  <p><strong>Valid enums:</strong> measure_basis = unit | linear | area</p>
                  <p><strong>Valid enums:</strong> roll_type = fabric | window_film | vinyl | mesh | paper | other (default: fabric)</p>
                  <p><strong>Valid enums:</strong> roll_pricing_mode = per_linear_meter | per_square_meter | per_unit</p>
                  <p><strong>Valid enums:</strong> roll_width_uom / roll_length_uom = m | yd | ft | in (also: meter, yard, feet, inch)</p>
                  <p><strong>Valid enums:</strong> purchase_unit = each | box | pack | set | roll | case | bag | bundle | carton | kit | pair | m | ft | yd</p>
                  <p><strong>Product Types (codes):</strong> roller | dual_shade | triple_shade | drapery | awning | window_film | honey_comb | vertical</p>
                  <p><strong>Default categories:</strong> Rolls/Fabric and Systems/Power Supplies</p>
                  <p><strong>Modeling guide:</strong> EA parts: measure_basis=unit + unit_of_measure=ea. Linear parts: measure_basis=linear + unit_of_measure=m/ft/yd. Roll/Fabric: is_roll=true + roll_type + roll_width_value/uom + collection_name + variant_name.</p>
                  <p><strong>Color rules:</strong> non-roll items can use color column. Roll/fabric uses variant_name for color/variant label.</p>
                  <p><strong>Legacy removed from v2:</strong> item_type, family, unit_price, cost_price, General</p>
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <input
                    id="legacy-import-toggle"
                    type="checkbox"
                    checked={useLegacyImport}
                    onChange={(event) => setUseLegacyImport(event.target.checked)}
                    className="h-3.5 w-3.5 rounded border-blue-300 text-blue-700 focus:ring-blue-500"
                  />
                  <label htmlFor="legacy-import-toggle" className="text-xs text-blue-900">
                    Internal: use Legacy Import
                  </label>
                </div>
                <div className="mt-3">
                  <a
                    href="/catalog_import_template.csv?v=20260325"
                    download="catalog_import_template_v2.csv"
                    className="inline-flex items-center gap-2 px-3 py-1.5 text-xs font-medium text-blue-900 bg-white border border-blue-300 rounded-md hover:bg-blue-100 transition-colors"
                  >
                    <Download className="w-3.5 h-3.5" />
                    Download template
                  </a>
                </div>
              </div>
            </div>
          )}

          {currentStep === 'preview' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-medium text-gray-900">Preview Data</h3>
                  <p className="text-sm text-gray-600">{parsedData.length} items ready to import</p>
                </div>
                {validationErrors.length > 0 && (
                  <div className="flex items-center gap-2 text-sm text-red-600">
                    <AlertCircle className="w-4 h-4" />
                    <span>{validationErrors.length} validation errors</span>
                  </div>
                )}
              </div>

              {validationErrors.length > 0 && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 max-h-48 overflow-y-auto">
                  <p className="text-xs font-medium text-red-900 mb-2">Validation Errors:</p>
                  <div className="space-y-1">
                    {validationErrors.slice(0, 20).map((error, index) => (
                      <p key={index} className="text-xs text-red-800">
                        Row {error.row}, {error.field}: {error.message}
                      </p>
                    ))}
                    {validationErrors.length > 20 && (
                      <p className="text-xs text-red-600 italic">... and {validationErrors.length - 20} more errors</p>
                    )}
                  </div>
                </div>
              )}

              <div className="border border-gray-200 rounded-lg overflow-hidden">
                <div className="table-fit-wrapper max-h-96 overflow-y-auto">
                  <table className="table-fit w-full text-xs">
                    <thead className="bg-gray-50 border-b border-gray-200">
                      <tr>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">SKU</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Name</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Category</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Subcategory</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Cost EXW</th>
                        <th className="text-left py-2 px-3 font-medium text-gray-900">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {parsedData.slice(0, 10).map((row, index) => (
                        <tr key={index} className="hover:bg-gray-50">
                          <td className="py-2 px-3 text-gray-700">{row.sku}</td>
                          <td className="py-2 px-3 text-gray-700">{row.name}</td>
                          <td className="py-2 px-3 text-gray-700">{String(row.category_group ?? '-')}</td>
                          <td className="py-2 px-3 text-gray-700">{String(row.subcategory ?? '-')}</td>
                          <td className="py-2 px-3 text-gray-700">${(parseNumber(row.cost_exw) ?? 0).toFixed(2)}</td>
                          <td className="py-2 px-3 text-gray-700">
                            {parseBoolean(row.is_active, parseBoolean(row.active, true)) ? 'Active' : 'Inactive'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {parsedData.length > 10 && (
                  <div className="bg-gray-50 px-3 py-2 text-xs text-gray-600 text-center border-t border-gray-200">
                    Showing first 10 of {parsedData.length} items
                  </div>
                )}
              </div>
            </div>
          )}

          {currentStep === 'result' && importResult && (
            <div className="space-y-4">
              <div className="text-center">
                {importResult.failed === 0 ? (
                  <CheckCircle2 className="w-16 h-16 text-green-600 mx-auto mb-4" />
                ) : (
                  <AlertCircle className="w-16 h-16 text-yellow-600 mx-auto mb-4" />
                )}
                <h3 className="text-lg font-medium text-gray-900 mb-2">Import Complete</h3>
                <div className="space-y-1 text-sm text-gray-600">
                  <p><strong className="text-green-600">{importResult.success}</strong> items imported successfully</p>
                  <p><strong>{importResult.inserted}</strong> inserted / <strong>{importResult.updated}</strong> updated</p>
                  <p><strong>{importResult.mappingFailed}</strong> mapping failures / <strong>{importResult.recomputeFailed}</strong> recompute failures</p>
                  {importResult.failed > 0 && (
                    <p><strong className="text-red-600">{importResult.failed}</strong> items failed to import</p>
                  )}
                </div>
              </div>

              {importResult.errors.length > 0 && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-4 max-h-48 overflow-y-auto">
                  <p className="text-xs font-medium text-red-900 mb-2">Errors:</p>
                  <div className="space-y-1">
                    {importResult.errors.slice(0, 20).map((error, index) => (
                      <p key={index} className="text-xs text-red-800">
                        Row {error.row}: {error.message}
                      </p>
                    ))}
                    {importResult.errors.length > 20 && (
                      <p className="text-xs text-red-600 italic">... and {importResult.errors.length - 20} more errors</p>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between p-6 border-t border-gray-200 bg-gray-50">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
          >
            {currentStep === 'result' ? 'Close' : 'Cancel'}
          </button>
          <div className="flex items-center gap-3">
            {currentStep === 'preview' && (
              <>
                <button
                  onClick={handleReset}
                  className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Reset
                </button>
                <button
                  onClick={handleImport}
                  disabled={isProcessing || validationErrors.length > 0}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  {isProcessing ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Importing...
                    </>
                  ) : (
                    'Import Items'
                  )}
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

