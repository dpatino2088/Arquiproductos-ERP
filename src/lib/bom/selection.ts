/**
 * Role Selection System
 * 
 * Define tres estados claros para la selección de roles en el configurador:
 * - UNSET: No se ha seleccionado nada, no aplica filtro
 * - SELECTED: Se seleccionó un item específico, filtra por SKU
 * - NONE: Se seleccionó explícitamente "ninguno", excluye templates con ese rol
 */

export type RoleSelection =
  | { state: "unset" }
  | { state: "none" }
  | { state: "selected"; catalog_item_id: string; sku: string; code?: string }; // sku = CatalogItems.sku (backward compat: code)

/**
 * Helper functions para verificar el estado de una selección
 */
export function isUnset(s?: RoleSelection | null): boolean {
  return !s || s.state === "unset";
}

export function isNone(s?: RoleSelection | null): boolean {
  return !!s && s.state === "none";
}

export function isSelected(s?: RoleSelection | null): boolean {
  return !!s && s.state === "selected";
}

/**
 * Convierte una selección antigua (sku string | null | undefined) a RoleSelection
 * Útil para migración gradual
 * 
 * REGLAS:
 * - sku === null && catalog_item_id === null → NONE (explícito)
 * - sku === undefined || sku === '' → UNSET (no seleccionado)
 * - sku válido (string no vacío) → SELECTED
 */
export function toRoleSelection(
  sku?: string | null | undefined,
  catalog_item_id?: string | null | undefined
): RoleSelection {
  // ✅ Caso especial: ambos null explícitos → NONE
  if (sku === null && catalog_item_id === null) {
    return { state: "none" };
  }
  
  // Si sku es undefined, null, o string vacío → UNSET
  const cleanSku = (sku || "").trim();
  if (!cleanSku) {
    return { state: "unset" };
  }
  
  // Caso especial: si el string es literalmente "none" → NONE
  if (cleanSku === 'none' || cleanSku === 'NONE') {
    return { state: "none" };
  }
  
  // ✅ Si hay SKU válido Y catalog_item_id → SELECTED
  if (cleanSku && catalog_item_id) {
    return {
      state: "selected",
      catalog_item_id: catalog_item_id,
      sku: cleanSku,
      code: cleanSku, // backward compat
    };
  }
  
  // Si hay SKU pero no catalog_item_id → SELECTED (pero sin item_id)
  if (cleanSku) {
    return {
      state: "selected",
      catalog_item_id: catalog_item_id || '',
      sku: cleanSku,
      code: cleanSku, // backward compat
    };
  }
  
  // Default: UNSET
  return { state: "unset" };
}

/**
 * Extrae el SKU real de una RoleSelection, con blindaje para legacy code
 * Siempre retorna el SKU real (de CatalogItems.sku), nunca code
 */
export function getSelectionSku(s?: RoleSelection | null): string | undefined {
  if (!s || s.state !== "selected") return undefined;
  
  // ✅ Priorizar sku, luego code (backward compat), luego nada
  const v = (s.sku || (s as any).code || "").trim();
  return v.length > 0 ? v : undefined;
}

/**
 * Convierte RoleSelection a formato legacy (para compatibilidad)
 */
export function toLegacyFormat(selection: RoleSelection): {
  sku: string | null;
  catalog_item_id: string | null;
} {
  if (isSelected(selection)) {
    return {
      sku: selection.sku || selection.code || '',
      catalog_item_id: selection.catalog_item_id,
    };
  }
  
  if (isNone(selection)) {
    return {
      sku: null,
      catalog_item_id: null,
    };
  }
  
  // UNSET
  return {
    sku: undefined as any, // undefined para indicar que no se ha seleccionado
    catalog_item_id: null,
  };
}
