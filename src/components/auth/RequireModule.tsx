import React, { useEffect } from "react";
import { router } from "../../lib/router";
import { useAccessContext, ModuleKey } from "../../hooks/useAccessContext";
import { MODULE_PERMS, usePermissions } from "../../hooks/usePermissions";

/**
 * RequireModule — NUNCA retorna null.
 * Siempre renderiza children para evitar flash.
 * Si el usuario no tiene acceso, redirige vía useEffect (sin desmontar UI).
 */
export function RequireModule({
  module,
  children,
}: {
  module: ModuleKey;
  children: React.ReactNode;
}) {
  const { loading, allowedModules, userType } = useAccessContext();
  const { loading: permissionsLoading, can } = usePermissions();
  const hasModuleAccess = allowedModules.includes(module);
  const modulePerms = MODULE_PERMS[module];
  const hasPermissionAccess = modulePerms.view.some((perm) => can(perm));
  // Portal users are gated by allowedModules + table-level RLS.
  // Internal users require both module-level allowlist and explicit RBAC permission checks.
  const hasAccess = userType === 'portal'
    ? hasModuleAccess
    : (hasModuleAccess && hasPermissionAccess);

  // Redirect si no tiene acceso (solo cuando loading terminó)
  useEffect(() => {
    if (loading || permissionsLoading) return;
    if (!hasAccess) {
      if (import.meta.env.DEV) {
        console.log("[RequireModule] Redirecting to /dashboard - module not allowed:", module);
      }
      router.navigate("/dashboard", true);
    }
  }, [loading, permissionsLoading, module, hasAccess]);

  // ✅ SIEMPRE renderizar children — nunca null.
  // El redirect se maneja por useEffect si no tiene acceso.
  return <>{children}</>;
}
