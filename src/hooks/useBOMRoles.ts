import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export type RoleType = 'parent_only' | 'child_only' | 'both';

export interface CatalogRole {
  role_code: string;
  label: string;
  description: string | null;
  role_type: RoleType;
  active: boolean;
  sort_order: number;
}

export interface RoleDependency {
  role_code: string;
  parent_role_code: string;
}

export interface ProductTypeRoleRule {
  id: string;
  product_type_id: string;
  role_code: string;
  is_required: boolean;
  active: boolean;
  product_type_name?: string;
}

export interface ProductType {
  id: string;
  name: string;
}

export function useBOMRoles() {
  const [roles, setRoles] = useState<CatalogRole[]>([]);
  const [dependencies, setDependencies] = useState<RoleDependency[]>([]);
  const [productTypeRules, setProductTypeRules] = useState<ProductTypeRoleRule[]>([]);
  const [productTypes, setProductTypes] = useState<ProductType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const fetchAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [rolesRes, depsRes, rulesRes, ptRes] = await Promise.all([
        supabase
          .from('CatalogItemRoles')
          .select('role_code, label, description, role_type, active, sort_order')
          .order('sort_order')
          .order('label'),
        supabase
          .from('RoleDependencies')
          .select('role_code, parent_role_code'),
        activeOrganizationId
          ? supabase
              .from('ProductTypeRoleRules')
              .select('id, product_type_id, role_code, is_required, active')
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .eq('archived', false)
          : Promise.resolve({ data: [] as any[], error: null }),
        supabase
          .from('ProductTypes')
          .select('id, name')
          .order('name'),
      ]);

      if (rolesRes.error) throw new Error(rolesRes.error.message);
      if (depsRes.error) throw new Error(depsRes.error.message);
      if (rulesRes.error) throw new Error(rulesRes.error.message);
      if (ptRes.error) throw new Error(ptRes.error.message);

      setRoles((rolesRes.data ?? []) as CatalogRole[]);
      setDependencies((depsRes.data ?? []) as RoleDependency[]);
      setProductTypeRules((rulesRes.data ?? []) as ProductTypeRoleRule[]);
      setProductTypes((ptRes.data ?? []) as ProductType[]);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error loading roles';
      setError(msg);
      console.error('[useBOMRoles] fetch error:', msg);
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => {
    fetchAll();
  }, [fetchAll]);

  // ── Mutations ──

  const updateRoleType = useCallback(
    async (roleCode: string, roleType: RoleType) => {
      const { error: err } = await supabase
        .from('CatalogItemRoles')
        .update({ role_type: roleType })
        .eq('role_code', roleCode);
      if (err) throw new Error(err.message);
      setRoles((prev) =>
        prev.map((r) => (r.role_code === roleCode ? { ...r, role_type: roleType } : r)),
      );
    },
    [],
  );

  const toggleRoleActive = useCallback(
    async (roleCode: string, active: boolean) => {
      const { error: err } = await supabase
        .from('CatalogItemRoles')
        .update({ active })
        .eq('role_code', roleCode);
      if (err) throw new Error(err.message);
      setRoles((prev) =>
        prev.map((r) => (r.role_code === roleCode ? { ...r, active } : r)),
      );
    },
    [],
  );

  const addDependency = useCallback(
    async (roleCode: string, parentRoleCode: string) => {
      const { error: err } = await supabase
        .from('RoleDependencies')
        .insert({ role_code: roleCode, parent_role_code: parentRoleCode });
      if (err) throw new Error(err.message);
      setDependencies((prev) => [...prev, { role_code: roleCode, parent_role_code: parentRoleCode }]);
    },
    [],
  );

  const removeDependency = useCallback(
    async (roleCode: string, parentRoleCode: string) => {
      const { error: err } = await supabase
        .from('RoleDependencies')
        .delete()
        .eq('role_code', roleCode)
        .eq('parent_role_code', parentRoleCode);
      if (err) throw new Error(err.message);
      setDependencies((prev) =>
        prev.filter((d) => !(d.role_code === roleCode && d.parent_role_code === parentRoleCode)),
      );
    },
    [],
  );

  const upsertProductTypeRule = useCallback(
    async (productTypeId: string, roleCode: string, isRequired: boolean) => {
      if (!activeOrganizationId) throw new Error('No organization');
      const { data, error: err } = await supabase
        .from('ProductTypeRoleRules')
        .upsert(
          {
            organization_id: activeOrganizationId,
            product_type_id: productTypeId,
            role_code: roleCode,
            is_required: isRequired,
            active: true,
            deleted: false,
            archived: false,
          },
          { onConflict: 'organization_id,product_type_id,role_code' },
        )
        .select('id, product_type_id, role_code, is_required, active')
        .single();
      if (err) throw new Error(err.message);
      if (data) {
        setProductTypeRules((prev) => {
          const idx = prev.findIndex(
            (r) => r.product_type_id === productTypeId && r.role_code === roleCode,
          );
          if (idx >= 0) {
            const next = [...prev];
            next[idx] = data as ProductTypeRoleRule;
            return next;
          }
          return [...prev, data as ProductTypeRoleRule];
        });
      }
    },
    [activeOrganizationId],
  );

  const removeProductTypeRule = useCallback(
    async (productTypeId: string, roleCode: string) => {
      const existing = productTypeRules.find(
        (r) => r.product_type_id === productTypeId && r.role_code === roleCode,
      );
      if (!existing) return;
      const { error: err } = await supabase
        .from('ProductTypeRoleRules')
        .update({ active: false })
        .eq('id', existing.id);
      if (err) throw new Error(err.message);
      setProductTypeRules((prev) => prev.filter((r) => r.id !== existing.id));
    },
    [productTypeRules],
  );

  const renameRole = useCallback(
    async (roleCode: string, newLabel: string) => {
      const trimmed = newLabel.trim();
      if (!trimmed) throw new Error('Label cannot be empty');
      const { error: err } = await supabase
        .from('CatalogItemRoles')
        .update({ label: trimmed })
        .eq('role_code', roleCode);
      if (err) throw new Error(err.message);
      setRoles((prev) =>
        prev.map((r) => (r.role_code === roleCode ? { ...r, label: trimmed } : r)),
      );
    },
    [],
  );

  const deleteRole = useCallback(
    async (roleCode: string) => {
      // Remove dependencies first (both as parent and child)
      const { error: depErr } = await supabase
        .from('RoleDependencies')
        .delete()
        .or(`role_code.eq.${roleCode},parent_role_code.eq.${roleCode}`);
      if (depErr) throw new Error(depErr.message);

      const { error: err } = await supabase
        .from('CatalogItemRoles')
        .delete()
        .eq('role_code', roleCode);
      if (err) throw new Error(err.message);

      setRoles((prev) => prev.filter((r) => r.role_code !== roleCode));
      setDependencies((prev) =>
        prev.filter((d) => d.role_code !== roleCode && d.parent_role_code !== roleCode),
      );
    },
    [],
  );

  return {
    roles,
    dependencies,
    productTypeRules,
    productTypes,
    loading,
    error,
    refetch: fetchAll,
    updateRoleType,
    toggleRoleActive,
    renameRole,
    deleteRole,
    addDependency,
    removeDependency,
    upsertProductTypeRule,
    removeProductTypeRule,
  };
}
