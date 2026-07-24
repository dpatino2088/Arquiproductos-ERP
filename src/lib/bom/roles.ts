/**
 * Canonical BOM Component Roles
 * 
 * Single source of truth for valid component_role values.
 * These roles match the ComponentRoleMap table in the database.
 * 
 * All roles are stored in lowercase to prevent typos and ensure consistency.
 * 
 * Architecture: 2-level model
 * - role: Canonical BOM vocabulary (max 15, stable, universal)
 * - sub_role: Part type/specific variant (optional, for granularity)
 */

// Canonical roles - EXACT list from user requirements (all lowercase)
export const CANONICAL_COMPONENT_ROLES = [
  'tube',
  'track',
  'bottom_bar',
  'bottom_channel',
  'hem_weight',
  'side_channel',
  'top_rail',
  'headbox',
  'bracket',
  'intermediate_bracket',
  'idler',
  'drive',
  'motor',
  'chain',
  'chain_stop',
  'chain_tensioner',
  'wand',
  'end_cap',
  'filler',
  'tape',
  'consumable',
  'fastener',
  'accessory',
  'carrier',
  'belt',
  'belt_connector',
  'hook',
  'brush',
  'fabric',
  'adapter', // ✅ Agregado: necesario para child roles
  // ✅ Nuevos roles child (agregados según requerimiento del usuario)
  'bearing',
  'connector',
  'guide',
  'rail_connector',
  'spring',
  'stopper',
  'mounting_clip',
  'intermediate_connector',
  'end_plug', // Aunque no era canónico originalmente, se requiere como child role
] as const;

export type CanonicalComponentRole = typeof CANONICAL_COMPONENT_ROLES[number];

/**
 * Valid Child Roles
 * 
 * Child roles MUST be canonical roles that are also allowed in CatalogItemComponents.child_role.
 * According to the database schema:
 * - Canonical roles are defined in BOMComponents.component_role CHECK constraint
 * - Child roles are defined in CatalogItemComponents.child_role CHECK constraint
 * - Valid child roles = intersection of canonical roles and child_role constraint
 * 
 * ✅ Lista completa de child roles según requerimiento del usuario:
 * - chain, belt, belt_connector, hem_weight, brush, accessory, carrier, consumable, hook
 * - mounting_clip, bearing, connector, end_plug, guide, rail_connector, spring, stopper, idler
 */
export const VALID_CHILD_ROLES = [
  // Roles originales
  'adapter',
  'end_cap',
  'fastener',
  'idler',
  'chain_stop',
  'chain_tensioner',
  'filler',
  // ✅ Nuevos child roles (según requerimiento del usuario)
  'chain',
  'belt',
  'belt_connector',
  'hem_weight',
  'brush',
  'accessory',
  'carrier',
  'consumable',
  'hook',
  'mounting_clip',
  'bearing',
  'connector',
  'end_plug',
  'guide',
  'rail_connector',
  'spring',
  'stopper',
] as const;

export type ValidChildRole = typeof VALID_CHILD_ROLES[number];

/**
 * Check if a role is a valid child role (canonical and allowed as child)
 */
export function isValidChildRole(role: string | null | undefined): boolean {
  if (!role) return false;
  const normalized = normalizeSubRole(role);
  if (!normalized) return false;
  const cached = getCachedRoles();
  if (cached) {
    return cached.some(r => r.active && r.role_type !== 'parent_only' && r.role_code === normalized);
  }
  return (VALID_CHILD_ROLES as readonly string[]).includes(normalized);
}

/**
 * Sub-roles mapping: which roles have available sub_roles
 * Used in UI to show sub_role dropdown conditionally
 */
export const ROLE_SUB_ROLES: Record<string, readonly string[]> = {
  hardware: ['fastener', 'end_cap', 'adapter'] as const,
  drive_manual: ['chain'] as const,
  end_cap: ['end_plug', 'bottom_rail_end_cap', 'cassette_end_cap', 'bracket_end_cap', 'screw_end_cap'] as const,
  bottom_rail: ['profile'] as const,
  side_channel: ['profile'] as const,
} as const;

/**
 * Get available sub_roles for a given role
 */
export function getSubRolesForRole(role: string | null | undefined): readonly string[] | null {
  if (!role) return null;
  const normalized = normalizeRole(role);
  if (!normalized) return null;
  return ROLE_SUB_ROLES[normalized] || null;
}

/**
 * Check if a role has sub_roles available
 */
export function hasSubRoles(role: string | null | undefined): boolean {
  const subRoles = getSubRolesForRole(role);
  return subRoles !== null && subRoles.length > 0;
}

/**
 * Normalize a role string to lowercase and trim whitespace
 */
export function normalizeRole(role: string | null | undefined): string | null {
  if (!role) return null;
  return role.toLowerCase().trim() || null;
}

/**
 * Normalize a sub_role string to lowercase and trim whitespace
 */
export function normalizeSubRole(subRole: string | null | undefined): string | null {
  if (!subRole) return null;
  return subRole.toLowerCase().trim() || null;
}

/**
 * Check if a role is valid. Uses DB cache (CatalogItemRoles) as source of truth.
 * Falls back to hardcoded list only if cache hasn't loaded yet.
 */
export function isValidRole(role: string | null | undefined): boolean {
  if (!role) return true;
  const normalized = normalizeRole(role);
  if (!normalized) return true;
  const cached = getCachedRoles();
  if (cached) {
    return cached.some(r => r.active && r.role_code === normalized);
  }
  if ((CANONICAL_COMPONENT_ROLES as readonly string[]).includes(normalized)) return true;
  return true;
}

