import { useState, useEffect, useMemo, useCallback, useRef, forwardRef, useImperativeHandle } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { Check } from 'lucide-react';
import { getDefaultPermissionsForRole, type OrgRole, isValidOrgRole } from '../../rbac/rolePresets';

interface Permission {
  code: string;
  module: string;
  description: string;
}

interface OrganizationUserPermissionsProps {
  organizationUserId: string;
  userRole: 'superadmin' | 'admin' | 'operator' | 'procurement' | 'finance' | 'member';
  onSave?: (saved: boolean) => void;
  onCancel?: () => void;
  onDirtyChange?: (isDirty: boolean) => void;
  externalSave?: (saveFn: () => Promise<void>) => void;
  onRequestSave?: () => Promise<void>;
  showActions?: boolean; // If false, don't render action buttons (parent handles them)
}

export interface OrganizationUserPermissionsRef {
  applyRolePreset: (role: OrgRole, allPermissionCodes?: string[]) => Promise<void>;
}

// Module order for consistent display
const MODULE_ORDER = [
  'catalog',
  'directory',
  'sales',
  'manufacturing',
  'inventory',
  'purchasing',
  'financials',
  'reports',
  'settings',
];

const MODULE_LABELS: Record<string, string> = {
  directory: 'Directory',
  catalog: 'Catalog',
  sales: 'Sales',
  manufacturing: 'Manufacturing',
  purchasing: 'Purchasing',
  inventory: 'Inventory',
  financials: 'Financials',
  reports: 'Reports',
  settings: 'Settings',
};

// Sort permissions: read before write, then alphabetical
const sortPermissions = (perms: Permission[]): Permission[] => {
  return [...perms].sort((a, b) => {
    const aIsRead = a.code.endsWith('.read');
    const bIsRead = b.code.endsWith('.read');
    
    if (aIsRead && !bIsRead) return -1;
    if (!aIsRead && bIsRead) return 1;
    
    return a.code.localeCompare(b.code);
  });
};

// Group permissions by module
const groupPermissionsByModule = (permissions: Permission[]): Record<string, Permission[]> => {
  return permissions.reduce((acc, perm) => {
    if (!acc[perm.module]) {
      acc[perm.module] = [];
    }
    const moduleArray = acc[perm.module];
    if (moduleArray) {
      moduleArray.push(perm);
    }
    return acc;
  }, {} as Record<string, Permission[]>);
};

// PermissionModuleCard Component
interface PermissionModuleCardProps {
  moduleName: string;
  permissions: Permission[];
  selectedSet: Set<string>;
  onTogglePermission: (code: string) => void;
  disabled?: boolean;
}

