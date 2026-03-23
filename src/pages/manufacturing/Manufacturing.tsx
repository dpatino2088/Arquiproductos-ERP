import { useEffect } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { usePermissions, useManufacturingAccess } from '../../hooks/usePermissions';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';

export default function Manufacturing() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();
  const { can, loading: permissionsLoading } = usePermissions();
  const { activeOrganizationId, hasOrganizations, loading: orgLoading } = useOrganizationContext();

  useEffect(() => {
    const currentPath = window.location.pathname;
    
    if (currentPath.startsWith('/manufacturing')) {
      // Register submodules without clearing first (let individual components handle it)
      // This ensures tabs are visible when navigating directly to sub-routes
      registerSubmodules('Manufacturing', filteredSubmodules);
      
      if (currentPath === '/manufacturing' || currentPath === '/manufacturing/') {
        const firstTab = filteredSubmodules[0];
        router.navigate(firstTab?.href ?? '/manufacturing/work-orders');
      }
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  // Check permissions — allow if user has legacy or any granular manufacturing permission
  if (!permissionsLoading && filteredSubmodules.length === 0) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">Sin permisos</p>
          <p className="text-sm text-yellow-700 mt-1">
            No tienes permisos para acceder al módulo de Manufacturing. 
            Contacta a un administrador para solicitar acceso.
          </p>
        </div>
      </div>
    );
  }

  if (!orgLoading && !hasOrganizations) {
    return <NoOrganizationMessage />;
  }

  return null;
}
