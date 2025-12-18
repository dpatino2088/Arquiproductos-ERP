import React, { ReactNode } from 'react';
import { useCurrentOrgRole } from '../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../context/OrganizationContext';
import { router } from '../lib/router';

type RouteGuardProps = {
  children: ReactNode;
  requiredPermission?: 'canManageOrganization' | 'canManageUsers' | 'canCreateQuotes' | 'canViewQuotes' | 'canEditCustomers' | 'canEditContacts' | 'canEditVendors';
  requiredRole?: 'superadmin' | 'owner' | 'admin' | 'member' | 'viewer';
  fallback?: ReactNode;
  redirectTo?: string;
};

/**
 * RouteGuard - Componente para proteger rutas basado en roles y permisos
 * 
 * @example
 * // Proteger ruta que requiere permiso de editar customers
 * <RouteGuard requiredPermission="canEditCustomers">
 *   <CustomerEditPage />
 * </RouteGuard>
 * 
 * @example
 * // Proteger ruta que requiere rol específico
 * <RouteGuard requiredRole="owner">
 *   <OrganizationSettings />
 * </RouteGuard>
 */
export default function RouteGuard({
  children,
  requiredPermission,
  requiredRole,
  fallback,
  redirectTo = '/dashboard',
}: RouteGuardProps) {
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();
  const {
    role,
    loading: roleLoading,
    isSuperAdmin,
    isOwner,
    isAdmin,
    isMember,
    isViewer,
    canManageOrganization,
    canManageUsers,
    canCreateQuotes,
    canViewQuotes,
    canEditCustomers,
    canEditContacts,
    canEditVendors,
  } = useCurrentOrgRole();

  // Mostrar loading mientras se cargan los datos
  if (orgLoading || roleLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-sm text-gray-600">Verificando permisos...</p>
        </div>
      </div>
    );
  }

  // Verificar si hay organización activa
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to continue.</p>
        </div>
      </div>
    );
  }

  // Verificar rol requerido
  if (requiredRole) {
    let hasRequiredRole = false;
    
    switch (requiredRole) {
      case 'superadmin':
        hasRequiredRole = isSuperAdmin;
        break;
      case 'owner':
        hasRequiredRole = isOwner;
        break;
      case 'admin':
        hasRequiredRole = isAdmin;
        break;
      case 'member':
        hasRequiredRole = isMember;
        break;
      case 'viewer':
        hasRequiredRole = isViewer;
        break;
    }

    if (!hasRequiredRole) {
      if (redirectTo) {
        // Redirigir después de un breve delay para mostrar el mensaje
        setTimeout(() => {
          router.navigate(redirectTo);
        }, 2000);
      }

      return (
        fallback || (
          <div className="py-6 px-6">
            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
              <p className="text-sm text-red-800 font-medium">Acceso denegado</p>
              <p className="text-sm text-red-700 mt-1">
                Esta página requiere el rol "{requiredRole}". Tu rol actual es: {role || 'sin rol'}.
              </p>
              {redirectTo && (
                <p className="text-xs text-red-600 mt-2">Redirigiendo...</p>
              )}
            </div>
          </div>
        )
      );
    }
  }

  // Verificar permiso requerido
  if (requiredPermission) {
    let hasPermission = false;

    switch (requiredPermission) {
      case 'canManageOrganization':
        hasPermission = canManageOrganization;
        break;
      case 'canManageUsers':
        hasPermission = canManageUsers;
        break;
      case 'canCreateQuotes':
        hasPermission = canCreateQuotes;
        break;
      case 'canViewQuotes':
        hasPermission = canViewQuotes;
        break;
      case 'canEditCustomers':
        hasPermission = canEditCustomers;
        break;
      case 'canEditContacts':
        hasPermission = canEditContacts;
        break;
      case 'canEditVendors':
        hasPermission = canEditVendors;
        break;
    }

    if (!hasPermission) {
      if (redirectTo) {
        // Redirigir después de un breve delay para mostrar el mensaje
        setTimeout(() => {
          router.navigate(redirectTo);
        }, 2000);
      }

      return (
        fallback || (
          <div className="py-6 px-6">
            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
              <p className="text-sm text-red-800 font-medium">Acceso denegado</p>
              <p className="text-sm text-red-700 mt-1">
                No tienes permisos para acceder a esta página. Se requiere el permiso: "{requiredPermission}".
              </p>
              <p className="text-xs text-gray-600 mt-2">
                Tu rol actual: {role || 'sin rol'}
              </p>
              {redirectTo && (
                <p className="text-xs text-red-600 mt-2">Redirigiendo...</p>
              )}
            </div>
          </div>
        )
      );
    }
  }

  // Si no hay restricciones o se cumplen todas, renderizar children
  return <>{children}</>;
}





