/**
 * getConfigFromQuoteLine — REWRITE FROM SCRATCH
 *
 * 1. Load QuoteLine
 * 2. Build base config from QuoteLine columns (productType, dimensions, etc.)
 * 3. If QuoteLine has configured_product_id → load CP → spread config_snapshot OVER config
 *    (snapshot wins for hardware selections). Cost keys are NEVER spread from config_snapshot;
 *    they come only from CP columns and bom_preview_snapshot.
 * 4. Return config
 *
 * config_snapshot: source of truth for SELECTIONS (SKUs, IDs, measurements). NO cost keys.
 * CP columns + bom_preview_snapshot.totals: source of truth for pricing/costs (display only).
 */

import type { SupabaseClient } from '@supabase/supabase-js';
import { CONFIG_SNAPSHOT_SKIP_ON_SPREAD } from '../config-snapshot-schema';
import type { ProductConfig } from '../../pages/sales/product-config/types';

const PT_MAP: Record<string, string> = {
  ROLLER: 'roller-shade',
  DUAL: 'dual-shade',
  TRIPLE: 'triple-shade',
  DRAPERY: 'drapery',
  AWNING: 'awning',
  FILM: 'window-film',
  CATALOG: 'catalog',
};

export interface GetConfigFromQuoteLineParams {
  supabase: SupabaseClient;
  organizationId: string;
  lineId: string;
  forEdit?: boolean;
}

