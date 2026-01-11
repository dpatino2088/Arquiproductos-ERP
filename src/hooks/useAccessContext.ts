import { useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase/client";
import { useAuthSession } from "./useAuthSession";
import { useOrganizationContext } from "../context/OrganizationContext";

type AccessUserType = "internal" | "portal" | "unknown";
export type PortalRole = "member" | "member_manager";

export type ModuleKey =
  | "dashboard"
  | "directory"
  | "sales"
  | "catalog"
  | "manufacturing"
  | "financials"
  | "settings";

type AccessContextState = {
  loading: boolean;
  userType: AccessUserType;

  activeOrganizationId: string | null;

  internalRole?: string | null;
  portalRole?: PortalRole | null;

  allowedModules: ModuleKey[];
  canApprove: boolean;
  canSeeAllCompanyQuotes: boolean;
  canEditDirectory: boolean;

  isInternal: boolean;
  isPortal: boolean;
};

const PORTAL_ALLOWED_MODULES: ModuleKey[] = ["dashboard", "directory", "sales"];

function normalizePortalRole(v: any): PortalRole | null {
  const s = (v ?? "").toString().trim().toLowerCase();
  if (s === "member") return "member";
  if (s === "member_manager" || s === "manager") return "member_manager";
  return null;
}

export function useAccessContext(): AccessContextState {
  const { session, loading: sessionLoading } = useAuthSession();
  const { activeOrganizationId, setActiveOrganizationId } = useOrganizationContext();
  const [loading, setLoading] = useState(true);
  const [accessResolved, setAccessResolved] = useState(false); // Prevent infinite loops

  const [userType, setUserType] = useState<AccessUserType>("unknown");
  const [internalRole, setInternalRole] = useState<string | null>(null);

  const [portalRole, setPortalRole] = useState<PortalRole | null>(null);
  const [portalOrgId, setPortalOrgId] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      if (sessionLoading) {
        // Reset resolved flag when session is loading (new session might be coming)
        setAccessResolved(false);
        return;
      }

      const uid = session?.user?.id ?? null;
      const jwtEmail = (session?.user?.email ?? "").toString().trim().toLowerCase();

      if (!uid) {
        if (!cancelled) {
          setUserType("unknown");
          setInternalRole(null);
          setPortalRole(null);
          setPortalOrgId(null);
          setLoading(false);
          setAccessResolved(true);
        }
        return;
      }

      setLoading(true);

      // =========================================================
      // 1) PORTAL FIRST (CompanyPortalUsers)  ✅ (safer)
      // =========================================================
      const orParts: string[] = [];
      if (uid) orParts.push(`user_id.eq.${uid}`);
      if (jwtEmail) orParts.push(`portal_user_email.ilike.${jwtEmail}`);

      const portalOr =
        orParts.length > 0
          ? orParts.join(",")
          : "id.eq.00000000-0000-0000-0000-000000000000";

      const { data: cpuRow, error: cpuErr } = await supabase
        .from("CompanyPortalUsers")
        .select("id, organization_id, role, status, deleted, portal_user_email, user_id")
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .or(portalOr)
        .maybeSingle();

      if (cpuErr) {
        console.error("[useAccessContext] CompanyPortalUsers lookup error", {
          message: cpuErr.message,
          details: cpuErr.details,
          hint: cpuErr.hint,
          code: cpuErr.code,
        });
        // IMPORTANT: set a stable state so it doesn't re-fetch forever
        if (!cancelled) {
          setAccessResolved(true);
          setLoading(false);
          // Continue to check OrganizationUsers instead of returning early
        }
      } else if (!cancelled && cpuRow) {
        // Filter by status (double-check, though query already filters)
        const status = cpuRow.status;
        if (status && status !== 'active' && status !== 'invited') {
          // Not active/invited, continue to check OrganizationUsers
        } else {
          if (import.meta.env.DEV) {
            console.log("[useAccessContext] Portal user found:", {
              id: cpuRow.id,
              role: cpuRow.role,
              organization_id: cpuRow.organization_id,
              email: cpuRow.portal_user_email,
              status: cpuRow.status
            });
          }

          setUserType("portal");
          setInternalRole(null);
          // Use role column (as per actual database schema)
          const normalizedRole = normalizePortalRole(cpuRow.role);
          setPortalRole(normalizedRole);
          setPortalOrgId(cpuRow.organization_id ?? null);

          if (import.meta.env.DEV && !normalizedRole) {
            console.warn("[useAccessContext] role is null or invalid:", cpuRow.role);
          }

          if (!activeOrganizationId && cpuRow.organization_id) {
            setActiveOrganizationId(cpuRow.organization_id);
          }

          setAccessResolved(true);
          setLoading(false);
          return;
        }
      }

      // =========================================================
      // 2) INTERNAL SECOND (OrganizationUsers)
      // =========================================================
      const { data: ouRow, error: ouErr } = await supabase
        .from("OrganizationUsers")
        .select("organization_id, role, status, deleted")
        .eq("user_id", uid)
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .maybeSingle();

      if (ouErr) {
        console.error("[useAccessContext] OrganizationUsers lookup error", {
          message: ouErr.message,
          details: ouErr.details,
          hint: ouErr.hint,
          code: ouErr.code,
        });
        // IMPORTANT: set a stable state so it doesn't re-fetch forever
        if (!cancelled) {
          setUserType("unknown");
          setInternalRole(null);
          setPortalRole(null);
          setPortalOrgId(null);
          setAccessResolved(true);
          setLoading(false);
        }
        return;
      }

      if (!cancelled && ouRow) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] OrganizationUser found:", {
            organization_id: ouRow.organization_id,
            role: ouRow.role,
            status: ouRow.status
          });
        }

        setUserType("internal");
        setInternalRole(ouRow.role ?? null);
        setPortalRole(null);
        setPortalOrgId(null);

        if (!activeOrganizationId && ouRow.organization_id) {
          setActiveOrganizationId(ouRow.organization_id);
        }

        setAccessResolved(true);
        setLoading(false);
        return;
      }

      // =========================================================
      // 3) UNKNOWN - No user found in either table
      // =========================================================
      if (!cancelled) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] No user found in CompanyPortalUsers or OrganizationUsers");
        }
        setUserType("unknown");
        setInternalRole(null);
        setPortalRole(null);
        setPortalOrgId(null);
        setAccessResolved(true);
        setLoading(false);
      }
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [
    sessionLoading,
    session?.user?.id,
    session?.user?.email,
    // Note: activeOrganizationId and setActiveOrganizationId removed from deps to prevent loops
    // accessResolved is managed internally and resets when user changes
  ]);

  // Reset accessResolved when user changes (so we can re-fetch for new user)
  useEffect(() => {
    setAccessResolved(false);
  }, [session?.user?.id, session?.user?.email]);

  const resolvedOrgId = activeOrganizationId ?? portalOrgId ?? null;

  const allowedModules = useMemo<ModuleKey[]>(() => {
    if (userType === "portal") return PORTAL_ALLOWED_MODULES;
    if (userType === "internal") {
      return ["dashboard", "directory", "sales", "catalog", "manufacturing", "financials", "settings"];
    }
    return ["dashboard"];
  }, [userType]);

  const canApprove = useMemo(() => {
    if (userType === "portal") return portalRole === "member_manager";
    return true; // Internal users: approve logic tied to permissions
  }, [userType, portalRole]);

  const canSeeAllCompanyQuotes = useMemo(() => {
    // Only member_manager portal users can see all company quotes
    // member portal users can only see their own quotes
    return userType === "portal" && portalRole === "member_manager";
  }, [userType, portalRole]);

  const canEditDirectory = useMemo(() => {
    // Both portal roles (member and member_manager) can edit Directory
    return userType === "portal";
  }, [userType]);

  if (import.meta.env.DEV) {
    console.log("[AccessContext]", {
      userType,
      activeOrganizationId: resolvedOrgId,
      internalRole,
      portalRole,
      allowedModules,
      canApprove,
      canSeeAllCompanyQuotes,
      canEditDirectory,
    });
  }

  return {
    loading: loading || sessionLoading,
    userType,

    activeOrganizationId: resolvedOrgId,

    internalRole,
    portalRole,

    allowedModules,
    canApprove,
    canSeeAllCompanyQuotes,
    canEditDirectory,

    isInternal: userType === "internal",
    isPortal: userType === "portal",
  };
}