function PermissionModuleCard({
  moduleName,
  permissions,
  selectedSet,
  onTogglePermission,
  disabled = false,
}: PermissionModuleCardProps) {
  const sortedPermissions = useMemo(() => sortPermissions(permissions), [permissions]);
  const checkboxRef = useRef<HTMLInputElement>(null);
  
  const allSelected = sortedPermissions.length > 0 && sortedPermissions.every(p => selectedSet.has(p.code));
  const someSelected = sortedPermissions.some(p => selectedSet.has(p.code)) && !allSelected;
  
  // Set indeterminate state
  useEffect(() => {
    if (checkboxRef.current) {
      checkboxRef.current.indeterminate = someSelected;
    }
  }, [someSelected]);
  
  const handleToggleModule = () => {
    if (disabled) return;
    
    const nextState = !allSelected;
    sortedPermissions.forEach(perm => {
      const isSelected = selectedSet.has(perm.code);
      if (nextState && !isSelected) {
        onTogglePermission(perm.code);
      } else if (!nextState && isSelected) {
        onTogglePermission(perm.code);
      }
    });
  };

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
      {/* Header */}
      <div className="flex items-center justify-between mb-4 pb-3 border-b border-gray-100">
        <div className="flex-1">
          <h4 className="text-sm font-semibold text-gray-900 capitalize">
            {MODULE_LABELS[moduleName] || moduleName}
          </h4>
        </div>
        <div className="flex items-center gap-2">
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              ref={checkboxRef}
              type="checkbox"
              checked={allSelected}
              onChange={handleToggleModule}
              disabled={disabled}
              className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
            />
            <span className="text-xs text-gray-600">
              {allSelected ? 'Todos' : someSelected ? 'Algunos' : 'Ninguno'}
            </span>
          </label>
        </div>
      </div>

      {/* Permissions List */}
      <div className="space-y-2">
        {sortedPermissions.map((permission) => {
          const isChecked = selectedSet.has(permission.code);
          return (
            <label
              key={permission.code}
              className={`flex items-start gap-3 p-2 rounded border cursor-pointer transition-colors ${
                isChecked
                  ? 'bg-blue-50 border-blue-200'
                  : 'bg-white border-gray-200 hover:bg-gray-50'
              } ${disabled ? 'cursor-not-allowed opacity-60' : ''}`}
            >
              <input
                type="checkbox"
                checked={isChecked}
                onChange={() => onTogglePermission(permission.code)}
                disabled={disabled}
                className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary mt-0.5"
              />
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-gray-900">
                  {permission.code}
                </div>
                {permission.description && (
                  <div className="text-xs text-gray-500 mt-0.5">
                    {permission.description}
                  </div>
                )}
              </div>
              {isChecked && (
                <Check className="w-4 h-4 text-blue-600 flex-shrink-0 mt-0.5" />
              )}
            </label>
          );
        })}
      </div>
    </div>
  );
}

// Helper functions (must be defined before the component uses them)
const getAllPermissionCodes = (permissions: Permission[]): Set<string> => {
  return new Set(permissions.map(p => p.code));
};

const getDefaultAdminPermissions = (permissions: Permission[]): Set<string> => {
  // Admin gets all permissions except settings.write (which controls user management)
  const allCodes = permissions.map(p => p.code);
  return new Set(allCodes.filter(code => code !== 'settings.write'));
};

const getDefaultMemberPermissions = (): Set<string> => {
  // Member starts with empty permissions (or only read permissions if desired)
  return new Set<string>();
};

// Helper to compare sets
function setsEqual(a: Set<string>, b: Set<string>): boolean {
  if (a.size !== b.size) return false;
  for (const v of a) {
    if (!b.has(v)) return false;
  }
  return true;
}

