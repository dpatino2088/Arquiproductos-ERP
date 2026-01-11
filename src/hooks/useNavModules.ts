import { useMemo } from 'react';
import { usePermissions, MODULE_PERMS, type ModuleKey } from './usePermissions';

/**
 * Navigation module configuration
 */
export interface NavModule {
  key: ModuleKey;
  name: string;
  href: string;
  icon?: React.ComponentType<{ style?: React.CSSProperties }>;
  canView: boolean;
  canEdit: boolean;
}

/**
 * Hook to get filtered navigation modules based on permissions
 * 
 * @example
 * const { modules, loading } = useNavModules(allNavItems);
 * 
 * {modules.map(module => (
 *   module.canView && <NavItem key={module.key} {...module} />
 * ))}
 */
export function useNavModules(
  allModules: Array<{
    key: ModuleKey | string;
    name: string;
    href: string;
    icon?: React.ComponentType<{ style?: React.CSSProperties }>;
  }>
): { modules: NavModule[]; loading: boolean } {
  const { hasAnyPermission, loading } = usePermissions();

  const modules = useMemo(() => {
    if (loading) {
      return [];
    }

    return allModules
      .filter(module => {
        // Check if module is a valid ModuleKey
        if (!(module.key in MODULE_PERMS)) {
          if (import.meta.env.DEV) {
            console.warn(`⚠️ useNavModules: Unknown module key "${module.key}", skipping`);
          }
          return false;
        }

        const moduleKey = module.key as ModuleKey;
        const modulePerms = MODULE_PERMS[moduleKey];

        // Check view permission
        const canView = hasAnyPermission(modulePerms.view);
        return canView;
      })
      .map(module => {
        const moduleKey = module.key as ModuleKey;
        const modulePerms = MODULE_PERMS[moduleKey];

        const canView = hasAnyPermission(modulePerms.view);
        const canEdit = hasAnyPermission(modulePerms.edit);

        return {
          key: moduleKey,
          name: module.name,
          href: module.href,
          icon: module.icon,
          canView,
          canEdit,
        } as NavModule;
      });
  }, [allModules, hasAnyPermission, loading]);

  return { modules, loading };
}