export async function getConfigFromQuoteLine(
  params: GetConfigFromQuoteLineParams
): Promise<ProductConfig | null> {
  const { supabase, organizationId, lineId, forEdit = true } = params;

  // ── 1. Load QuoteLine ──────────────────────────────────────────────
  const { data: line, error } = await supabase
    .from('QuoteLines')
    .select('*')
    .eq('id', lineId)
    .eq('organization_id', organizationId)
    .maybeSingle();

  if (error || !line) {
    console.warn('[getConfigFromQuoteLine] QuoteLine not found', { lineId, error: error?.message });
    return null;
  }

  // ── 2. Resolve ProductType ─────────────────────────────────────────
  let productTypeId = line.product_type_id;
  if (!productTypeId && line.product_type) {
    const { data } = await supabase
      .from('ProductTypes')
      .select('id, code')
      .or(`organization_id.eq.${organizationId},organization_id.is.null`)
      .ilike('code', line.product_type)
      .maybeSingle();
    if (data) productTypeId = data.id;
  }
  const ptCode = line.product_type?.toUpperCase() || 'ROLLER';
  const productTypeUI = PT_MAP[ptCode] || 'roller-shade';

  // ── 3. Resolve CatalogItem (fabric) ────────────────────────────────
  let catalogItem: any = null;
  if (line.catalog_item_id) {
    const { data } = await supabase
      .from('CatalogItems')
      .select('id, collection_name, variant_name, sku, name, item_name')
      .eq('id', line.catalog_item_id)
      .eq('organization_id', organizationId)
      .eq('is_active', true)
      .maybeSingle();
    catalogItem = data;
  }

  // ── 4. Load accessories ────────────────────────────────────────────
  const accRes = await supabase
    .from('QuoteLineComponents')
    .select('catalog_item_id, qty, unit_cost_exw')
    .eq('quote_line_id', lineId)
    .eq('deleted', false)
    .eq('organization_id', organizationId)
    .or('source.eq.accessory,component_role.eq.accessory');
  const accRows = accRes.error ? [] : (accRes.data || []);
  const accItemIds = accRows.map((a: any) => a.catalog_item_id).filter(Boolean);
  const accItemMap = new Map<string, any>();
  if (accItemIds.length > 0) {
    const { data: items } = await supabase
      .from('CatalogItems')
      .select('id, item_name, sku, name')
      .in('id', accItemIds)
      .eq('organization_id', organizationId)
      .eq('is_active', true);
    (items || []).forEach((i: any) => accItemMap.set(i.id, i));
  }
  const accessories = accRows.map((a: any) => {
    const ci = accItemMap.get(a.catalog_item_id);
    return {
      id: a.catalog_item_id,
      name: ci?.item_name || ci?.name || ci?.sku || 'Unknown',
      qty: a.qty || 1,
      price: a.unit_cost_exw || 0,
    };
  });

  // ── 5. Build base config from QuoteLine columns ────────────────────
  const width_mm = line.width_m ? line.width_m * 1000 : undefined;
  const height_mm = line.height_m ? line.height_m * 1000 : undefined;

  const config: any = {
    productType: productTypeUI,
    productTypeId: productTypeId || undefined,
    area: line.area || undefined,
    position: line.position || '',
    quantity: line.qty || 1,
    width_mm,
    height_mm,
    width_m: line.width_m || undefined,
    height_m: line.height_m || undefined,
    variantId: line.catalog_item_id,
    catalogItemId: line.catalog_item_id,
    fabric_catalog_item_id: line.catalog_item_id,
    collectionName: catalogItem?.collection_name || line.collection_name || undefined,
    variantName: catalogItem?.variant_name || line.variant_name || undefined,
    operatingSystem: line.drive_type === 'motor' ? 'motorized' : 'manual',
    operation_type: line.drive_type || 'motor',
    drive_type: line.drive_type || 'motor',
    bom_template_id: line.bom_template_id || undefined,
    bottom_rail_type: line.bottom_rail_type || 'standard',
    cassette: line.cassette || false,
    cassette_type: line.cassette_type || undefined,
    side_channel: line.side_channel || false,
    side_channel_type: line.side_channel ? (line.side_channel_type || 'side_only') : undefined,
    hardware_color: line.hardware_color || undefined,
    hardwareColor: line.hardware_color || undefined,
    fabric_rotation: line.metadata?.fabric_rotation || false,
    fabric_heatseal: line.metadata?.fabric_heatseal || false,
    fabricDrop: normalizeEnum(line.fabric_drop, ['normal', 'inverted']),
    installationType: normalizeEnum(line.installation_type, ['inside', 'outside']),
    installationLocation: normalizeEnum(line.installation_location, ['ceiling', 'wall']),
    accessories,
  };

  if (productTypeUI === 'dual-shade') {
    config.frontFabric = { variantId: line.catalog_item_id };
  }

  if (productTypeUI === 'catalog') {
    config.catalog_item_id = line.catalog_item_id;
    config.name = line.name || '';
    config.sku = line.sku || '';
    config.unit_price = Number(line.unit_msrp) || 0;
    config.qty = line.quantity || 1;
  }

  if (forEdit) {
    config.quote_line_id = lineId;
  }

  // ── 6. Load ConfiguredProduct and SPREAD config_snapshot ───────────
  const cpId = line.configured_product_id;
  let snapshotApplied = false;

  if (cpId) {
    // HARD LOCK: Cost columns ONLY roll_total_cost, bom_total_cost, accessories_total_cost, unit_product_cost, total_cost (no _landed)
    const { data: cp, error: cpErr } = await supabase
      .from('ConfiguredProducts')
      .select(`
        id,
        config_snapshot,
        hardware_color,
        bom_preview_snapshot,
        roll_msrp_total,
        bom_total,
        accessories_total,
        labor_amount,
        labor_pct,
        unit_msrp_total,
        msrp_product_subtotal,
        roll_total_cost,
        bom_total_cost,
        accessories_total_cost,
        unit_product_cost,
        unit_labor_cost,
        total_cost
      `)
      .eq('id', cpId)
      .maybeSingle();

    if (cpErr) {
      console.warn('[getConfigFromQuoteLine] CP query error', { cpId, error: cpErr.message });
    }

    if (cp) {
      const snapshot = cp.config_snapshot;

      if (snapshot && typeof snapshot === 'object' && Object.keys(snapshot).length > 0) {
        const snap = snapshot as Record<string, any>;
        snapshotApplied = true;

        // ── Spread snapshot keys into config (snapshot wins for SELECTIONS only) ──
        // Skip cost/pricing keys: those come from CP columns and bom_preview_snapshot.totals.
        for (const [key, value] of Object.entries(snap)) {
          if (CONFIG_SNAPSHOT_SKIP_ON_SPREAD.has(key)) continue;
          if (value === undefined || value === null) continue;
          // Snapshot value wins (overwrite base config); never overwrite with null
          config[key] = value;
        }

        // ── Copia defensiva: claves críticas desde snapshot (snake + camel) si faltan ──
        const setFromSnap = (cfgKey: string, ...snapKeys: string[]) => {
          if (config[cfgKey] != null && config[cfgKey] !== '') return;
          const v = snapKeys.map(k => snap[k]).find(v => v != null && v !== '');
          if (v != null) config[cfgKey] = typeof v === 'string' ? v.trim() : v;
        };
        setFromSnap('bottom_bar_sku', 'bottom_bar_sku', 'bottomBarSku');
        setFromSnap('bottom_bar_item_id', 'bottom_bar_item_id', 'bottomBarItemId', 'bottomBarItemID');
        setFromSnap('hardware_color', 'hardware_color', 'hardwareColor');
        setFromSnap('hardwareColor', 'hardware_color', 'hardwareColor');
        setFromSnap('headbox_sku', 'headbox_sku', 'headboxSku');
        setFromSnap('headbox_item_id', 'headbox_item_id', 'headboxItemId');
        setFromSnap('side_channel_sku', 'side_channel_sku', 'sideChannelSku');
        setFromSnap('side_channel_item_id', 'side_channel_item_id', 'sideChannelItemId');
        setFromSnap('bottom_channel_sku', 'bottom_channel_sku', 'bottomChannelSku');
        setFromSnap('bottom_channel_item_id', 'bottom_channel_item_id', 'bottomChannelItemId');
        setFromSnap('tube_sku', 'tube_sku', 'tubeSku');
        setFromSnap('tube_item_id', 'tube_item_id', 'tubeItemId');
        setFromSnap('drive_sku', 'drive_sku', 'driveSku');
        setFromSnap('drive_item_id', 'drive_item_id', 'driveItemId');
        setFromSnap('gear_ratio', 'gear_ratio');
        setFromSnap('motor_sku', 'motor_sku', 'motorSku');
        setFromSnap('motor_item_id', 'motor_item_id', 'motorItemId');
        setFromSnap('operation_type', 'operation_type', 'operating_type');
        setFromSnap('drive_type', 'drive_type');

        // ── Normalize camelCase → snake_case aliases ──
        // So HardwareStep always finds snake_case keys
        if (config.bottomBarItemId && !config.bottom_bar_item_id) config.bottom_bar_item_id = config.bottomBarItemId;
        if (config.bottomBarSku && !config.bottom_bar_sku) config.bottom_bar_sku = config.bottomBarSku;
        if (config.headboxItemId && !config.headbox_item_id) config.headbox_item_id = config.headboxItemId;
        if (config.headboxSku && !config.headbox_sku) config.headbox_sku = config.headboxSku;
        if (config.sideChannelItemId && !config.side_channel_item_id) config.side_channel_item_id = config.sideChannelItemId;
        if (config.sideChannelSku && !config.side_channel_sku) config.side_channel_sku = config.sideChannelSku;
        if (config.bottomChannelItemId && !config.bottom_channel_item_id) config.bottom_channel_item_id = config.bottomChannelItemId;
        if (config.bottomChannelSku && !config.bottom_channel_sku) config.bottom_channel_sku = config.bottomChannelSku;
        if (config.tubeItemId && !config.tube_item_id) config.tube_item_id = config.tubeItemId;
        if (config.tubeSku && !config.tube_sku) config.tube_sku = config.tubeSku;
        if (config.driveItemId && !config.drive_item_id) config.drive_item_id = config.driveItemId;
        if (config.driveSku && !config.drive_sku) config.drive_sku = config.driveSku;
        if (config.motorItemId && !config.motor_item_id) config.motor_item_id = config.motorItemId;
        if (config.motorSku && !config.motor_sku) config.motor_sku = config.motorSku;
        if (config.hardwareColor && !config.hardware_color) config.hardware_color = config.hardwareColor;
        if (config.hardware_color && !config.hardwareColor) config.hardwareColor = config.hardware_color;

        // ── Drapery-specific: ensure camelCase aliases exist ──
        if (config.product_line && !config.productLine) config.productLine = config.product_line;
        if (config.productLine && !config.product_line) config.product_line = config.productLine;
        if (config.style_code && !config.styleCode) config.styleCode = config.style_code;
        if (config.styleCode && !config.style_code) config.style_code = config.styleCode;
        if (config.system_size && !config.systemSize) config.systemSize = config.system_size;
        if (config.systemSize && !config.system_size) config.system_size = config.systemSize;
        if (config.opening_direction && !config.openingDirection) config.openingDirection = config.opening_direction;
        if (config.openingDirection && !config.opening_direction) config.opening_direction = config.openingDirection;
        if (config.drive_side && !config.driveSide) config.driveSide = config.drive_side;
        if (config.driveSide && !config.drive_side) config.drive_side = config.driveSide;

        // Bottom hem override from config_snapshot
        if (snap.bottom_hem_cm != null && config.bottom_hem_cm == null)
          config.bottom_hem_cm = snap.bottom_hem_cm;
        if (snap.bottom_hem_profile && !config.bottom_hem_profile)
          config.bottom_hem_profile = snap.bottom_hem_profile;

        // ── Normalize hardware_color to capitalized (White/Black/Silver) ──
        const hc = config.hardware_color;
        if (typeof hc === 'string' && hc.trim()) {
          const lower = hc.trim().toLowerCase();
          const cap = lower.charAt(0).toUpperCase() + lower.slice(1);
          config.hardware_color = cap;
          config.hardwareColor = cap;
        }

        // ── MeasurementsStep enums ──
        const fd = config.fabricDrop ?? config.fabric_drop;
        if (fd) config.fabricDrop = normalizeEnum(fd, ['normal', 'inverted']) ?? config.fabricDrop;
        const it = config.installationType ?? config.installation_type;
        if (it) config.installationType = normalizeEnum(it, ['inside', 'outside']) ?? config.installationType;
        const il = config.installationLocation ?? config.installation_location;
        if (il) config.installationLocation = normalizeEnum(il, ['ceiling', 'wall']) ?? config.installationLocation;

        // ── Derive width from measurements if available ──
        const m = config.measurements;
        if (m?.width_total_mm) config.width_mm = m.width_total_mm;
        if (m?.height_mm) config.height_mm = m.height_mm;

        // ── Restore top-level panels from measurements.panels if missing ──
        // MeasurementsStep reads config.panels first; without this, multi-panel configs
        // show as 1 panel with the total width instead of individual panel widths.
        if (!Array.isArray(config.panels) && Array.isArray(m?.panels) && m.panels.length > 0) {
          config.panels = m.panels.map((p: any) => ({
            width_mm: p?.width_mm || 0,
            index: p?.index,
          }));
        }

        // ── Default optional hardware selections to 'NONE' when editing ──
        // If bottom_bar is set (hardware section was visible) but headbox/side/bottom
        // are still null/undefined, the user chose "Not Included" (or the snapshot
        // predates the 'NONE' persistence fix). Default to 'NONE' so the button
        // shows as selected on Edit/Duplicate.
        if (config.bottom_bar_item_id) {
          if (config.headbox_item_id == null) config.headbox_item_id = 'NONE';
          if (config.side_channel_item_id == null) config.side_channel_item_id = 'NONE';
          if (config.bottom_channel_item_id == null) config.bottom_channel_item_id = 'NONE';
        }

        // ── Accessories: prefer QuoteLineComponents, fallback to snapshot ──
        if (accessories.length > 0) {
          config.accessories = accessories;
        } else if (Array.isArray(snap.accessories) && snap.accessories.length > 0) {
          config.accessories = snap.accessories;
        }
      }

      // ── Catalog item: map unit_msrp → unit_price for CatalogItemStep ──
      if (productTypeUI === 'catalog') {
        if (config.unit_price == null || config.unit_price === 0) {
          config.unit_price = Number(config.unit_msrp) || 0;
        }
      }

      // ── CP totals and snapshot for ReviewStep (Breakdown vs QuoteLine must match) ──
      if ((cp as any).bom_preview_snapshot) config.bom_preview_snapshot = (cp as any).bom_preview_snapshot;
      if ((cp as any).roll_msrp_total != null) config.roll_msrp_total = (cp as any).roll_msrp_total;
      if ((cp as any).bom_total != null) config.bom_total = (cp as any).bom_total;
      if ((cp as any).labor_amount != null) config.labor_amount = (cp as any).labor_amount;
      if ((cp as any).labor_pct != null) config.labor_pct = (cp as any).labor_pct;
      if ((cp as any).unit_msrp_total != null) config.unit_msrp_total = (cp as any).unit_msrp_total;
      if ((cp as any).msrp_product_subtotal != null) config.msrp_product_subtotal = (cp as any).msrp_product_subtotal;
      if ((cp as any).roll_total_cost != null) config.roll_total_cost = (cp as any).roll_total_cost;
      if ((cp as any).bom_total_cost != null) config.bom_total_cost = (cp as any).bom_total_cost;
      if ((cp as any).accessories_total_cost != null) config.accessories_total_cost = (cp as any).accessories_total_cost;
      if ((cp as any).unit_product_cost != null) config.unit_product_cost = (cp as any).unit_product_cost;
      if ((cp as any).unit_labor_cost != null) config.unit_labor_cost = (cp as any).unit_labor_cost;
      if ((cp as any).total_cost != null) config.total_cost = (cp as any).total_cost;

      // Fallback: CP column hardware_color
      if (!config.hardware_color && cp.hardware_color) {
        const lower = String(cp.hardware_color).trim().toLowerCase();
        const cap = lower.charAt(0).toUpperCase() + lower.slice(1);
        config.hardware_color = cap;
        config.hardwareColor = cap;
      }
    } else {
      console.warn('[getConfigFromQuoteLine] CP not found', { cpId });
    }
  }

  // ── 6b. Recover drapery fields from BOM template when snapshot is incomplete ──
  const isDrapery = config.productType === 'drapery';
  const bomTemplateId = config.bom_template_id || line.bom_template_id;
  const needsDraperyRecovery = isDrapery && bomTemplateId && (
    (!config.productLine && !config.product_line) ||
    (!config.systemSize && !config.system_size) ||
    (!config.openingDirection && !config.opening_direction) ||
    (!config.driveSide && !config.drive_side) ||
    !config.manufacturer
  );
  if (needsDraperyRecovery) {
    const { data: bt } = await supabase
      .from('BOMTemplates')
      .select('product_line, system_size, manufacturer, opening_direction, drive_side, hardware_color')
      .eq('id', bomTemplateId)
      .maybeSingle();
    if (bt) {
      if (bt.product_line && !config.productLine && !config.product_line) {
        config.product_line = bt.product_line;
        config.productLine = bt.product_line;
      }
      if (bt.system_size && !config.systemSize && !config.system_size) {
        config.system_size = bt.system_size;
        config.systemSize = bt.system_size;
      }
      if (bt.manufacturer && !config.manufacturer) {
        config.manufacturer = bt.manufacturer;
      }
      if (bt.opening_direction && !config.openingDirection && !config.opening_direction) {
        config.opening_direction = bt.opening_direction;
        config.openingDirection = bt.opening_direction;
      }
      if (bt.drive_side && !config.driveSide && !config.drive_side) {
        config.drive_side = bt.drive_side;
        config.driveSide = bt.drive_side;
      }
      if (bt.hardware_color && !config.hardwareColor && !config.hardware_color) {
        config.hardware_color = bt.hardware_color;
        config.hardwareColor = bt.hardware_color;
      }
    }
  }

  // ── 7. Quote line dealer pricing and labor snapshots for ReviewStep (when editing) ──
  if (forEdit && line) {
    if (line.dealer_discount_pct != null) config.dealer_discount_pct = line.dealer_discount_pct;
    if (line.unit_dealer_price_snapshot != null) config.unit_dealer_price_snapshot = line.unit_dealer_price_snapshot;
    if (line.dealer_price_total != null) config.dealer_price_total = line.dealer_price_total;
    if ((config as any).unit_labor_cost == null && (line as any).labor_cost_snapshot != null)
      (config as any).unit_labor_cost = (line as any).labor_cost_snapshot;
    if ((config as any).labor_amount == null && (line as any).labor_msrp_snapshot != null)
      (config as any).labor_amount = (line as any).labor_msrp_snapshot;
  }

  // ── 8. Derive width_m / height_m ──────────────────────────────────
  if (config.width_mm != null) config.width_m = config.width_mm / 1000;
  if (config.height_mm != null) config.height_m = config.height_mm / 1000;

  // Log solo primitivos (evitar [circular])
  console.log('[getConfigFromQuoteLine] RESULT', lineId, String(cpId ?? 'NONE'), snapshotApplied, String(config.hardware_color ?? 'MISSING'), String(config.bottom_bar_sku ?? 'MISSING'), String(config.bottom_bar_item_id ?? 'MISSING'));

  return config as ProductConfig;
}

// ── Helpers ──────────────────────────────────────────────────────────

function normalizeEnum<T extends string>(value: unknown, allowed: readonly T[]): T | undefined {
  if (value == null) return undefined;
  const n = String(value).trim().toLowerCase();
  return (allowed as readonly string[]).includes(n) ? (n as T) : undefined;
}
