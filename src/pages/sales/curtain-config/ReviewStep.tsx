import React, { useState, useEffect, useMemo } from 'react';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import DimensionsStackView from '../../../components/DimensionsStackView';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { formatMoney, formatUom } from '../../../lib/format';
import { useCostSettings } from '../../../hooks/useCosts';
import { computeSelectedSnapshotTotals } from '../../../lib/bom/snapshotSelectedTotals';
import { useAccessContext } from '../../../hooks/useAccessContext';
import { computeLaborBreakdownForRule, type LaborTestBreakdownLine } from '../../../lib/laborRules';
import type { LaborRuleRow } from '../../../hooks/useCostEngineSettings';

// ============================================================================
// BOM Preview Snapshot types (from ConfiguredProducts.bom_preview_snapshot)
// ============================================================================
interface BOMSnapshotItem {
  id: string;
  kind: 'roll' | 'parent' | 'child' | 'accessory' | 'labor' | 'other';
  role: string;
  level: number;
  selected: boolean;
  catalog_item_id: string | null;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unit_price: number;
  line_total: number;
  children?: BOMSnapshotItem[];
  meta?: Record<string, any>;
}

interface BOMPreviewSnapshot {
  version: string;
  product_type_id: string;
  bom_template_id: string | null;
  price_basis: 'msrp' | 'dealer';
  currency: string;
  totals: {
    roll_msrp_total: number;
    bom_total: number;
    accessories_total: number;
    labor_pct: number;
    labor_amount: number;
    total_msrp: number;
    roll_total_cost: number;
    bom_total_cost: number;
  };
  items: BOMSnapshotItem[];
}

// Breakdown line type. When from snapshot: qty, uom, unitPrice, totalPrice are source of truth.
// kind + meta used for roll secondary display (≈ $/m² or ≈ $/m when roll_width_m available).
interface BOMBreakdownLine {
  role: string;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unitPrice: number;
  totalPrice: number;
  unitCost?: number;
  totalCost?: number;
  source: 'selected' | 'template' | 'child';
  isChild?: boolean;
  parentRole?: string;
  kind?: 'roll' | 'parent' | 'child' | 'accessory' | 'labor' | 'other';
  meta?: Record<string, unknown>;
}

const OPTIONAL_HARDWARE_ROLES = new Set(['headbox', 'side_channel', 'bottom_channel', 'bottom_bar']);

interface ReviewStepProps {
  config: ProductConfig;
  onUpdate: (updates: Partial<ProductConfig>) => void;
  quoteId?: string; // Optional quote ID (kept for compatibility)
}

