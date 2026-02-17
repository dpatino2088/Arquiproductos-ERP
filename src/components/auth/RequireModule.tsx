import React, { useEffect } from "react";
import { router } from "../../lib/router";
import { useAccessContext, ModuleKey } from "../../hooks/useAccessContext";

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
  const { loading, allowedModules } = useAccessContext();
  const hasAccess = allowedModules.includes(module);

  // Redirect si no tiene acceso (solo cuando loading terminó)
  useEffect(() => {
    if (loading) return;
    if (!hasAccess) {
      if (import.meta.env.DEV) {
        console.log("[RequireModule] Redirecting to /dashboard - module not allowed:", module);
      }
      router.navigate("/dashboard", true);
    }
  }, [loading, module, hasAccess]);

  // ✅ SIEMPRE renderizar children — nunca null.
  // El redirect se maneja por useEffect si no tiene acceso.
  return <>{children}</>;
}
