import React, { useEffect } from "react";
import { router } from "../../lib/router";
import { useAccessContext, ModuleKey } from "../../hooks/useAccessContext";

export function RequireModule({
  module,
  children,
}: {
  module: ModuleKey;
  children: React.ReactNode;
}) {
  const { loading, allowedModules } = useAccessContext();

  // ✅ LOG C) Debug output
  if (import.meta.env.DEV) {
    console.log("[RequireModule]", { module, allowedModules, loading, hasAccess: allowedModules.includes(module) });
  }

  useEffect(() => {
    if (loading) return;
    if (!allowedModules.includes(module)) {
      // ✅ CORRECCIÓN: Usar router personalizado con replace=true (previene loop)
      if (import.meta.env.DEV) {
        console.log("[RequireModule] Redirecting to /dashboard - module not allowed:", module);
      }
      router.navigate("/dashboard", true); // true = replace (previene back button issues)
    }
  }, [loading, module, allowedModules]);

  if (loading) return null;
  if (!allowedModules.includes(module)) {
    // Return null during redirect to prevent flash of content
    return null;
  }

  return <>{children}</>;
}