export default function ReviewStep({ config, onUpdate }: ReviewStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { settings: costSettings } = useCostSettings();
  const { userType, internalRole } = useAccessContext();
  const normalizedInternalRole = (internalRole ?? '').toString().trim().toLowerCase();
  const canViewInternalBreakdown =
    userType === 'internal' &&
    ['superadmin', 'admin', 'organization_admin'].includes(normalizedInternalRole);
  const [rollData, setRollData] = useState<{
    sku?: string;
    collection_name?: string;
    variant_name?: string;
    roll_width_m?: number | null;
    roll_pricing_mode?: string;
  } | null>(null);
  const [loadingRoll, setLoadingRoll] = useState(false);
  
  // BOM Breakdown state
  const [breakdownLines, setBreakdownLines] = useState<BOMBreakdownLine[]>([]);
  const [loadingBreakdown, setLoadingBreakdown] = useState(false);
  const [showBreakdown, setShowBreakdown] = useState(true);
  const [templateInfo, setTemplateInfo] = useState<{ code: string; name: string } | null>(null);

  const bomPreviewSnapshot = (config as any).bom_preview_snapshot as BOMPreviewSnapshot | undefined;
  const hasValidSnapshot = !!(bomPreviewSnapshot?.version) &&
    Array.isArray(bomPreviewSnapshot?.items) &&
    bomPreviewSnapshot.items.length > 0;

  // Get variant ID from config (supports different product types)
  const getVariantId = () => {
    if ('variantId' in config && config.variantId) {
      return config.variantId;
    }
    if ('fabric' in config && config.fabric?.variantId) {
      return config.fabric.variantId;
    }
    if ('frontFabric' in config && config.frontFabric?.variantId) {
      return config.frontFabric.variantId;
    }
    return null;
  };

  // Load roll (tela) item data from CatalogItems — variant has role 'fabric'
  useEffect(() => {
    const loadRollData = async () => {
      const variantId = getVariantId();
      if (!variantId || !activeOrganizationId) {
        setRollData(null);
        return;
      }

      try {
        setLoadingRoll(true);
        const { data: catalogItem, error } = await supabase
          .from('CatalogItems')
          .select('sku, collection_name, variant_name, roll_width_m, roll_width, roll_pricing_mode, measure_basis')
          .eq('id', variantId)
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true)
          .maybeSingle();

        if (error) {
          const errorMsg = error?.message || error?.error_description || error?.hint || 'Error loading roll data';
          const errorCode = error?.code ? ` (${error.code})` : '';
          console.error('Error loading roll data:', errorMsg + errorCode);
          setRollData(null);
          return;
        }

        if (catalogItem) {
          const rw = (catalogItem as any).roll_width_m ?? (catalogItem as any).roll_width;
          setRollData({
            sku: catalogItem.sku || undefined,
            collection_name: catalogItem.collection_name || undefined,
            variant_name: catalogItem.variant_name || undefined,
            roll_width_m: rw != null ? Number(rw) : null,
            roll_pricing_mode: (catalogItem as any).roll_pricing_mode || ((catalogItem as any).measure_basis === 'linear' ? 'per_linear_meter' : undefined),
          });
        } else {
          setRollData(null);
        }
      } catch (err: any) {
        const errorMsg = err?.message || err?.error_description || err?.hint || 'Error loading roll data';
        console.error('Error loading roll data:', errorMsg);
        setRollData(null);
      } finally {
        setLoadingRoll(false);
      }
    };

    loadRollData();
  }, [config, activeOrganizationId]);

  // Load BOM breakdown from template components
  // Try bom_template_id first, then fall back to _hardware_filtered_templates if single match
  const explicitBomTemplateId = (config as any).bom_template_id;
  const filteredTemplates = (config as any)._hardware_filtered_templates as string[] | undefined;
  
  // Resolve the template ID: explicit > single filtered > null
  const bomTemplateId = explicitBomTemplateId 
    || (filteredTemplates && filteredTemplates.length === 1 ? filteredTemplates[0] : null);
  
  const hasMultipleCandidates = !explicitBomTemplateId && filteredTemplates && filteredTemplates.length > 1;

  useEffect(() => {
    if (!bomTemplateId || !activeOrganizationId) {
      setTemplateInfo(null);
      return;
    }
    let cancelled = false;
    supabase
      .from('BOMTemplates')
      .select('code, name')
      .eq('id', bomTemplateId)
      .maybeSingle()
      .then(({ data }: { data: { code: string; name: string } | null }) => {
        if (cancelled) return;
        setTemplateInfo(data ? { code: data.code || '', name: data.name || '' } : null);
      });
    return () => { cancelled = true; };
  }, [bomTemplateId, activeOrganizationId]);

  // Resolve fabric UOM from roll_pricing_mode (overrides any hardcoded 'm²' in old snapshots)
  const fabricUom = useMemo((): string => {
    const mode = rollData?.roll_pricing_mode;
    if (mode === 'per_linear_meter') return 'm';
    if (mode === 'per_unit') return 'ea';
    return 'm²'; // per_square_meter or unknown
  }, [rollData?.roll_pricing_mode]);

  // ✅ NEW: Convert snapshot items to breakdown lines (no DB queries needed!)
  const snapshotBreakdownLines = useMemo((): BOMBreakdownLine[] => {
    if (!hasValidSnapshot || !bomPreviewSnapshot) return [];

    const lines: BOMBreakdownLine[] = [];
    const configAny = config as any;
    const explicitNoneByRole: Record<string, boolean> = {
      headbox: String(configAny.headbox_item_id ?? '').toUpperCase() === 'NONE',
      side_channel: String(configAny.side_channel_item_id ?? '').toUpperCase() === 'NONE',
      bottom_channel: String(configAny.bottom_channel_item_id ?? '').toUpperCase() === 'NONE',
      bottom_bar: String(configAny.bottom_bar_item_id ?? '').toUpperCase() === 'NONE',
    };

    const processItem = (item: BOMSnapshotItem, isChild = false, parentRole?: string) => {
      const normalizedRole = String(item.role || '').toLowerCase();
      const isExplicitlyExcluded = explicitNoneByRole[normalizedRole] === true;
      // In snapshot mode, optional hardware flagged as not selected should not appear in Review.
      if ((isExplicitlyExcluded || (item.selected === false && OPTIONAL_HARDWARE_ROLES.has(normalizedRole))) && !isChild) {
        return;
      }

      // For roll/fabric: always use the UOM derived from roll_pricing_mode (fixes old snapshots with hardcoded m²)
      const resolvedUom = (item.kind === 'roll' || item.role === 'fabric')
        ? fabricUom
        : item.uom;

      lines.push({
        role: item.role,
        sku: item.sku,
        name: item.name,
        qty: item.qty,
        uom: resolvedUom,
        unitPrice: item.unit_price,
        totalPrice: item.line_total,
        unitCost: (item.meta as any)?.unit_cost != null ? Number((item.meta as any).unit_cost) : undefined,
        totalCost: (item.meta as any)?.line_cost != null ? Number((item.meta as any).line_cost) : undefined,
        source: item.selected ? 'selected' : isChild ? 'child' : 'template',
        isChild,
        parentRole,
        kind: item.kind,
        meta: item.meta,
      });

      // Process nested children
      if (item.children && item.children.length > 0) {
        item.children.forEach(child => processItem(child, true, item.role));
      }
    };

    bomPreviewSnapshot.items.forEach(item => processItem(item));

    return lines;
  }, [hasValidSnapshot, bomPreviewSnapshot, config, fabricUom]);

  useEffect(() => {
    // ✅ If we have a valid snapshot, use it directly (no queries needed)
    if (hasValidSnapshot) {
      setBreakdownLines(snapshotBreakdownLines);
      setLoadingBreakdown(false);
      return;
    }
    
    // Fallback: load from DB
    const loadBreakdown = async () => {
      if (!bomTemplateId || !activeOrganizationId) {
        setBreakdownLines([]);
        return;
      }

      try {
        setLoadingBreakdown(true);

        // 1. Get all components from BOMComponents (including condition columns)
        const { data: rawComponents, error: componentsError } = await supabase
          .from('BOMComponents')
          .select(`
            id,
            component_role,
            component_item_id,
            qty_type,
            qty_value,
            qty_delta_mm,
            uom,
            parent_component_id,
            condition_key,
            condition_value,
            is_required
          `)
          .eq('bom_template_id', bomTemplateId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('sort_order', { ascending: true });

        if (componentsError) throw componentsError;
        if (!rawComponents || rawComponents.length === 0) {
          setBreakdownLines([]);
          return;
        }

        // 2. Build map of selected items from config
        const configAny = config as any;
        const normalizedRoleSelection = (value: unknown): string | null => {
          if (value == null) return null;
          const s = String(value).trim();
          if (!s || s.toUpperCase() === 'NONE') return null;
          return s;
        };
        const selectedItems: Record<string, string | null> = {
          bottom_bar: normalizedRoleSelection(configAny.bottom_bar_item_id),
          headbox: normalizedRoleSelection(configAny.headbox_item_id),
          side_channel: normalizedRoleSelection(configAny.side_channel_item_id),
          bottom_channel: normalizedRoleSelection(configAny.bottom_channel_item_id),
          motor: normalizedRoleSelection(configAny.motor_item_id),
          drive: normalizedRoleSelection(configAny.drive_item_id),
          tube: normalizedRoleSelection(configAny.tube_item_id),
          track: normalizedRoleSelection(configAny.track_item_id),
        };

        // 3. Collect all catalog item IDs we need to fetch
        const catalogItemIds = new Set<string>();
        const variantId = getVariantId();
        if (variantId) catalogItemIds.add(variantId);
        Object.values(selectedItems).forEach(id => { if (id) catalogItemIds.add(id); });
        rawComponents.forEach((c: any) => {
          if (c.component_item_id) catalogItemIds.add(c.component_item_id);
        });

        if (catalogItemIds.size === 0) {
          setBreakdownLines([]);
          return;
        }

        // 4. Fetch CatalogItems info
        const { data: catalogItems, error: itemsError } = await supabase
          .from('CatalogItems')
          .select('id, sku, name, unit_of_measure')
          .in('id', Array.from(catalogItemIds))
          .eq('organization_id', activeOrganizationId);

        if (itemsError) throw itemsError;

        const itemMap = new Map<string, { sku: string; name: string; uom: string }>();
        (catalogItems || []).forEach((item: any) => {
          itemMap.set(item.id, {
            sku: item.sku || '',
            name: item.name || item.sku || '',
            uom: item.unit_of_measure || 'ea',
          });
        });

        // 5. Filter components by condition_key/condition_value
        const components = rawComponents.filter((c: any) => {
          const condKey = (c.condition_key || '').trim();
          if (!condKey) return true;
          const condVal = c.condition_value || '';
          if (condKey === 'motor_item_id') {
            const selectedMotorId = configAny.motor_item_id;
            if (!selectedMotorId) return false;
            const motorInfo = itemMap.get(selectedMotorId);
            return (motorInfo?.sku || '') === condVal;
          }
          return (configAny[condKey] ?? '') === condVal;
        });

        // 5. Fetch MSRP prices from CatalogItemsMSRP
        const { data: msrpData, error: msrpError } = await supabase
          .from('CatalogItemsMSRP')
          .select('catalog_item_id, msrp, total_cost')
          .in('catalog_item_id', Array.from(catalogItemIds))
          .eq('organization_id', activeOrganizationId);

        if (msrpError) {
          console.warn('Error loading MSRP data:', msrpError.message);
        }

        const priceMap = new Map<string, { msrp: number; cost: number }>();
        (msrpData || []).forEach((row: any) => {
          priceMap.set(row.catalog_item_id, {
            msrp: Number(row.msrp) || 0,
            cost: Number(row.total_cost) || 0,
          });
        });

        // 6. Calculate dimensions for qty calculation
        const widthMm = Number((config as any).width_mm) || 0;
        const heightMm = Number((config as any).height_mm) || 0;
        const widthM = widthMm / 1000;
        const heightM = heightMm / 1000;

        // 7. Build breakdown lines - process parents first, then children
        const lines: BOMBreakdownLine[] = [];
        const parentComponents = components.filter((c: any) => !c.parent_component_id);
        const childComponents = components.filter((c: any) => c.parent_component_id);
        
        // Build a map of parent component ID to role for child display
        const parentIdToRole = new Map<string, string>();
        parentComponents.forEach((p: any) => {
          parentIdToRole.set(p.id, p.component_role || 'unknown');
        });

        // Helper function to calculate qty
        const calculateQty = (comp: any): number => {
          let qty = Number(comp.qty_value) || 1;
          const qtyType = comp.qty_type || 'fixed';
          const deltaMm = Number(comp.qty_delta_mm) || 0;

          if (qtyType === 'per_width' || qtyType === 'width') {
            qty = Math.max(0, (widthMm + deltaMm) / 1000);
          } else if (qtyType === 'per_height' || qtyType === 'height') {
            qty = Math.max(0, (heightMm + deltaMm) / 1000);
          } else if (qtyType === 'per_m2' || qtyType === 'area') {
            qty = Math.max(0, widthM * heightM);
          }
          return qty;
        };

        // Process parent components
        parentComponents.forEach((comp: any) => {
          const role = (comp.component_role || '').toLowerCase();
          const selectedId = selectedItems[role];
          const isOptionalRole = OPTIONAL_HARDWARE_ROLES.has(role);
          const isOptionalAndNotSelected = isOptionalRole && comp.is_required === false && !selectedId;
          if (isOptionalAndNotSelected) return;
          const itemId = selectedId || comp.component_item_id;

          if (!itemId) return; // Skip if no item

          const itemInfo = itemMap.get(itemId);
          const priceInfo = priceMap.get(itemId);
          const qty = calculateQty(comp);
          const unitPrice = priceInfo?.msrp || 0;
          const unitCost = priceInfo?.cost || 0;
          const totalPrice = qty * unitPrice;
          const totalCost = qty * unitCost;

          lines.push({
            role: comp.component_role || 'unknown',
            sku: itemInfo?.sku || null,
            name: itemInfo?.name || null,
            qty: Math.round(qty * 1000) / 1000,
            uom: comp.uom || itemInfo?.uom || 'ea',
            unitPrice,
            totalPrice: Math.round(totalPrice * 100) / 100,
            unitCost,
            totalCost: Math.round(totalCost * 100) / 100,
            source: selectedId ? 'selected' : 'template',
            isChild: false,
          });

          // Add children of this parent immediately after
          const children = childComponents.filter((c: any) => c.parent_component_id === comp.id);
          children.forEach((child: any) => {
            const childItemId = child.component_item_id;
            if (!childItemId) return;

            const childItemInfo = itemMap.get(childItemId);
            const childPriceInfo = priceMap.get(childItemId);
            const childQty = calculateQty(child);
            const childUnitPrice = childPriceInfo?.msrp || 0;
            const childUnitCost = childPriceInfo?.cost || 0;
            const childTotalPrice = childQty * childUnitPrice;
            const childTotalCost = childQty * childUnitCost;

            lines.push({
              role: child.component_role || 'child',
              sku: childItemInfo?.sku || null,
              name: childItemInfo?.name || null,
              qty: Math.round(childQty * 1000) / 1000,
              uom: child.uom || childItemInfo?.uom || 'ea',
              unitPrice: childUnitPrice,
              totalPrice: Math.round(childTotalPrice * 100) / 100,
              unitCost: childUnitCost,
              totalCost: Math.round(childTotalCost * 100) / 100,
              source: 'child',
              isChild: true,
              parentRole: comp.component_role,
            });
          });
        });

        // Add fabric line if exists (variantId was captured above).
        // UOM depends on roll_pricing_mode: per_linear_meter → 'm', per_unit → 'ea', else → 'm²'
        if (variantId) {
          const fabricPrice = priceMap.get(variantId);
          const fabricItem = itemMap.get(variantId);
          const rollPricingMode = rollData?.roll_pricing_mode || 'per_square_meter';
          let fabricQty: number;
          let fabricUom: string;
          if (rollPricingMode === 'per_linear_meter') {
            fabricQty = heightM;
            fabricUom = 'm';
          } else if (rollPricingMode === 'per_unit') {
            fabricQty = 1;
            fabricUom = 'ea';
          } else {
            fabricQty = widthM * heightM;
            fabricUom = 'm²';
          }

          lines.unshift({
            role: 'fabric',
            sku: rollData?.sku || fabricItem?.sku || null,
            name: rollData?.variant_name || fabricItem?.name || 'Roll',
            qty: Math.round(fabricQty * 1000) / 1000,
            uom: fabricUom,
            unitPrice: fabricPrice?.msrp || 0,
            totalPrice: Math.round((fabricQty * (fabricPrice?.msrp || 0)) * 100) / 100,
            unitCost: fabricPrice?.cost || 0,
            totalCost: Math.round((fabricQty * (fabricPrice?.cost || 0)) * 100) / 100,
            source: 'selected',
          });
        }

        setBreakdownLines(lines);
      } catch (err: any) {
        console.error('Error loading BOM breakdown:', err?.message || err);
        setBreakdownLines([]);
      } finally {
        setLoadingBreakdown(false);
      }
    };

    loadBreakdown();
  }, [bomTemplateId, activeOrganizationId, config, rollData, hasValidSnapshot, snapshotBreakdownLines]);

  // ── HARD LOCK: bom_preview_snapshot.totals is PRIMARY. configured_product_totals + CP columns fallback. NO calculations.
  const snapshotTotals = (config as any).bom_preview_snapshot?.totals ?? null;
  const selectedSnapshotTotals = computeSelectedSnapshotTotals((config as any).bom_preview_snapshot);
  const configuredProductTotals = (config as any).configured_product_totals ?? null;
  // Prefer snapshot; fallback to configured_product_totals (e.g. createConfiguredProductPreview fallback path)
  const totals = snapshotTotals ?? (configuredProductTotals && typeof configuredProductTotals === 'object' ? configuredProductTotals : null);

  // Safety guard: warn if we have config but no totals (do NOT recalculate)
  useEffect(() => {
    if ((config as any).bom_preview_snapshot && !snapshotTotals && !configuredProductTotals) {
      console.warn('[PRICING] Missing totals from bom_preview_snapshot and configured_product_totals');
    }
  }, [snapshotTotals, configuredProductTotals, (config as any).bom_preview_snapshot]);

  // ── DISPLAY ONLY: 1) bom_preview_snapshot.totals 2) CP columns. NO calculations.
  type TotalsShape = {
    roll_msrp_total: number;
    bom_total: number;
    accessories_total: number;
    labor_pct: number;
    labor_amount: number;
    msrp_product_subtotal: number;
    total_msrp: number;
  };

  const cpDirect = config as any;

  const effectiveTotals: TotalsShape = useMemo(() => {
    const t = totals as Record<string, number> | null;
    const rollMsrp = (selectedSnapshotTotals?.rollMsrp != null ? Number(selectedSnapshotTotals.rollMsrp) : null) ?? (t?.roll_msrp_total != null ? Number(t.roll_msrp_total) : null) ?? (cpDirect.roll_msrp_total != null ? Number(cpDirect.roll_msrp_total) : null) ?? 0;
    const bomTotal = (selectedSnapshotTotals?.bomMsrp != null ? Number(selectedSnapshotTotals.bomMsrp) : null) ?? (t?.bom_total != null ? Number(t.bom_total) : null) ?? (t?.bom_msrp_total != null ? Number(t.bom_msrp_total) : null) ?? (cpDirect.bom_total != null ? Number(cpDirect.bom_total) : null) ?? 0;
    const accessoriesTotal = (t?.accessories_total != null ? Number(t.accessories_total) : null) ?? (cpDirect.accessories_total != null ? Number(cpDirect.accessories_total) : null) ?? 0;
    const rawLaborPct =
      (t?.labor_msrp_pct != null ? Number(t.labor_msrp_pct) : null) ??
      (cpDirect.labor_msrp_pct != null ? Number(cpDirect.labor_msrp_pct) : null) ??
      (t?.labor_pct != null ? Number(t.labor_pct) : null) ??
      ((costSettings as any)?.labor_msrp_pct != null ? Number((costSettings as any).labor_msrp_pct) : null) ??
      (cpDirect.labor_pct != null ? Number(cpDirect.labor_pct) : null) ??
      ((costSettings as any)?.labor_pct != null ? Number((costSettings as any).labor_pct) : null) ??
      0;
    const laborPct = rawLaborPct <= 1 ? rawLaborPct : rawLaborPct / 100;
    const laborAmount = (t?.labor_amount != null ? Number(t.labor_amount) : null) ?? (t?.labor_msrp != null ? Number(t.labor_msrp) : null) ?? (cpDirect.labor_amount != null ? Number(cpDirect.labor_amount) : null) ?? (cpDirect.labor_msrp != null ? Number(cpDirect.labor_msrp) : null) ?? 0;
    const snapshotTotalMsrp =
      (selectedSnapshotTotals?.totalMsrp != null ? Number(selectedSnapshotTotals.totalMsrp) : null) ??
      (t?.total_msrp != null ? Number(t.total_msrp) : null) ??
      (t?.unit_msrp_total != null ? Number(t.unit_msrp_total) : null) ??
      null;
    const derivedTotalMsrp = (rollMsrp + bomTotal + accessoriesTotal) > 0 && laborAmount > 0
      ? (rollMsrp + bomTotal + accessoriesTotal + laborAmount)
      : null;
    const totalMsrp = snapshotTotalMsrp ?? derivedTotalMsrp ?? (cpDirect.unit_msrp_total != null ? Number(cpDirect.unit_msrp_total) : null) ?? (cpDirect.total_msrp != null ? Number(cpDirect.total_msrp) : null) ?? 0;
    const msrpProductSubtotal = (t?.msrp_product_subtotal != null ? Number(t.msrp_product_subtotal) : null) ?? (cpDirect.msrp_product_subtotal != null ? Number(cpDirect.msrp_product_subtotal) : null) ?? 0;
    return {
      roll_msrp_total: rollMsrp,
      bom_total: bomTotal,
      accessories_total: accessoriesTotal,
      labor_pct: laborPct * 100,
      labor_amount: laborAmount,
      msrp_product_subtotal: msrpProductSubtotal,
      total_msrp: totalMsrp,
    };
  }, [totals, cpDirect, costSettings, selectedSnapshotTotals]);

  // TOTAL PRODUCT MSRP (unit) — from totals/CP first; fallback: sum breakdown lines (preview without saved totals)
  const totalProductMsrpUnit = useMemo(() => {
    if (effectiveTotals.total_msrp > 0) return effectiveTotals.total_msrp;
    // Fallback: sum all breakdown lines visible in the table
    if (breakdownLines.length > 0) {
      return breakdownLines.reduce((sum, line) => sum + (Number(line.totalPrice) || 0), 0);
    }
    return 0;
  }, [effectiveTotals.total_msrp, breakdownLines]);

  // Line quantity (multiplicador): used when adding multiple same units to quote
  const lineQuantity = Math.max(1, Number((config as any).quantity) || 1);

  // Preview fallback for labor MSRP when totals are not persisted yet.
  const effectiveLaborMsrpAmount = useMemo(() => {
    if ((effectiveTotals.labor_amount || 0) > 0) return Number(effectiveTotals.labor_amount);
    const msrpMaterials = Number(effectiveTotals.roll_msrp_total || 0) + Number(effectiveTotals.bom_total || 0) + Number(effectiveTotals.accessories_total || 0);
    const laborPctDec = Number(effectiveTotals.labor_pct || 0) / 100;
    if (msrpMaterials <= 0 || laborPctDec <= 0) return 0;
    return msrpMaterials * laborPctDec;
  }, [effectiveTotals]);

  // ── Labor COST breakdown (verification, display-only) ────────────────
  // Reconstructs how the stored labor COST was composed (base, heatseal, bottom bar
  // wrap, confection, size escalation) from the authoritative ConfiguredProducts.labor_calc_meta
  // (which carries the matched rule_id + input context) plus the matched LaborRule rates.
  // It does NOT recompute or alter any stored price — it mirrors the SQL engine for transparency.
  const laborMeta = useMemo(
    () => (snapshotTotals as any)?.labor_calc_meta || (configuredProductTotals as any)?.labor_meta || null,
    [snapshotTotals, configuredProductTotals],
  );
  const [laborRule, setLaborRule] = useState<LaborRuleRow | null>(null);
  useEffect(() => {
    const ruleId = laborMeta?.rule_id;
    if (!ruleId || laborMeta?.source !== 'labor_rule') {
      setLaborRule(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase
        .from('LaborRules')
        .select('*')
        .eq('id', ruleId)
        .maybeSingle();
      if (!cancelled && !error && data) setLaborRule(data as LaborRuleRow);
    })();
    return () => {
      cancelled = true;
    };
  }, [laborMeta?.rule_id, laborMeta?.source]);

  const laborCostBreakdown = useMemo(() => {
    if (!laborRule || !laborMeta) return null;
    const ctx = laborMeta.context || {};
    const lines: LaborTestBreakdownLine[] = computeLaborBreakdownForRule(laborRule, {
      productTypeId: (laborRule as any).product_type_id ?? null,
      widthMm: Number(ctx.width_mm ?? 0),
      heightMm: Number(ctx.height_mm ?? 0),
      panelCount: Number(ctx.panel_count ?? 1),
      drops: Number(ctx.drops ?? 1),
      hasMotor: Boolean(ctx.has_motor),
      operatingType: ctx.operating_type ?? null,
      materialsCost: Number(laborMeta.materials_cost ?? 0),
      heatsealLengthM: Number(ctx.heatseal_length_m ?? 0),
      bottomBarWrapped: Boolean(ctx.bottom_bar_wrapped),
    }).breakdown.filter((l) => l.active || Math.abs(l.contribution) > 0.005);
    const sum = lines.reduce((s, l) => s + (Number(l.contribution) || 0), 0);
    const authoritative = Number(laborMeta.rounded_cost ?? laborMeta.raw_cost ?? sum);
    const rounding = authoritative - sum;
    return {
      lines,
      sum,
      authoritative,
      rounding,
      ruleName: laborMeta.display_name ?? (laborRule as any).display_name ?? 'Labor rule',
      calcMode: laborMeta.calc_mode ?? (laborRule as any).calc_mode ?? null,
    };
  }, [laborRule, laborMeta]);

  // Pricing ladder params from totals/settings
  const t = totals as Record<string, number> | null;
  const minimumMarginPctRaw =
    (t?.minimum_margin_pct != null ? Number(t.minimum_margin_pct) : null) ??
    (cpDirect.minimum_margin_pct != null ? Number(cpDirect.minimum_margin_pct) : null) ??
    ((costSettings as any)?.minimum_margin_pct != null ? Number((costSettings as any).minimum_margin_pct) : null) ??
    0.35;
  const msrpMarginPctRaw =
    (t?.msrp_margin_pct != null ? Number(t.msrp_margin_pct) : null) ??
    (t?.default_msrp_pct != null ? Number(t.default_msrp_pct) : null) ??
    (cpDirect.default_msrp_pct != null ? Number(cpDirect.default_msrp_pct) : null) ??
    ((costSettings as any)?.default_msrp_pct != null ? Number((costSettings as any).default_msrp_pct) : null) ??
    0.65;
  const minimumMarginPct = minimumMarginPctRaw <= 1 ? minimumMarginPctRaw : minimumMarginPctRaw / 100;
  const msrpMarginPct = msrpMarginPctRaw <= 1 ? msrpMarginPctRaw : msrpMarginPctRaw / 100;
  const dealerFactor = Math.max(0.01, 1 - minimumMarginPct);
  const msrpFactor = Math.max(0.01, 1 - msrpMarginPct);

  // DISPLAY ONLY: 1) bom_preview_snapshot.totals 2) CP columns. No calculations.
  const effectiveCosts = useMemo(() => {
    const t = totals as Record<string, number> | null;
    const rollCostFromData = (selectedSnapshotTotals?.rollCost != null ? Number(selectedSnapshotTotals.rollCost) : null) ?? (t?.roll_total_cost != null ? Number(t.roll_total_cost) : null) ?? (cpDirect.roll_total_cost != null ? Number(cpDirect.roll_total_cost) : null) ?? null;
    const bomCostFromData = (selectedSnapshotTotals?.bomCost != null ? Number(selectedSnapshotTotals.bomCost) : null) ?? (t?.bom_total_cost != null ? Number(t.bom_total_cost) : null) ?? (cpDirect.bom_total_cost != null ? Number(cpDirect.bom_total_cost) : null) ?? null;
    const accessoriesCost = (t?.accessories_total_cost != null ? Number(t.accessories_total_cost) : null) ?? (cpDirect.accessories_total_cost != null ? Number(cpDirect.accessories_total_cost) : null) ?? 0;
    const productCostFromData = (t?.unit_product_cost != null ? Number(t.unit_product_cost) : null) ?? (cpDirect.unit_product_cost != null ? Number(cpDirect.unit_product_cost) : null) ?? null;
    const laborCostFromData = (t?.unit_labor_cost != null ? Number(t.unit_labor_cost) : null) ?? (t?.labor_cost != null ? Number(t.labor_cost) : null) ?? (t?.labor_cost_snapshot != null ? Number(t.labor_cost_snapshot) : null) ?? (cpDirect.unit_labor_cost != null ? Number(cpDirect.unit_labor_cost) : null) ?? null;
    const rawLaborCostPct =
      (t?.labor_pct != null ? Number(t.labor_pct) : null) ??
      (cpDirect.labor_pct != null ? Number(cpDirect.labor_pct) : null) ??
      ((costSettings as any)?.labor_pct != null ? Number((costSettings as any).labor_pct) : null) ??
      0;
    const laborCostPct = rawLaborCostPct <= 1 ? rawLaborCostPct * 100 : rawLaborCostPct;
    const totalCostFromData = (t?.total_cost != null ? Number(t.total_cost) : null) ?? (cpDirect.total_cost != null ? Number(cpDirect.total_cost) : null) ?? null;

    // Preview fallback (before save): derive costs from live breakdown lines.
    const rollCostPreview = breakdownLines
      .filter((line) => (line.role || '').toLowerCase() === 'fabric' || line.kind === 'roll')
      .reduce((sum, line) => sum + (Number(line.totalCost) || 0), 0);
    const bomCostPreview = breakdownLines
      .filter((line) => {
        const role = (line.role || '').toLowerCase();
        return role !== 'fabric' && role !== 'labor' && line.kind !== 'roll' && line.kind !== 'labor' && line.kind !== 'accessory';
      })
      .reduce((sum, line) => sum + (Number(line.totalCost) || 0), 0);

    const rollCost = rollCostFromData != null && rollCostFromData > 0 ? rollCostFromData : rollCostPreview;
    const bomCost = bomCostFromData != null && bomCostFromData > 0 ? bomCostFromData : bomCostPreview;
    const productCost = productCostFromData != null && productCostFromData > 0 ? productCostFromData : (rollCost + bomCost + accessoriesCost);
    const laborCost = laborCostFromData != null && laborCostFromData > 0 ? laborCostFromData : (productCost * (laborCostPct / 100));
    const totalCost = totalCostFromData != null && totalCostFromData > 0 ? totalCostFromData : (productCost + laborCost);

    return {
      roll_cost: rollCost,
      bom_cost: bomCost,
      accessories_cost: accessoriesCost,
      unit_product_cost: productCost,
      unit_labor_cost: laborCost,
      labor_pct: laborCostPct,
      total_cost: totalCost,
    };
  }, [cpDirect, totals, breakdownLines, costSettings, selectedSnapshotTotals]);

  const unitDealerPriceFromDataRaw =
    (t?.unit_dealer_price != null ? Number(t.unit_dealer_price) : null) ??
    (cpDirect.unit_dealer_price != null ? Number(cpDirect.unit_dealer_price) : null) ??
    ((config as any).unit_dealer_price_snapshot != null ? Number((config as any).unit_dealer_price_snapshot) : null) ??
    ((config as any).unit_dealer_price != null ? Number((config as any).unit_dealer_price) : null) ??
    null;
  const unitDealerPriceFromData =
    unitDealerPriceFromDataRaw != null && Number(unitDealerPriceFromDataRaw) > 0
      ? Number(unitDealerPriceFromDataRaw)
      : null;
  const unitMsrpFromData =
    (t?.unit_msrp != null ? Number(t.unit_msrp) : null) ??
    (t?.total_msrp != null ? Number(t.total_msrp) : null) ??
    (t?.unit_msrp_total != null ? Number(t.unit_msrp_total) : null) ??
    (cpDirect.unit_msrp_total != null ? Number(cpDirect.unit_msrp_total) : null) ??
    (cpDirect.total_msrp != null ? Number(cpDirect.total_msrp) : null) ??
    null;
  const computedUnitDealerPrice =
    unitDealerPriceFromData != null
      ? Number(unitDealerPriceFromData)
      : (Number(effectiveCosts.total_cost || 0) > 0
          ? Number(effectiveCosts.total_cost || 0) / dealerFactor
          : null);
  const computedUnitMsrp =
    unitMsrpFromData != null
      ? Number(unitMsrpFromData)
      : (computedUnitDealerPrice != null
          ? Number(computedUnitDealerPrice) / msrpFactor
          : null);
  const dealerLineTotalFromDataRaw =
    (t?.dealer_price_total != null ? Number(t.dealer_price_total) : null) ??
    (cpDirect.dealer_price_total != null ? Number(cpDirect.dealer_price_total) : null) ??
    ((config as any).dealer_price_total_snapshot != null ? Number((config as any).dealer_price_total_snapshot) : null) ??
    null;
  const dealerLineTotal =
    computedUnitDealerPrice != null
      ? Number(computedUnitDealerPrice) * lineQuantity
      : (dealerLineTotalFromDataRaw != null && Number(dealerLineTotalFromDataRaw) > 0
          ? Number(dealerLineTotalFromDataRaw)
          : null);
  const msrpLineTotalFromDataRaw =
    (t?.msrp_total != null ? Number(t.msrp_total) : null) ??
    ((config as any).msrp_total_snapshot != null ? Number((config as any).msrp_total_snapshot) : null) ??
    null;
  const effectiveUnitMsrp = totalProductMsrpUnit || computedUnitMsrp;
  const msrpLineTotal =
    effectiveUnitMsrp != null
      ? Number(effectiveUnitMsrp) * lineQuantity
      : (msrpLineTotalFromDataRaw != null && Number(msrpLineTotalFromDataRaw) > 0
          ? Number(msrpLineTotalFromDataRaw)
          : null);

  // Total quantity of components (sum of Qty column) for Breakdown summary
  const breakdownTotalQty = useMemo(() => {
    const fromLines = breakdownLines.reduce((sum, line) => sum + Number(line.qty) || 0, 0);
    const accessoriesQty = snapshotTotals && (snapshotTotals.accessories_total || 0) > 0
      ? ((config as any).accessories?.length || 1)
      : 0;
    const laborQty = snapshotTotals && (snapshotTotals.labor_amount || 0) > 0 ? 1 : 0;
    return fromLines + accessoriesQty + laborQty;
  }, [breakdownLines, snapshotTotals, (config as any).accessories?.length]);

  const dimensionsSource = {
    width_mm: (config as any).width_mm,
    height_mm: (config as any).height_mm,
    measurements: (config as any).measurements,
    panels: (config as any).panels,
  };
  const measurements = (config as any).measurements;
  const widthTotalMm = measurements?.width_total_mm ?? (config as any).width_mm ?? null;
  const heightMm = measurements?.height_mm ?? (config as any).height_mm ?? null;
  const hasTotalDimensions = widthTotalMm != null && widthTotalMm > 0 && heightMm != null && heightMm > 0;
  const hasRollData = rollData && (rollData.sku || rollData.collection_name || rollData.variant_name);

  const panelsList = (config as any).measurements?.panels ?? (Array.isArray((config as any).panels) ? (config as any).panels : []);

  // Total fabric = sum of all panel widths × height, in m²
  const fabricRollInfo = (() => {
    const totalWidthMmVal = widthTotalMm ?? (panelsList.length > 0
      ? panelsList.reduce((s: number, p: any) => s + (Number(p?.width_mm) || 0), 0)
      : ((config as any).width_mm ?? null));
    const heightMmVal = heightMm ?? ((config as any).height_mm ?? null);
    if (totalWidthMmVal != null && totalWidthMmVal > 0 && heightMmVal != null && heightMmVal > 0) {
      const m2 = (totalWidthMmVal / 1000) * (heightMmVal / 1000);
      return { qty: m2, uom: 'm²' as const };
    }
    if (!hasValidSnapshot || !bomPreviewSnapshot?.items) return null;
    const roll = bomPreviewSnapshot.items.find((i: any) => i.kind === 'roll' || i.role === 'fabric');
    if (roll?.qty == null) return null;
    return { qty: Number(roll.qty), uom: fabricUom };
  })();

  // Rule: no panel can be wider than the roll; note: rotate fabric if applicable
  const rollWidthMm = rollData?.roll_width_m != null && rollData.roll_width_m > 0
    ? rollData.roll_width_m * 1000
    : null;
  const panelsExceedingRoll = rollWidthMm != null && panelsList.length > 0
    ? panelsList
        .map((p: any, i: number) => ({ index: i + 1, width_mm: p?.width_mm ?? 0 }))
        .filter((p: { index: number; width_mm: number }) => p.width_mm > rollWidthMm)
    : [];
  const showRollWidthWarning = panelsExceedingRoll.length > 0;

  const laborUnresolved = Boolean(
    (snapshotTotals as any)?.labor_unresolved === true ||
      (snapshotTotals as any)?.labor_engine_source === 'unresolved' ||
      (configuredProductTotals as any)?.labor_unresolved === true
  );
  const laborUnresolvedContext = (() => {
    const meta = (snapshotTotals as any)?.labor_calc_meta || (configuredProductTotals as any)?.labor_meta;
    const ctx = meta?.context || {};
    const parts: string[] = [];
    if (ctx.width_mm != null) parts.push(`${Number(ctx.width_mm).toFixed(0)}mm wide`);
    if (ctx.height_mm != null) parts.push(`${Number(ctx.height_mm).toFixed(0)}mm tall`);
    if (ctx.panel_count != null) parts.push(`${ctx.panel_count} panel${ctx.panel_count === 1 ? '' : 's'}`);
    if (ctx.drops != null) parts.push(`${ctx.drops} drop${ctx.drops === 1 ? '' : 's'}`);
    if (ctx.has_motor != null) parts.push(ctx.has_motor ? 'motorized' : 'manual');
    return parts.join(', ');
  })();

  return (
    <div className="max-w-4xl mx-auto">
      {laborUnresolved && (
        <div className="mb-4 p-4 bg-red-50 border-2 border-red-300 rounded-lg">
          <div className="flex items-start gap-3">
            <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-red-200 shrink-0">
              <svg className="w-4 h-4 text-red-700" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.732 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.008v.008H12v-.008Z" />
              </svg>
            </span>
            <div className="flex-1">
              <h3 className="text-sm font-semibold text-red-900">
                Labor cost is unresolved — pricing is BLOCKED
              </h3>
              <p className="text-xs text-red-800 mt-1">
                No active LaborRule matches this configuration{laborUnresolvedContext ? ` (${laborUnresolvedContext})` : ''}.
                The legacy Labor % fallback has been disabled, so this line cannot be saved until you create a covering rule.
              </p>
              <a
                href="/settings/cost-engine"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center mt-2 text-xs font-medium text-red-900 underline"
              >
                Open Settings → Cost Engine → Labor Rules
              </a>
            </div>
          </div>
        </div>
      )}
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-lg font-semibold mb-6 block">CONFIGURED PRODUCT</Label>
          
          <div className="space-y-5">
            {/* Track Only indicator */}
            {(config as any).track_only && (
              <div className="pb-5 border-b border-gray-200">
                <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                  <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-gray-200">
                    <svg className="w-4 h-4 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="m4.5 12.75 6 6 9-13.5" /></svg>
                  </span>
                  <div>
                    <p className="text-sm font-medium text-gray-900">Track Only</p>
                    <p className="text-xs text-gray-500">Customer supplies their own fabric — no fabric included in this quote.</p>
                  </div>
                </div>
              </div>
            )}

            {/* Dealer Supply Fabric indicator (ghost fabric: cut list kept, fabric cost excluded) */}
            {(config as any).dealer_supply_fabric && (
              <div className="pb-5 border-b border-gray-200">
                <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                  <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-gray-200">
                    <svg className="w-4 h-4 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 9.75h16.5m-16.5 0v8.25a1.5 1.5 0 0 0 1.5 1.5h13.5a1.5 1.5 0 0 0 1.5-1.5V9.75m-16.5 0L5.25 4.5h13.5l1.5 5.25M9 13.5h6" /></svg>
                  </span>
                  <div>
                    <p className="text-sm font-medium text-gray-900">Dealer-supplied fabric</p>
                    <p className="text-xs text-gray-500">Client provides the fabric — cut list included, fabric cost excluded. Labor & hardware remain.</p>
                  </div>
                </div>
              </div>
            )}

            {/* Fabric Technical Data Section */}
            {hasRollData && !(config as any).track_only && !(config as any).dealer_supply_fabric && (
              <div className="pb-5 border-b border-gray-200">
                <h3 className="text-sm font-semibold text-gray-700 mb-3">Roll (Fabric) – technical data</h3>
                <div className="grid grid-cols-2 gap-x-8 gap-y-0 text-sm">
                  {rollData.collection_name && (
                    <div className="py-1.5">
                      <span className="font-medium text-gray-700">Collection:</span>
                      <span className="ml-2 text-gray-900">{rollData.collection_name}</span>
                    </div>
                  )}
                  {rollData.variant_name && (
                    <div className="py-1.5">
                      <span className="font-medium text-gray-700">Variant:</span>
                      <span className="ml-2 text-gray-900">{rollData.variant_name}</span>
                    </div>
                  )}
                  {rollData.sku && (
                    <div className="py-1.5">
                      <span className="font-medium text-gray-700">SKU:</span>
                      <span className="ml-2 text-gray-900">{rollData.sku}</span>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Dimensions card */}
            {(() => {
              const pt = (config as any).productType || (config as any).product_type || '';
              const isShadeProduct = ['roller-shade', 'dual-shade', 'triple-shade', 'drapery', 'awning'].includes(pt);
              return (
              <div className="border border-gray-200 rounded-lg px-4 py-3 space-y-2.5">
                <div className="flex items-start justify-between gap-6">
                  <div>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Panels (mm)</span>
                    <div className="mt-1 text-gray-900 text-sm">
                      <DimensionsStackView source={dimensionsSource} />
                    </div>
                  </div>
                  {hasTotalDimensions && (
                    <div className="text-right">
                      <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Total</span>
                      <div className="mt-1 text-sm tabular-nums text-gray-900">
                        {Math.round(widthTotalMm)} × {Math.round(heightMm)} mm
                      </div>
                    </div>
                  )}
                </div>
                {isShadeProduct && rollWidthMm != null && hasRollData && (() => {
                  const fc = snapshotTotals?.fabric_calc;
                  const autoRotated = fc?.is_rotated === true;
                  const hsSeams = fc?.heatseal_seams ?? 0;
                  const bbWrapped = fc?.bottom_bar_wrapped === true;
                  return (
                  <div className="border-t border-gray-100 pt-2.5 space-y-1.5 text-sm">
                    <div className="flex items-center justify-between gap-6">
                      <div>
                        <span className="text-gray-500">Roll width:</span>{' '}
                        <span className="tabular-nums text-gray-700 font-medium">{Math.round(rollWidthMm)} mm</span>
                      </div>
                      <div>
                        <span className="text-gray-500">Fabric rotation:</span>{' '}
                        <span className={`font-medium ${autoRotated ? 'text-amber-700' : 'text-gray-700'}`}>
                          {autoRotated ? 'Yes (auto)' : 'No'}
                        </span>
                      </div>
                    </div>
                    {autoRotated && hsSeams > 0 && (
                      <div className="flex items-center justify-between gap-6 bg-amber-50 rounded px-2 py-1">
                        <div>
                          <span className="text-amber-700 font-medium">Heat Seal:</span>{' '}
                          <span className="text-amber-800">{hsSeams} {hsSeams === 1 ? 'seam' : 'seams'}</span>
                        </div>
                        <div className="text-[11px] text-amber-700 italic">charged via Labor</div>
                      </div>
                    )}
                    {bbWrapped && (
                      <div className="flex items-center justify-between gap-6 bg-blue-50 rounded px-2 py-1">
                        <div>
                          <span className="text-blue-700 font-medium">Bottom Bar Wrapped (Forrado)</span>
                        </div>
                        <div className="text-[11px] text-blue-700 italic">charged via Labor</div>
                      </div>
                    )}
                  </div>
                  );
                })()}
              </div>
              );
            })()}

            {/* Product Specifications — product-type-aware */}
            {(() => {
              const pt = (config as any).productType || (config as any).product_type || '';
              const isWindowFilm = pt === 'window-film';
              const isDrapery = pt === 'drapery';
              const isRoller = pt === 'roller-shade';
              const isDual = pt === 'dual-shade';
              const isTriple = pt === 'triple-shade';
              const isShade = isRoller || isDual || isTriple;
              const isShadeOrDrapery = isShade || isDrapery;
              const specRow = 'py-1.5';

              const fc = snapshotTotals?.fabric_calc;
              const consumptionQty = fc?.consumption_qty ? Number(fc.consumption_qty) : null;
              const consumptionUom = fc?.consumption_uom ?? 'm';
              const drops = fc?.drops ? Number(fc.drops) : null;

              const titleCase = (v: string | null | undefined) => {
                if (!v) return null;
                return String(v).replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
              };

              const snapItems: any[] = bomPreviewSnapshot?.items ?? [];
              const selectedItemForRole = (role: string) =>
                snapItems.find((i: any) => i.kind === 'parent' && i.role === role && i.selected === true) ?? null;

              const componentRow = (label: string, itemId: string | null | undefined, role: string) => {
                const snapItem = selectedItemForRole(role);
                const configHasItem = typeof itemId === 'string' && itemId.trim().length > 10;
                const hasItem = configHasItem || snapItem !== null;
                const displayName = hasItem ? (snapItem?.name ?? 'Included') : 'Not included';
                return (
                  <div key={role} className={specRow}>
                    <span className="font-medium text-gray-700">{label}:</span>
                    <span className={`ml-2 ${hasItem ? 'text-gray-900' : 'text-gray-400'}`}>{displayName}</span>
                  </div>
                );
              };

              const installDisplay = (() => {
                const type = (config as any).installationType ?? (config as any).installation_type;
                const location = (config as any).installationLocation ?? (config as any).installation_location;
                const parts = [
                  type ? String(type).charAt(0).toUpperCase() + String(type).slice(1).toLowerCase() : null,
                  location ? String(location).charAt(0).toUpperCase() + String(location).slice(1).toLowerCase() : null,
                ].filter(Boolean);
                return parts.length ? parts.join(' / ') : 'Not selected';
              })();

              return (
            <div>
              <h3 className="text-sm font-semibold text-gray-700 mb-3">PRODUCT SPECIFICATIONS</h3>
              <div className="grid grid-cols-2 gap-x-8 gap-y-0 text-sm">
                {/* ── Common fields ── */}
                <div className={specRow}>
                  <span className="font-medium text-gray-700">Product Type:</span>
                  <span className="ml-2 text-gray-900">{titleCase(pt) || 'Not selected'}</span>
                </div>
                <div className={specRow}>
                  <span className="font-medium text-gray-700">Quantity:</span>
                  <span className="ml-2 text-gray-900">{lineQuantity}</span>
                </div>
                <div className={specRow}>
                  <span className="font-medium text-gray-700">Installation:</span>
                  <span className="ml-2 text-gray-900">{installDisplay}</span>
                </div>
                <div className={specRow}>
                  <span className="font-medium text-gray-700">Position:</span>
                  <span className="ml-2 text-gray-900">{config.position ?? 'Not selected'}</span>
                </div>

                {/* ── Window Film only ── */}
                {isWindowFilm && (() => {
                  const c = config as any;
                  const sellMode = c.sell_mode || 'roll';
                  const filmCollection = c.film_collection || '';
                  const filmVariant = c.film_variant || '';
                  const filmModel = filmCollection && filmVariant ? `${filmCollection} ${filmVariant}` : (c.film_model || c.name || 'Not selected');
                  const rollWidthIn = c.roll_width_inches || c.film_width || 0;
                  const rollWidthM = c.roll_width_m || 0;
                  const rawLinearLen = Number(c.linear_length_m) || 0;
                  // Backward compatibility: old snapshots may store mm instead of m.
                  const linearLen = rawLinearLen > 100 ? rawLinearLen / 1000 : rawLinearLen;
                  const qty = c.qty || 1;
                  return (
                    <>
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Collection:</span>
                        <span className="ml-2 text-gray-900">{filmCollection || '—'}</span>
                      </div>
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Film:</span>
                        <span className="ml-2 text-gray-900">{filmModel}</span>
                      </div>
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">SKU:</span>
                        <span className="ml-2 text-gray-900">{c.sku || '—'}</span>
                      </div>
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Roll Width:</span>
                        <span className="ml-2 text-gray-900">{rollWidthIn}" ({rollWidthM.toFixed(2)}m)</span>
                      </div>
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Sell Mode:</span>
                        <span className="ml-2 text-gray-900">{sellMode === 'roll' ? 'Full Roll' : 'Linear Meter'}</span>
                      </div>
                      {sellMode === 'roll' ? (
                        <div className={specRow}>
                          <span className="font-medium text-gray-700">Quantity:</span>
                          <span className="ml-2 text-gray-900">{qty} roll{qty > 1 ? 's' : ''}</span>
                        </div>
                      ) : (
                        <>
                          <div className={specRow}>
                            <span className="font-medium text-gray-700">Quantity:</span>
                            <span className="ml-2 text-gray-900">{qty} piece{qty > 1 ? 's' : ''}</span>
                          </div>
                          <div className={specRow}>
                            <span className="font-medium text-gray-700">Length:</span>
                            <span className="ml-2 text-gray-900">{linearLen.toFixed(2)} m</span>
                          </div>
                        </>
                      )}
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Manufacturer:</span>
                        <span className="ml-2 text-gray-900">{c.manufacturer || '—'}</span>
                      </div>
                    </>
                  );
                })()}

                {/* ── Drapery-specific ── */}
                {isDrapery && (() => {
                  const c = config as any;
                  const productLine = c.product_line || c.productLine;
                  const styleCode = c.style_code || c.styleCode;
                  const systemSize = c.system_size || c.systemSize;
                  const openingDir = c.opening_direction || c.openingDirection;
                  const driveSide = c.drive_side || c.driveSide;
                  const trackJoin = c.force_track_join ?? c.forceTrackJoin;
                  const bottomHemCmRaw = c.bottom_hem_cm;
                  const bottomHemFromProfile = (() => {
                    const p = typeof c.bottom_hem_profile === 'string' ? c.bottom_hem_profile : '';
                    const m = p.match(/^hem_(\d+(?:\.\d+)?)$/);
                    return m ? Number(m[1]) : null;
                  })();
                  const bottomHemCm = bottomHemCmRaw != null
                    ? Number(bottomHemCmRaw)
                    : bottomHemFromProfile;
                  const bottomHemDisplay =
                    bottomHemCm == null || Number.isNaN(bottomHemCm)
                      ? 'Not selected'
                      : (bottomHemCm === 0 ? 'Serged (0 cm)' : `${bottomHemCm} cm`);
                  return (
                  <>
                    {productLine && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Product Line:</span>
                        <span className="ml-2 text-gray-900">{titleCase(productLine)}</span>
                      </div>
                    )}
                    {styleCode && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Wave Size:</span>
                        <span className="ml-2 text-gray-900">{titleCase(styleCode)}</span>
                      </div>
                    )}
                    {systemSize && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">System Size:</span>
                        <span className="ml-2 text-gray-900">{systemSize}</span>
                      </div>
                    )}
                    <div className={specRow}>
                      <span className="font-medium text-gray-700">Bottom Hem:</span>
                      <span className="ml-2 text-gray-900">{bottomHemDisplay}</span>
                    </div>
                    {openingDir && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Opening Direction:</span>
                        <span className="ml-2 text-gray-900">{titleCase(openingDir)}</span>
                      </div>
                    )}
                    {driveSide && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Drive Side:</span>
                        <span className="ml-2 text-gray-900">{titleCase(driveSide)}</span>
                      </div>
                    )}
                    {trackJoin != null && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Track Split:</span>
                        <span className="ml-2 text-gray-900">
                          {String(trackJoin) === 'true' ? 'Yes (joined)' : 'No'}
                        </span>
                      </div>
                    )}
                  </>
                  );
                })()}

                {/* ── Shade-specific (roller/dual/triple) ── */}
                {isShade && (
                  <>
                    {(() => {
                      const openness = fc?.openness_factor_pct ? Number(fc.openness_factor_pct) : null;
                      return openness != null ? (
                        <div className={specRow}>
                          <span className="font-medium text-gray-700">Openness:</span>
                          <span className="ml-2 text-gray-900">{openness}%</span>
                        </div>
                      ) : null;
                    })()}
                    <div className={specRow}>
                      <span className="font-medium text-gray-700">Fabric Drop:</span>
                      <span className="ml-2 text-gray-900">
                        {titleCase((config as any).fabricDrop ?? (config as any).fabric_drop) || 'Not selected'}
                      </span>
                    </div>
                    {componentRow('Tube', (config as any).tube_item_id, 'tube')}
                    {componentRow('Bottom Bar', (config as any).bottom_bar_item_id, 'bottom_bar')}
                    {componentRow('Cassette', (config as any).headbox_item_id, 'headbox')}
                    {componentRow('Side Channel', (config as any).side_channel_item_id, 'side_channel')}
                    {componentRow('Bottom Channel', (config as any).bottom_channel_item_id, 'bottom_channel')}
                  </>
                )}

                {/* ── Shared: fabric consumption ── */}
                {isShadeOrDrapery && consumptionQty != null && consumptionQty > 0 && (
                  <div className={specRow}>
                    <span className="font-medium text-gray-700">Fabric Consumption:</span>
                    <span className="ml-2 text-gray-900">
                      {consumptionQty.toFixed(2)} {formatUom(consumptionUom)}
                      {drops != null && drops > 0 && ` (${drops} ${drops === 1 ? 'drop' : 'drops'})`}
                    </span>
                  </div>
                )}
                {isShadeOrDrapery && !consumptionQty && fabricRollInfo != null && (
                  <div className={specRow}>
                    <span className="font-medium text-gray-700">Total fabric:</span>
                    <span className="ml-2 text-gray-900">
                      {fabricRollInfo.qty.toFixed(2)} {formatUom(fabricRollInfo.uom)}
                    </span>
                  </div>
                )}

                {/* ── Shared: hardware color, drive type, accessories ── */}
                {isShadeOrDrapery && (
                  <>
                    {((config as any).hardware_color || (config as any).hardwareColor) && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Hardware Color:</span>
                        <span className="ml-2 text-gray-900">{(config as any).hardware_color || (config as any).hardwareColor}</span>
                      </div>
                    )}
                    {((config as any).drive_type || (config as any).operatingSystem) && (
                      <div className={specRow}>
                        <span className="font-medium text-gray-700">Drive Type:</span>
                        <span className="ml-2 text-gray-900">{titleCase((config as any).drive_type || (config as any).operatingSystem)}</span>
                      </div>
                    )}
                    <div className={specRow}>
                      <span className="font-medium text-gray-700">Accessories:</span>
                      <span className="ml-2 text-gray-900">{(config as any).accessories?.length || 0} items</span>
                    </div>
                  </>
                )}

                {/* ── Generic fallback ── */}
                {!isShadeOrDrapery && !isWindowFilm && (
                  <div className={specRow}>
                    <span className="font-medium text-gray-700">Accessories:</span>
                    <span className="ml-2 text-gray-900">{(config as any).accessories?.length || 0} items</span>
                  </div>
                )}

                {showRollWidthWarning && (
                  <div className="col-span-2 mt-3 p-4 bg-amber-50 border border-amber-200 rounded text-sm">
                    <p className="font-medium text-amber-800">
                      Rule: no panel can be wider than the roll ({Math.round(rollWidthMm!)} mm).
                    </p>
                    <p className="text-amber-700 mt-1">
                      Panel(s) exceeding: {panelsExceedingRoll.map((p: any) => `Panel ${p.index} (${p.width_mm} mm)`).join(', ')}.
                    </p>
                  </div>
                )}
              </div>
            </div>
              );
            })()}
          </div>
        </div>
        
        {/* PRODUCT MSRP BREAKDOWN (internal admin only) */}
        {canViewInternalBreakdown && (
        <div className="pt-5 border-t border-gray-200">
          <div 
            className="flex items-center justify-between cursor-pointer"
            onClick={() => setShowBreakdown(!showBreakdown)}
          >
            <div className="flex flex-col gap-1 min-w-0">
              <h3 className="text-sm font-semibold text-gray-700 flex items-center gap-2">
                PRODUCT MSRP BREAKDOWN
                {hasValidSnapshot && (
                  <span className="px-1.5 py-0.5 text-xs bg-green-100 text-green-700 rounded font-normal flex-shrink-0">
                    Snapshot
                  </span>
                )}
              </h3>
              {templateInfo?.code && (
                <span className="px-1.5 py-0.5 text-[10px] bg-gray-100 text-gray-500 rounded font-mono w-fit max-w-full truncate" title={templateInfo.code}>
                  {templateInfo.code}
                </span>
              )}
            </div>
            <button className="p-1 hover:bg-gray-100 rounded">
              {showBreakdown ? (
                <ChevronUp className="w-4 h-4 text-gray-500" />
              ) : (
                <ChevronDown className="w-4 h-4 text-gray-500" />
              )}
            </button>
          </div>
          
          {showBreakdown && (
            <div className="mt-4">
              {/* Multiple template candidates - can't show breakdown yet */}
              {hasMultipleCandidates ? (
                <div className="text-sm text-amber-600 bg-amber-50 p-3 rounded-lg">
                  Multiple BOM templates match your selection ({filteredTemplates?.length} candidates). 
                  Final breakdown will be calculated when you add to quote.
                </div>
              ) : !bomTemplateId ? (
                <div className="text-sm text-gray-500">
                  No BOM template resolved yet. Complete your selections to see breakdown.
                </div>
              ) : loadingBreakdown ? (
                <div className="text-sm text-gray-500">Loading component breakdown...</div>
              ) : breakdownLines.length > 0 ? (
                <div className="table-fit-wrapper">
                  <table className="table-fit min-w-full divide-y divide-gray-200 text-sm">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Component
                        </th>
                        <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          SKU
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Qty
                        </th>
                        <th className="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                          UOM
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Unit Price (MSRP)
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Total (MSRP)
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {breakdownLines.map((line, idx) => (
                        <React.Fragment key={idx}>
                        <tr 
                          className={
                            line.source === 'selected' 
                              ? 'bg-blue-50' 
                              : line.isChild 
                                ? 'bg-gray-50' 
                                : ''
                          }
                        >
                          <td className="px-3 py-2 whitespace-nowrap">
                            <div className={`flex items-center ${line.isChild ? 'pl-4' : ''}`}>
                              {line.isChild && (
                                <span className="text-gray-400 mr-1">└</span>
                              )}
                              <span className={`capitalize ${line.isChild ? 'text-gray-600 text-sm' : 'font-medium text-gray-900'}`}>
                                {line.role.replace(/_/g, ' ')}
                              </span>
                              {line.source === 'selected' && (
                                <span className="ml-2 px-1.5 py-0.5 text-xs bg-blue-100 text-blue-700 rounded">
                                  Selected
                                </span>
                              )}
                              {(line.meta as any)?.per_panel && !line.isChild && (
                                <span className="ml-2 px-1.5 py-0.5 text-xs bg-emerald-100 text-emerald-700 rounded">
                                  Per Panel{(line.meta as any)?.panel_count > 1 ? ` ×${(line.meta as any).panel_count}` : ''}
                                </span>
                              )}
                              {line.isChild && (
                                <span className="ml-2 px-1.5 py-0.5 text-xs bg-gray-200 text-gray-600 rounded">
                                  Child
                                </span>
                              )}
                            </div>
                            {line.name && line.name !== line.sku && (
                              <div className={`text-xs text-gray-500 ${line.isChild ? 'pl-6' : ''}`}>{line.name}</div>
                            )}
                          </td>
                          <td className={`px-3 py-2 whitespace-nowrap ${line.isChild ? 'text-gray-500' : 'text-gray-600'}`}>
                            {line.sku || '-'}
                          </td>
                          <td className={`px-3 py-2 whitespace-nowrap text-right ${line.isChild ? 'text-gray-600' : 'text-gray-900'}`}>
                            {Number(line.qty).toFixed(2)}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-center text-gray-500">
                            {formatUom(line.uom)}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-right text-gray-600">
                            <div>
                              {formatMoney(line.unitPrice)} / {formatUom(line.uom)}
                              {/* Roll: secondary equivalent price when roll_width_m available */}
                              {line.kind === 'roll' && (line.meta as any)?.roll_width_m != null && Number((line.meta as any).roll_width_m) > 0 && (() => {
                                const rw = Number((line.meta as any).roll_width_m);
                                const uomNorm = String(line.uom || '').toLowerCase().replace('²', '2');
                                if (uomNorm === 'm' || line.uom === 'm') {
                                  const perM2 = line.unitPrice / rw;
                                  return <div className="text-xs text-gray-500 mt-0.5">≈ {formatMoney(perM2)} / m²</div>;
                                }
                                if (uomNorm === 'm2' || line.uom === 'm²') {
                                  const perM = line.unitPrice * rw;
                                  return <div className="text-xs text-gray-500 mt-0.5">≈ {formatMoney(perM)} / m</div>;
                                }
                                return null;
                              })()}
                            </div>
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-right font-medium text-gray-900">
                            {formatMoney(line.totalPrice)}
                          </td>
                        </tr>
                        {!line.isChild && (line.meta as any)?.panel_cuts && Array.isArray((line.meta as any).panel_cuts) && (line.meta as any).panel_cuts.length > 1 && (
                          <tr key={`${idx}-pc`} className="bg-emerald-50/30">
                            <td colSpan={6} className="px-3 py-1 pl-7">
                              <div className="text-[11px] text-gray-500">
                                <span className="font-medium text-gray-600">Panel cuts: </span>
                                {((line.meta as any).panel_cuts as any[]).map((pc: any, pi: number) => (
                                  <span key={pi}>
                                    {pi > 0 && ' · '}
                                    P{pc.index}: {Math.round(pc.tube_width_mm ?? pc.bottom_bar_width_mm ?? 0)} mm
                                    {pc.position && <span className="text-gray-400"> ({pc.position})</span>}
                                  </span>
                                ))}
                              </div>
                            </td>
                          </tr>
                        )}
                        {line.kind === 'roll' && (() => {
                          const fc = snapshotTotals?.fabric_calc;
                          if (!fc || fc.source === 'none' || fc.source === 'legacy') return null;
                          const hsSeams = fc.heatseal_seams ?? 0;
                          const bbWrapped = fc.bottom_bar_wrapped === true;
                          return (
                            <tr key={`${idx}-fc`} className="bg-blue-50/30">
                              <td colSpan={6} className="px-3 py-1.5 pl-7">
                                <div className="text-[11px] text-gray-500 space-y-0.5">
                                  <div>
                                    <span className="font-medium text-gray-600">Consumption: </span>
                                    Width: {Math.round(fc.fabric_cut_width_mm ?? 0)} mm
                                    ({fc.fabric_width_source?.replace(/_/g, ' ') ?? 'n/a'})
                                    {' · '}Height: {Math.round(fc.fabric_cut_height_mm ?? 0)} mm
                                    {fc.waste_pct != null && <>{' · '}Waste: {(Number(fc.waste_pct) * 100).toFixed(0)}%</>}
                                    {' · '}Qty: {Number(fc.consumption_qty ?? 0).toFixed(3)} {fc.consumption_uom ?? ''}
                                    {fc.is_rotated === true && <span className="ml-1 text-amber-600 font-medium">[ROTATED]</span>}
                                  </div>
                                  {hsSeams > 0 && (
                                    <div className="text-amber-600">
                                      Heat Seal: {hsSeams} {hsSeams === 1 ? 'seam' : 'seams'} <span className="italic text-amber-500">(charged via Labor)</span>
                                    </div>
                                  )}
                                  {bbWrapped && (
                                    <div className="text-blue-600">
                                      Bottom Bar Wrap <span className="italic text-blue-500">(charged via Labor)</span>
                                    </div>
                                  )}
                                </div>
                              </td>
                            </tr>
                          );
                        })()}
                        </React.Fragment>
                      ))}
                      {/* Accessories are NOT part of ConfiguredProduct breakdown; they are separate QuoteLines. */}
                      {/* Labor as breakdown row when we have a labor amount (from snapshot or derived) */}
                      {(effectiveLaborMsrpAmount || 0) > 0 && (
                        <tr className="bg-gray-50 border-t border-gray-200">
                          <td className="px-3 py-2 whitespace-nowrap">
                            <span className="font-medium text-gray-900">
                              Labor MSRP ({effectiveTotals.labor_pct ?? 0}%)
                            </span>
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-gray-500">—</td>
                          <td className="px-3 py-2 whitespace-nowrap text-right text-gray-600">1</td>
                          <td className="px-3 py-2 whitespace-nowrap text-center text-gray-500">—</td>
                          <td className="px-3 py-2 whitespace-nowrap text-right text-gray-600">
                            ${effectiveLaborMsrpAmount.toFixed(2)}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-right font-medium text-gray-900">
                            ${effectiveLaborMsrpAmount.toFixed(2)}
                          </td>
                        </tr>
                      )}
                      {/* Labor COST breakdown (verification): how the labor cost was composed from the matched LaborRule */}
                      {laborCostBreakdown && laborCostBreakdown.lines.length > 0 && (
                        <tr className="bg-amber-50/40">
                          <td colSpan={6} className="px-3 py-2 pl-7">
                            <div className="text-[11px] text-gray-600 space-y-1">
                              <div className="font-semibold text-gray-700">
                                Labor cost breakdown — verification
                                {laborCostBreakdown.ruleName && (
                                  <span className="ml-1 font-normal text-gray-500">
                                    (rule: {laborCostBreakdown.ruleName}
                                    {laborCostBreakdown.calcMode ? ` · ${laborCostBreakdown.calcMode}` : ''})
                                  </span>
                                )}
                              </div>
                              <div className="text-[10px] text-gray-400 italic">
                                Cost figures (pre-MSRP). These compose the labor cost; the Labor MSRP above is this cost marked up.
                              </div>
                              {laborCostBreakdown.lines.map((l, li) => (
                                <div key={li} className="flex items-baseline justify-between gap-4">
                                  <span className="text-gray-600">
                                    <span className="font-medium text-gray-700">{l.label}</span>
                                    <span className="ml-2 text-gray-400">{l.description}</span>
                                  </span>
                                  <span className="tabular-nums text-gray-700 shrink-0">{formatMoney(l.contribution)}</span>
                                </div>
                              ))}
                              {Math.abs(laborCostBreakdown.rounding) > 0.005 && (
                                <div className="flex items-baseline justify-between gap-4">
                                  <span className="text-gray-500">Rounding / min-max adjustment</span>
                                  <span className="tabular-nums text-gray-600 shrink-0">{formatMoney(laborCostBreakdown.rounding)}</span>
                                </div>
                              )}
                              <div className="flex items-baseline justify-between gap-4 border-t border-amber-200 pt-1 mt-1">
                                <span className="font-semibold text-gray-700">Total labor cost</span>
                                <span className="tabular-nums font-semibold text-gray-900 shrink-0">{formatMoney(laborCostBreakdown.authoritative)}</span>
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </tbody>
                    <tfoot className="border-t-2 border-gray-300">

                      {/* ── MSRP SUBTOTALS ──────────────────────────────── */}
                      <tr>
                        <td colSpan={6} className="px-3 pt-5 pb-1.5 text-right text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                          MSRP Subtotals (unit)
                        </td>
                      </tr>
                      {(effectiveTotals.roll_msrp_total || 0) > 0 && (
                        <tr>
                          <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                            Roll Product Subtotal MSRP
                          </td>
                          <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                            ${(effectiveTotals.roll_msrp_total || 0).toFixed(2)}
                          </td>
                        </tr>
                      )}
                      <tr>
                        <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                          BOM Product Subtotal MSRP
                        </td>
                        <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                          ${(effectiveTotals.bom_total || 0).toFixed(2)}
                        </td>
                      </tr>
                      {(effectiveLaborMsrpAmount || 0) > 0 && (
                        <tr>
                          <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                            Labor MSRP
                          </td>
                          <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                            ${effectiveLaborMsrpAmount.toFixed(2)}
                          </td>
                        </tr>
                      )}
                      <tr className="border-t border-gray-200">
                        <td colSpan={5} className="px-3 py-2.5 text-right text-sm font-bold text-gray-900">
                          Total MSRP (per unit)
                        </td>
                        <td className="px-3 py-2.5 text-right font-bold text-gray-900 tabular-nums">
                          ${(totalProductMsrpUnit || computedUnitMsrp || 0).toFixed(2)}
                        </td>
                      </tr>

                      {/* ── DEALER PRICING ──────────────────────────────── */}
                      <tr className="border-t-2 border-gray-300">
                        <td colSpan={6} className="px-3 pt-5 pb-1.5 text-right text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                          Dealer Pricing
                        </td>
                      </tr>
                      <tr>
                        <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                          Dealer Price (unit)
                        </td>
                        <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                          {computedUnitDealerPrice != null ? `$${Number(computedUnitDealerPrice).toFixed(2)}` : '—'}
                        </td>
                      </tr>
                      <tr>
                        <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                          MSRP Margin (on sale)
                        </td>
                        <td className="px-3 py-1.5 text-right text-gray-600 tabular-nums">
                          {(msrpMarginPct * 100).toFixed(0)}%
                        </td>
                      </tr>
                      <tr className="border-t border-gray-200">
                        <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                          Qty
                        </td>
                        <td className="px-3 py-1.5 text-right font-semibold text-gray-700 tabular-nums">
                          {lineQuantity}
                        </td>
                      </tr>
                      <tr>
                        <td colSpan={5} className="px-3 py-1.5 text-right text-sm font-bold text-gray-900">
                          Dealer Line Total
                        </td>
                        <td className="px-3 py-1.5 text-right font-bold text-gray-900 tabular-nums">
                          {dealerLineTotal != null ? `$${Number(dealerLineTotal).toFixed(2)}` : '—'}
                        </td>
                      </tr>
                      <tr>
                        <td colSpan={5} className="px-3 pb-4 text-right text-sm font-bold text-gray-900">
                          MSRP Line Total
                        </td>
                        <td className="px-3 pb-4 text-right font-bold text-gray-900 tabular-nums">
                          {msrpLineTotal != null ? `$${Number(msrpLineTotal).toFixed(2)}` : '—'}
                        </td>
                      </tr>

                      {/* ── COST BREAKDOWN ──────────────────────────────── */}
                      {(effectiveCosts.unit_product_cost || effectiveCosts.roll_cost || effectiveCosts.bom_cost || effectiveCosts.unit_labor_cost || (effectiveCosts.labor_pct ?? 0) > 0) ? (
                        <>
                          <tr className="border-t-2 border-gray-300">
                            <td colSpan={6} className="px-3 pt-5 pb-1.5 text-right text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                              Cost Breakdown (internal)
                            </td>
                          </tr>
                          {(effectiveCosts.roll_cost || 0) > 0 && (
                            <tr>
                              <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                                Roll Cost:
                              </td>
                              <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                                ${(effectiveCosts.roll_cost || 0).toFixed(2)}
                              </td>
                            </tr>
                          )}
                          {(effectiveCosts.bom_cost || 0) > 0 && (
                            <tr>
                              <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                                BOM Cost:
                              </td>
                              <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                                ${(effectiveCosts.bom_cost || 0).toFixed(2)}
                              </td>
                            </tr>
                          )}
                          {(effectiveCosts.accessories_cost || 0) > 0 && (
                            <tr>
                              <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                                Accessories Cost:
                              </td>
                              <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                                ${(effectiveCosts.accessories_cost || 0).toFixed(2)}
                              </td>
                            </tr>
                          )}
                          <tr className="border-t border-gray-200">
                            <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                              Materials Cost (Roll + BOM + Acc):
                            </td>
                            <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                              ${(effectiveCosts.unit_product_cost || 0).toFixed(2)}
                            </td>
                          </tr>
                          <tr>
                            <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                              Labor Cost ({(effectiveCosts.labor_pct ?? 0).toFixed(1)}% of materials):
                            </td>
                            <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                              ${(effectiveCosts.unit_labor_cost || 0).toFixed(2)}
                            </td>
                          </tr>
                          <tr className="border-t border-gray-200">
                            <td colSpan={5} className="px-3 py-2.5 text-right text-sm font-bold text-gray-900">
                              Total Cost:
                            </td>
                            <td className="px-3 py-2.5 text-right font-bold text-gray-900 tabular-nums">
                              ${(effectiveCosts.total_cost || 0).toFixed(2)}
                            </td>
                          </tr>

                          {/* ── PROFIT ──────────────────────────────────── */}
                          <tr className="border-t-2 border-gray-300">
                            <td colSpan={6} className="px-3 pt-5 pb-1.5 text-right text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                              Profit (unit)
                            </td>
                          </tr>
                          <tr>
                            <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                              Dealer Price:
                            </td>
                            <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                              {computedUnitDealerPrice != null ? `$${Number(computedUnitDealerPrice).toFixed(2)}` : '—'}
                            </td>
                          </tr>
                          <tr>
                            <td colSpan={5} className="px-3 py-1.5 text-right text-sm text-gray-500">
                              Gross Profit:
                            </td>
                            <td className="px-3 py-1.5 text-right text-gray-700 tabular-nums">
                              {computedUnitDealerPrice != null ? `$${(Number(computedUnitDealerPrice) - Number(effectiveCosts.total_cost || 0)).toFixed(2)}` : '—'}
                            </td>
                          </tr>
                          <tr>
                            <td colSpan={5} className="px-3 pb-5 text-right text-sm text-gray-500">
                              Gross Margin (Dealer):
                            </td>
                            <td className="px-3 pb-5 text-right text-gray-700 tabular-nums">
                              {computedUnitDealerPrice != null && Number(computedUnitDealerPrice) > 0
                                ? `${(((Number(computedUnitDealerPrice) - Number(effectiveCosts.total_cost || 0)) / Number(computedUnitDealerPrice)) * 100).toFixed(1)}%`
                                : '—'}
                            </td>
                          </tr>
                        </>
                      ) : null}
                    </tfoot>
                  </table>
                </div>
              ) : (
                <div className="text-sm text-gray-500">
                  No component breakdown available for this template.
                </div>
              )}
            </div>
          )}
        </div>
        )}
      </div>
    </div>
  );
}