/**
 * Check if a sub_role is valid for a given role
 */
export function isValidSubRole(role: string | null | undefined, subRole: string | null | undefined): boolean {
  if (!subRole) return true; // null/empty is valid
  const normalizedRole = normalizeRole(role);
  const normalizedSubRole = normalizeSubRole(subRole);
  if (!normalizedRole || !normalizedSubRole) return false;
  
  const validSubRoles = getSubRolesForRole(normalizedRole);
  if (!validSubRoles) return false;
  
  return validSubRoles.includes(normalizedSubRole);
}

/**
 * Get display label for a role (Title Case)
 * Handles both canonical and legacy roles gracefully
 */
const ROLE_DISPLAY_LABELS: Record<string, string> = {
  bracket: 'Edge Bracket (L/R)',
  intermediate_bracket: 'Intermediate Bracket (N−1)',
  intermediate_connector: 'Intermediate Connector',
  mounting_clip: 'Mounting Clip (spacing)',
};

export function getRoleLabel(role: string | null | undefined): string {
  if (!role) return '— None —';
  const normalized = normalizeRole(role);
  if (!normalized) return '— None —';

  if (ROLE_DISPLAY_LABELS[normalized]) return ROLE_DISPLAY_LABELS[normalized];

  // Prefer DB label when available
  const cached = getCachedRoles();
  const dbLabel = cached?.find((r) => r.role_code === normalized)?.label;
  if (dbLabel) return dbLabel;

  // Convert snake_case to Title Case
  return normalized
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Get display label for a sub_role (Title Case)
 */
export function getSubRoleLabel(subRole: string | null | undefined): string {
  if (!subRole) return '— None —';
  const normalized = normalizeSubRole(subRole);
  if (!normalized) return '— None —';
  
  // Convert snake_case to Title Case
  return normalized
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

// ── DB-driven role lists (cached in-memory) ──

import { supabase } from '../supabase/client';

interface DBRole {
  role_code: string;
  label: string;
  role_type: 'parent_only' | 'child_only' | 'both';
  active: boolean;
}

interface DBDependency {
  role_code: string;
  parent_role_code: string;
}

let _cachedRoles: DBRole[] | null = null;
let _cachedDeps: DBDependency[] | null = null;
let _fetchPromise: Promise<void> | null = null;

export function getCachedRoles(): DBRole[] | null {
  ensureRolesLoaded();
  return _cachedRoles;
}

async function ensureRolesLoaded(): Promise<void> {
  if (_cachedRoles) return;
  if (_fetchPromise) return _fetchPromise;
  _fetchPromise = (async () => {
    try {
      const [rolesRes, depsRes] = await Promise.all([
        supabase
          .from('CatalogItemRoles')
          .select('role_code, label, role_type, active')
          .order('sort_order')
          .order('label'),
        supabase
          .from('RoleDependencies')
          .select('role_code, parent_role_code'),
      ]);
      _cachedRoles = (rolesRes.data ?? []) as DBRole[];
      _cachedDeps = (depsRes.data ?? []) as DBDependency[];
    } catch {
      _cachedRoles = null;
      _cachedDeps = null;
    }
    _fetchPromise = null;
  })();
  return _fetchPromise;
}

export function invalidateRolesCache(): void {
  _cachedRoles = null;
  _cachedDeps = null;
  _fetchPromise = null;
  ensureRolesLoaded();
}

/**
 * Get parent/both roles for the component_role dropdown (BOMTemplateModal).
 * Falls back to CANONICAL_COMPONENT_ROLES if DB hasn't loaded.
 */
export function getParentRoleOptions(): Array<{ value: string; label: string }> {
  ensureRolesLoaded();
  if (_cachedRoles) {
    return _cachedRoles
      .filter((r) => r.active && r.role_type !== 'child_only')
      .map((r) => ({ value: r.role_code, label: r.label }));
  }
  return CANONICAL_COMPONENT_ROLES.map((r) => ({ value: r, label: getRoleLabel(r) }));
}

/**
 * Get child roles for the child_role dropdown (BOMChildrenModal).
 * Optionally filtered by parent role using RoleDependencies.
 * Falls back to VALID_CHILD_ROLES if DB hasn't loaded.
 */
export function getChildRoleOptions(parentRole?: string | null): Array<{ value: string; label: string }> {
  ensureRolesLoaded();
  if (_cachedRoles) {
    let childCodes: Set<string> | null = null;
    if (parentRole && _cachedDeps) {
      const depCodes = _cachedDeps
        .filter((d) => d.parent_role_code === parentRole)
        .map((d) => d.role_code);
      if (depCodes.length > 0) childCodes = new Set(depCodes);
    }
    return _cachedRoles
      .filter((r) => {
        if (!r.active) return false;
        if (r.role_type === 'parent_only') return false;
        if (childCodes && !childCodes.has(r.role_code)) return false;
        return true;
      })
      .map((r) => ({ value: r.role_code, label: r.label }));
  }
  return (VALID_CHILD_ROLES as readonly string[]).map((r) => ({ value: r, label: getRoleLabel(r) }));
}

/**
 * Get all active roles (for any dropdown that needs the full list).
 */
export function getAllRoleOptions(): Array<{ value: string; label: string }> {
  ensureRolesLoaded();
  if (_cachedRoles) {
    return _cachedRoles
      .filter((r) => r.active)
      .map((r) => ({ value: r.role_code, label: r.label }));
  }
  return CANONICAL_COMPONENT_ROLES.map((r) => ({ value: r, label: getRoleLabel(r) }));
}
