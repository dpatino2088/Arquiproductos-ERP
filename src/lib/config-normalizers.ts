/**
 * Config Normalizers - Getters canónicos para evitar inconsistencias camelCase vs snake_case
 * 
 * El configurador tiene duplicación de llaves (hardware_color vs hardwareColor, etc.)
 * Estos getters aseguran que siempre leamos el valor correcto sin ambigüedad.
 */

type AnyConfig = Record<string, any>;

/**
 * Get hardware color (normalized to CAPITALIZED: White, Black, Silver, Bronze)
 */
export function getHardwareColor(cfg: AnyConfig): string | null {
  const value = cfg.hardware_color ?? cfg.hardwareColor ?? cfg.operatingSystemColor ?? null;
  if (!value) return null;
  // Normalize to capitalize first letter
  return String(value).trim().charAt(0).toUpperCase() + String(value).trim().slice(1).toLowerCase();
}

/**
 * Get product type ID
 */
export function getProductTypeId(cfg: AnyConfig): string | null {
  return cfg.product_type_id ?? cfg.productTypeId ?? null;
}

/**
 * Get product type code
 */
export function getProductType(cfg: AnyConfig): string | null {
  return cfg.product_type ?? cfg.productType ?? null;
}

/**
 * Get collection name
 */
export function getCollectionName(cfg: AnyConfig): string | null {
  return cfg.collection_name ?? cfg.collectionName ?? null;
}

/**
 * Get collection ID
 */
export function getCollectionId(cfg: AnyConfig): string | null {
  return cfg.collection_id ?? cfg.collectionId ?? null;
}

/**
 * Get variant name
 */
export function getVariantName(cfg: AnyConfig): string | null {
  return cfg.variant_name ?? cfg.variantName ?? null;
}

/**
 * Get variant ID (fabric catalog item ID)
 */
export function getVariantId(cfg: AnyConfig): string | null {
  return cfg.variant_id ?? cfg.variantId ?? cfg.fabric_catalog_item_id ?? null;
}

/**
 * Get operation type (motor | manual)
 */
export function getOperationType(cfg: AnyConfig): 'motor' | 'manual' | null {
  return cfg.operation_type ?? cfg.drive_type ?? cfg.operatingSystem === 'motorized' ? 'motor' : cfg.operatingSystem === 'manual' ? 'manual' : null;
}

/**
 * Get bottom bar SKU (trimmed, null if empty)
 */
export function getBottomBarSku(cfg: AnyConfig): string | null {
  const value = cfg.bottom_bar_sku ?? cfg.bottomBarSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get tube SKU (trimmed, null if empty)
 */
export function getTubeSku(cfg: AnyConfig): string | null {
  const value = cfg.tube_sku ?? cfg.tubeSku ?? cfg.tube_type ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get headbox SKU (trimmed, null if empty)
 */
export function getHeadboxSku(cfg: AnyConfig): string | null {
  const value = cfg.headbox_sku ?? cfg.headboxSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get motor SKU (trimmed, null if empty)
 */
export function getMotorSku(cfg: AnyConfig): string | null {
  const value = cfg.motor_sku ?? cfg.motorSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get drive SKU (trimmed, null if empty)
 */
export function getDriveSku(cfg: AnyConfig): string | null {
  const value = cfg.drive_sku ?? cfg.driveSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get side channel SKU (trimmed, null if empty)
 */
export function getSideChannelSku(cfg: AnyConfig): string | null {
  const value = cfg.side_channel_sku ?? cfg.sideChannelSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/**
 * Get bottom channel SKU (trimmed, null if empty)
 */
export function getBottomChannelSku(cfg: AnyConfig): string | null {
  const value = cfg.bottom_channel_sku ?? cfg.bottomChannelSku ?? null;
  if (!value) return null;
  const trimmed = String(value).trim();
  return trimmed || null;
}

/** Serialize to primitive-safe value to avoid [circular] in logs */
function toLogVal(v: unknown): unknown {
  if (v === null || v === undefined) return v;
  const t = typeof v;
  if (t === 'string' || t === 'number' || t === 'boolean') return v;
  if (Array.isArray(v)) return `[array len=${v.length}]`;
  if (t === 'object') return '[object]';
  return String(v);
}

/**
 * Log config diff (antes/después de update) para debugging.
 * Solo primitives / placeholders para evitar [circular].
 */
export function logConfigDiff(prev: AnyConfig, next: AnyConfig, label: string) {
  if (!import.meta.env.DEV) return;
  
  const criticalKeys = [
    'product_type_id', 'productTypeId',
    'hardware_color', 'hardwareColor',
    'operation_type', 'drive_type',
    'bottom_bar_sku', 'tube_sku', 'headbox_sku',
    'drive_sku', 'motor_sku',
    'side_channel_sku', 'bottom_channel_sku',
  ];
  
  const diff: { label: string; lost: Array<{ key: string; prevVal: unknown }>; changed: Array<{ key: string; prevVal: unknown; nextVal: unknown }>; added: Array<{ key: string; nextVal: unknown }> } = {
    label,
    lost: [],
    changed: [],
    added: [],
  };
  
  criticalKeys.forEach(key => {
    const prevVal = prev[key];
    const nextVal = next[key];
    
    if (prevVal !== undefined && nextVal === undefined) {
      diff.lost.push({ key, prevVal: toLogVal(prevVal) });
    } else if (prevVal !== nextVal) {
      diff.changed.push({ key, prevVal: toLogVal(prevVal), nextVal: toLogVal(nextVal) });
    } else if (prevVal === undefined && nextVal !== undefined) {
      diff.added.push({ key, nextVal: toLogVal(nextVal) });
    }
  });
  
  if (diff.lost.length > 0 || diff.changed.length > 0 || diff.added.length > 0) {
    console.warn('[ConfigDiff] State change detected', diff);
  }
}