const OrganizationUserPermissions = forwardRef<OrganizationUserPermissionsRef, OrganizationUserPermissionsProps>(({ 
  organizationUserId,
  userRole,
  onSave,
  onCancel,
  onDirtyChange,
  externalSave,
  onRequestSave,
  showActions = true, // Default: render buttons (parent can override)
}, ref) => {
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isAdmin } = useCurrentOrgRole();
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [assignedPermissions, setAssignedPermissions] = useState<Set<string>>(new Set()); // From DB
  const [originalPermissions, setOriginalPermissions] = useState<Set<string>>(new Set());
  const [draftPermissions, setDraftPermissions] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const previousRoleRef = useRef<typeof userRole | null>(null);

  // Only admins can edit permissions
  const canEdit = isSuperAdmin || isAdmin;

  // Apply role preset (exposed via ref)
  const applyRolePreset = useCallback(async (role: OrgRole, allPermissionCodes?: string[]) => {
    if (role === 'superadmin') {
      // Superadmin: use all permissions
      const allCodes = allPermissionCodes || permissions.map(p => p.code);
      const preset = new Set(allCodes);
      setDraftPermissions(preset);
      setOriginalPermissions(preset);
    } else {
      // Get preset for role
      const preset = getDefaultPermissionsForRole(role, allPermissionCodes);
      setDraftPermissions(preset);
      setOriginalPermissions(preset);
    }
  }, [permissions]);

  // Expose applyRolePreset via ref
  useImperativeHandle(ref, () => ({
    applyRolePreset,
  }), [applyRolePreset]);

  // Calculate effective permissions for rendering
  const effectivePermissions = useMemo(() => {
    if (userRole === 'superadmin') {
      // Superadmin has all permissions implicitly
      return getAllPermissionCodes(permissions);
    }
    // For other roles, use draftPermissions
    return draftPermissions;
  }, [userRole, permissions, draftPermissions]);

  // Check if there are changes (dirty state) - using setsEqual helper
  const isDirtyPermissions = useMemo(() => {
    // Superadmin never has dirty state (permissions are implicit)
    if (userRole === 'superadmin') return false;
    
    return !setsEqual(draftPermissions, originalPermissions);
  }, [originalPermissions, draftPermissions, userRole]);

  // Notify parent of dirty state changes
  useEffect(() => {
    if (onDirtyChange) {
      onDirtyChange(isDirtyPermissions);
    }
  }, [isDirtyPermissions, onDirtyChange]);

  // Internal save function (also used by external save)
  const savePermissionsInternal = useCallback(async () => {
    if (!canEdit || saving) return;
    
    // If superadmin, don't save permissions (they're implicit)
    if (userRole === 'superadmin') {
      return;
    }

    if (!isDirtyPermissions) return;

    setSaving(true);
    try {
      // Calculate differences
      const toAdd: string[] = [];
      const toRemove: string[] = [];

      // Find permissions to add
      draftPermissions.forEach(code => {
        if (!originalPermissions.has(code)) {
          toAdd.push(code);
        }
      });

      // Find permissions to remove
      originalPermissions.forEach(code => {
        if (!draftPermissions.has(code)) {
          toRemove.push(code);
        }
      });

      // Execute inserts and deletes sequentially to better handle errors
      // Add new permissions
      if (toAdd.length > 0) {
        // Filter out duplicates (shouldn't happen, but safety check)
        const uniqueToAdd = Array.from(new Set(toAdd));
        
        const insertRows = uniqueToAdd.map(code => ({
          organization_user_id: organizationUserId,
          permission_code: code,
        }));
        
        const { data, error } = await supabase
          .from('OrganizationUserPermissions')
          .insert(insertRows);
        
        if (error) {
          // Handle duplicate key error (23505) - ignore if it's a duplicate
          if (error.code === '23505') {
            // Duplicate key violation - permission already exists
            // This can happen if the permission was added between load and save
            // Log but don't throw - continue with other inserts
            if (import.meta.env.DEV) {
              console.warn('SAVE PERMISSIONS WARNING (DUPLICATE)', {
                error,
                insertRows,
                message: 'Some permissions already exist, skipping duplicates',
              });
            }
          } else {
            console.error('SAVE PERMISSIONS ERROR (INSERT)', {
              error,
              errorCode: error.code,
              errorMessage: error.message,
              errorDetails: error.details,
              errorHint: error.hint,
              insertRows,
              toAdd: uniqueToAdd,
              organizationUserId,
            });
            throw error; // IMPORTANT: que reviente para que lo veas
          }
        }
      }

      // Remove permissions
      if (toRemove.length > 0) {
        const { data, error } = await supabase
          .from('OrganizationUserPermissions')
          .delete()
          .eq('organization_user_id', organizationUserId)
          .in('permission_code', toRemove);
        
        if (error) {
          console.error('SAVE PERMISSIONS ERROR (DELETE)', {
            error,
            errorCode: error.code,
            errorMessage: error.message,
            errorDetails: error.details,
            errorHint: error.hint,
            toRemove,
            organizationUserId,
          });
          throw error; // IMPORTANT: que reviente para que lo veas
        }
      }

      // Update original permissions to match draft
      setOriginalPermissions(new Set(draftPermissions));
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error saving permissions:', err);
      }
      throw err; // Re-throw to let parent handle
    } finally {
      setSaving(false);
    }
  }, [canEdit, saving, isDirtyPermissions, draftPermissions, originalPermissions, organizationUserId, userRole]);

  // Expose save function to parent
  useEffect(() => {
    if (externalSave) {
      externalSave(savePermissionsInternal);
    }
  }, [externalSave, savePermissionsInternal]);

  // Initialize previousRoleRef on mount
  useEffect(() => {
    if (previousRoleRef.current === null) {
      previousRoleRef.current = userRole;
    }
  }, []);

  // Load data when userId or org changes
  useEffect(() => {
    if (organizationUserId && activeOrganizationId) {
      loadData();
    }
  }, [organizationUserId, activeOrganizationId]);

  // Handle role change: recalculate draftPermissions
  useEffect(() => {
    // Skip on initial load (wait for permissions to load)
    if (previousRoleRef.current === null || permissions.length === 0) {
      if (previousRoleRef.current === null) {
        previousRoleRef.current = userRole;
      }
      return;
    }

    // If role changed (but don't auto-apply presets here - parent handles it via ref)
    if (previousRoleRef.current !== userRole) {
      // Just update the ref, don't auto-apply presets
      // The parent component will call applyRolePreset if needed
      previousRoleRef.current = userRole;
    }
  }, [userRole, permissions, assignedPermissions]);

  const loadData = useCallback(async () => {
    if (!activeOrganizationId || !organizationUserId) return;

    setLoading(true);
    try {
      // Load all available permissions
      const { data: allPermissions, error: permsError } = await supabase
        .from('Permissions')
        .select('code, module, description')
        .order('module, code');

      if (permsError) throw permsError;
      setPermissions(allPermissions || []);

      // Load user's current permissions
      const { data: userPerms, error: userPermsError } = await supabase
        .from('OrganizationUserPermissions')
        .select('permission_code')
        .eq('organization_user_id', organizationUserId);

      if (userPermsError) throw userPermsError;
      
      const currentPerms = new Set((userPerms || []).map(p => p.permission_code));
      setAssignedPermissions(new Set(currentPerms));
      
      // Initialize draftPermissions based on current role
      if (userRole === 'superadmin') {
        // Superadmin: don't use DB permissions, they're implicit
        setOriginalPermissions(new Set());
        setDraftPermissions(new Set());
      } else if (isValidOrgRole(userRole)) {
        // New roles: use role preset if no DB permissions, otherwise use DB permissions
        const allCodes = (allPermissions || []).map(p => p.code);
        const rolePreset = getDefaultPermissionsForRole(userRole, allCodes);
        
        if (currentPerms.size > 0) {
          // User has DB permissions, use those
          setOriginalPermissions(new Set(currentPerms));
          setDraftPermissions(new Set(currentPerms));
        } else {
          // No DB permissions: initialize originalPermissions as EMPTY (so save will insert preset)
          // and draftPermissions with preset (so UI shows them)
          // This ensures that when user saves, all preset permissions get inserted
          setOriginalPermissions(new Set()); // Empty = no permissions in DB yet
          setDraftPermissions(rolePreset); // Preset = what we want to save
        }
      } else {
        // Member or other legacy roles: use only DB permissions
        setOriginalPermissions(new Set(currentPerms));
        setDraftPermissions(new Set(currentPerms));
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error loading permissions:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Error al cargar permisos. Por favor, intenta de nuevo.',
      });
    } finally {
      setLoading(false);
    }
  }, [organizationUserId, activeOrganizationId]);

  // Toggle permission in draft state (NO persiste en DB)
  const handleTogglePermission = useCallback((permissionCode: string) => {
    if (!canEdit || saving || userRole === 'superadmin') return; // Superadmin can't toggle

    setDraftPermissions(prev => {
      const next = new Set(prev);
      if (next.has(permissionCode)) {
        next.delete(permissionCode);
      } else {
        next.add(permissionCode);
      }
      return next;
    });
  }, [canEdit, saving, userRole]);

  // Save permissions to DB
  const handleSave = useCallback(async (finish: boolean = false) => {
    console.log('CLICK SAVE', {
      isDirtyPermissions,
      isSaving: saving,
      canEdit,
      userRole,
      organizationUserId,
    });

    if (!canEdit || saving) {
      console.warn('SAVE BLOCKED', { canEdit, saving });
      return;
    }
    
    // If superadmin, don't save permissions (they're implicit)
    if (userRole === 'superadmin') {
      useUIStore.getState().addNotification({
        type: 'info',
        title: 'Información',
        message: 'Los Superadmins tienen todos los permisos automáticamente. No es necesario guardar permisos.',
      });
      if (onSave) {
        onSave(finish);
      }
      return;
    }

    // If no dirty changes, just exit (no-op save)
    if (!isDirtyPermissions) {
      console.log('SAVE SKIP - No permission changes', {
        draftPermissions: Array.from(draftPermissions),
        originalPermissions: Array.from(originalPermissions),
      });
      
      // Notify parent that there are no changes
      if (onDirtyChange) {
        onDirtyChange(false);
      }
      if (onSave) {
        onSave(finish);
      }
      return;
    }

    console.log('HANDLE SAVE PERMISSIONS', {
      role: userRole,
      organizationUserId,
      draftPermissions: Array.from(draftPermissions),
      originalPermissions: Array.from(originalPermissions),
      isDirtyPermissions,
    });

    setSaving(true);
    try {
      // Calculate differences
      const toAdd: string[] = [];
      const toRemove: string[] = [];

      // Find permissions to add
      draftPermissions.forEach(code => {
        if (!originalPermissions.has(code)) {
          toAdd.push(code);
        }
      });

      // Find permissions to remove
      originalPermissions.forEach(code => {
        if (!draftPermissions.has(code)) {
          toRemove.push(code);
        }
      });

      console.log('HANDLE SAVE PERMISSIONS - DIFF', {
        organizationUserId,
        toAdd,
        toRemove,
        toAddCount: toAdd.length,
        toRemoveCount: toRemove.length,
      });

      // Execute inserts and deletes sequentially to better handle errors
      // Add new permissions
      if (toAdd.length > 0) {
        // Filter out duplicates (shouldn't happen, but safety check)
        const uniqueToAdd = Array.from(new Set(toAdd));
        
        const insertRows = uniqueToAdd.map(code => ({
          organization_user_id: organizationUserId,
          permission_code: code,
        }));
        
        const { data, error } = await supabase
          .from('OrganizationUserPermissions')
          .insert(insertRows);
        
        if (error) {
          // Handle duplicate key error (23505) - ignore if it's a duplicate
          if (error.code === '23505') {
            // Duplicate key violation - permission already exists
            // This can happen if the permission was added between load and save
            // Log but don't throw - continue with other inserts
            if (import.meta.env.DEV) {
              console.warn('SAVE PERMISSIONS WARNING (DUPLICATE)', {
                error,
                insertRows,
                message: 'Some permissions already exist, skipping duplicates',
              });
            }
          } else {
            console.error('SAVE PERMISSIONS ERROR (INSERT)', {
              error,
              errorCode: error.code,
              errorMessage: error.message,
              errorDetails: error.details,
              errorHint: error.hint,
              insertRows,
              toAdd: uniqueToAdd,
              organizationUserId,
            });
            throw error; // IMPORTANT: que reviente para que lo veas
          }
        }
      }

      // Remove permissions
      if (toRemove.length > 0) {
        const { data, error } = await supabase
          .from('OrganizationUserPermissions')
          .delete()
          .eq('organization_user_id', organizationUserId)
          .in('permission_code', toRemove);
        
        if (error) {
          console.error('SAVE PERMISSIONS ERROR (DELETE)', {
            error,
            errorCode: error.code,
            errorMessage: error.message,
            errorDetails: error.details,
            errorHint: error.hint,
            toRemove,
            organizationUserId,
          });
          throw error; // IMPORTANT: que reviente para que lo veas
        }
      }

      // Update original permissions to match draft
      setOriginalPermissions(new Set(draftPermissions));

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Permisos guardados',
        message: 'Los permisos se han guardado correctamente.',
      });

      if (onSave) {
        onSave(finish);
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error saving permissions:', err);
      }
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Error al guardar permisos. Por favor, intenta de nuevo.',
      });
    } finally {
      setSaving(false);
    }
  }, [canEdit, saving, isDirtyPermissions, draftPermissions, originalPermissions, organizationUserId, userRole, onSave]);

  // Group and sort permissions by module
  const permissionsByModule = useMemo(() => {
    const grouped = groupPermissionsByModule(permissions);
    const sorted: Record<string, Permission[]> = {};
    
    // Sort modules by MODULE_ORDER
    MODULE_ORDER.forEach(module => {
      if (grouped[module]) {
        sorted[module] = sortPermissions(grouped[module]);
      }
    });
    
    // Add any remaining modules not in MODULE_ORDER
    Object.keys(grouped).forEach(module => {
      if (!sorted[module] && grouped[module]) {
        sorted[module] = sortPermissions(grouped[module]);
      }
    });
    
    return sorted;
  }, [permissions]);

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[200px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Cargando permisos...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">User Permissions</h3>
        {userRole === 'superadmin' ? (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p className="text-sm text-blue-800 font-medium">
              Superadmin has all permissions automatically
            </p>
            <p className="text-xs text-blue-700 mt-1">
              No need to assign individual permissions. All permissions are enabled by default.
            </p>
          </div>
        ) : (
          <p className="text-sm text-gray-600">
            {canEdit 
              ? 'Select the permissions this user can have. Changes will be saved when you press "Save" or "Save & Finish".'
              : 'Only administrators can edit permissions.'}
          </p>
        )}
        {isDirtyPermissions && canEdit && userRole !== 'superadmin' && (
          <div className="mt-2 text-xs text-amber-600">
            You have unsaved changes
          </div>
        )}
      </div>

      {/* Grid of Module Cards */}
      {Object.keys(permissionsByModule).length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 mb-6">
          {Object.entries(permissionsByModule).map(([module, modulePermissions]) => (
            <PermissionModuleCard
              key={module}
              moduleName={module}
              permissions={modulePermissions}
              selectedSet={effectivePermissions}
              onTogglePermission={handleTogglePermission}
              disabled={!canEdit || saving || userRole === 'superadmin'}
            />
          ))}
        </div>
      ) : (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-8 text-center">
          <p className="text-sm text-gray-600">No hay permisos disponibles para mostrar.</p>
        </div>
      )}

      {/* Action Buttons - Only render if showActions is true (parent handles by default) */}
      {showActions && canEdit && (
        <div className="flex items-center justify-end gap-3 pt-4 border-t border-gray-200">
          {onCancel && (
            <button
              type="button"
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                onCancel();
              }}
              disabled={saving}
              className="px-4 py-2 border border-gray-300 text-gray-700 hover:bg-gray-50 transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Cancelar
            </button>
          )}
          {userRole !== 'superadmin' && (
            <>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  console.log('CLICK SAVE BUTTON', { isDirtyPermissions, saving });
                  handleSave(false);
                }}
                disabled={saving || !isDirtyPermissions}
                className="px-4 py-2 bg-primary text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm flex items-center gap-2"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {saving ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                    <span>Guardando...</span>
                  </>
                ) : (
                  <span>Guardar</span>
                )}
              </button>
              <button
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  console.log('CLICK SAVE & FINISH BUTTON', { isDirtyPermissions, saving });
                  handleSave(true);
                }}
                disabled={saving || !isDirtyPermissions}
                className="px-4 py-2 bg-primary text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm flex items-center gap-2"
                style={{ backgroundColor: '#10b981' }}
              >
                {saving ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                    <span>Guardando...</span>
                  </>
                ) : (
                  <span>Guardar y Finalizar</span>
                )}
              </button>
            </>
          )}
        </div>
      )}
    </div>
  );
});

OrganizationUserPermissions.displayName = 'OrganizationUserPermissions';

export default OrganizationUserPermissions;
