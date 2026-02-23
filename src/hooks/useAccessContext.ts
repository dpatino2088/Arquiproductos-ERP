import { useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase/client";
import { useAuthSession } from "./useAuthSession";
import { useOrganizationContext } from "../context/OrganizationContext";

type AccessUserType = "internal" | "portal" | "unknown";
export type PortalRole = "dealer_member" | "dealer_manager";

export type ModuleKey =
  | "dashboard"
  | "directory"
  | "sales"
  | "catalog"
  | "inventory"
  | "manufacturing"
  | "financials"
  | "settings";

type AccessContextState = {
  loading: boolean;
  userType: AccessUserType;

  activeOrganizationId: string | null;
  /** When userType === 'portal', the dealer_id for the current dealer user (from AppUsers/DealerUsers). */
  portalDealerId: string | null;

  internalRole?: string | null;
  portalRole?: PortalRole | null;

  allowedModules: ModuleKey[];
  canApprove: boolean;
  canSeeAllDealerQuotes: boolean;
  canEditDirectory: boolean;

  isInternal: boolean;
  isPortal: boolean;
};

const PORTAL_ALLOWED_MODULES: ModuleKey[] = ["dashboard", "directory", "sales"];

/** Map AppUser.role_code (dealer_manager, dealer_member) or DealerUsers.role to PortalRole */
function roleCodeToPortalRole(v: any): PortalRole | null {
  const s = (v ?? "").toString().trim().toLowerCase();
  if (s === "member" || s === "dealer_member") return "dealer_member";
  if (s === "member_manager" || s === "manager" || s === "dealer_manager") return "dealer_manager";
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
  const [portalDealerId, setPortalDealerId] = useState<string | null>(null);

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
          setPortalDealerId(null);
          setLoading(false);
          setAccessResolved(true);
        }
        return;
      }

      setLoading(true);

      // =========================================================
      // 1) PORTAL: AppUsers first (role from role_code), then Legacy DealerUsers
      // =========================================================
      const appUserOr: string[] = [];
      if (uid) appUserOr.push(`auth_user_id.eq.${uid}`);
      if (jwtEmail) appUserOr.push(`email.ilike.${jwtEmail}`);
      const appUserOrFilter =
        appUserOr.length > 0 ? appUserOr.join(",") : "id.eq.00000000-0000-0000-0000-000000000000";

      const { data: appUserRow, error: appUserErr } = await supabase
        .from("AppUsers")
        .select("id, organization_id, dealer_id, role_code, status, deleted, email")
        .eq("user_type", "dealer")
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .or(appUserOrFilter)
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (!cancelled && appUserRow && !appUserErr) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] Portal user from AppUsers (role_code):", {
            id: appUserRow.id,
            role_code: appUserRow.role_code,
            organization_id: appUserRow.organization_id,
            email: appUserRow.email,
            status: appUserRow.status,
          });
        }
        setUserType("portal");
        setInternalRole(null);
        setPortalDealerId(appUserRow.dealer_id ?? null);
        const normalizedRole = roleCodeToPortalRole(appUserRow.role_code);
        setPortalRole(normalizedRole);
        setPortalOrgId(appUserRow.organization_id ?? null);
        if (import.meta.env.DEV && !normalizedRole) {
          console.warn("[useAccessContext] AppUsers role_code not mapped to PortalRole:", appUserRow.role_code);
        }
        if (!activeOrganizationId && appUserRow.organization_id) {
          setActiveOrganizationId(appUserRow.organization_id);
        }
        setAccessResolved(true);
        setLoading(false);
        return;
      }

      // Legacy: DealerUsers (role from column "role")
      const legacyOrParts: string[] = [];
      if (uid) legacyOrParts.push(`user_id.eq.${uid}`);
      if (jwtEmail) legacyOrParts.push(`portal_user_email.ilike.${jwtEmail}`);
      const legacyOr =
        legacyOrParts.length > 0
          ? legacyOrParts.join(",")
          : "id.eq.00000000-0000-0000-0000-000000000000";

      const { data: cpuRow, error: cpuErr } = await supabase
        .from("DealerUsers")
        .select("id, organization_id, dealer_id, role, status, deleted, portal_user_email, user_id")
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .or(legacyOr)
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (cpuErr && import.meta.env.DEV) {
        console.warn("[useAccessContext] DealerUsers (Legacy) lookup error", {
          message: cpuErr.message,
          code: cpuErr.code,
        });
      }
      if (!cancelled && cpuRow) {
        const status = cpuRow.status;
        if (status === "active" || status === "invited") {
          if (import.meta.env.DEV) {
            console.log("[useAccessContext] Portal user from DealerUsers (Legacy):", {
              id: cpuRow.id,
              role: cpuRow.role,
              organization_id: cpuRow.organization_id,
            });
          }
          setUserType("portal");
          setInternalRole(null);
          setPortalDealerId(cpuRow.dealer_id ?? null);
          const normalizedRole = roleCodeToPortalRole(cpuRow.role);
          setPortalRole(normalizedRole);
          setPortalOrgId(cpuRow.organization_id ?? null);
          if (!activeOrganizationId && cpuRow.organization_id) {
            setActiveOrganizationId(cpuRow.organization_id);
          }
          setAccessResolved(true);
          setLoading(false);
          return;
        }
      }

      // =========================================================
      // 2) INTERNAL — AppUsers (unified: user_type='org', role_code)
      // =========================================================
      const { data: appUserOrgRow, error: appUserOrgErr } = await supabase
        .from("AppUsers")
        .select("organization_id, role_code, status, deleted")
        .eq("auth_user_id", uid)
        .eq("user_type", "org")
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .limit(1)
        .maybeSingle();

      if (!cancelled && appUserOrgRow && !appUserOrgErr) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] Internal user from AppUsers:", {
            organization_id: appUserOrgRow.organization_id,
            role_code: appUserOrgRow.role_code,
            status: appUserOrgRow.status,
          });
        }

        setUserType("internal");
        setInternalRole(appUserOrgRow.role_code ?? null);
        setPortalRole(null);
        setPortalOrgId(null);
        setPortalDealerId(null);

        if (!activeOrganizationId && appUserOrgRow.organization_id) {
          setActiveOrganizationId(appUserOrgRow.organization_id);
        }

        setAccessResolved(true);
        setLoading(false);
        return;
      }

      // Legacy fallback: OrganizationUsers (if no AppUsers org row)
      const { data: ouRow, error: ouErr } = await supabase
        .from("OrganizationUsers")
        .select("organization_id, role, status, deleted")
        .eq("user_id", uid)
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .maybeSingle();

      if (ouErr && import.meta.env.DEV) {
        console.debug("[useAccessContext] OrganizationUsers lookup error", ouErr.code);
      }

      if (!cancelled && ouRow) {
        setUserType("internal");
        setInternalRole(ouRow.role ?? null);
        setPortalRole(null);
        setPortalOrgId(null);
        setPortalDealerId(null);
        if (!activeOrganizationId && ouRow.organization_id) {
          setActiveOrganizationId(ouRow.organization_id);
        }
        setAccessResolved(true);
        setLoading(false);
        return;
      }

      // =========================================================
      // 3) UNKNOWN - No user found in AppUsers (dealer/org), DealerUsers (Legacy), or OrganizationUsers
      // =========================================================
      if (!cancelled) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] No user found in AppUsers, DealerUsers (Legacy), or OrganizationUsers");
        }
        setUserType("unknown");
        setInternalRole(null);
        setPortalRole(null);
        setPortalOrgId(null);
        setPortalDealerId(null);
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
      return ["dashboard", "directory", "sales", "catalog", "inventory", "manufacturing", "financials", "settings"];
    }
    return ["dashboard"];
  }, [userType]);

  const canApprove = useMemo(() => {
    if (userType === "portal") return portalRole === "dealer_manager";
    return true; // Internal users: approve logic tied to permissions
  }, [userType, portalRole]);

  const canSeeAllDealerQuotes = useMemo(() => {
    // Only member_manager portal users can see all dealer quotes
    return userType === "portal" && portalRole === "dealer_manager";
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
      canSeeAllDealerQuotes,
      canEditDirectory,
    });
  }

  return {
    loading: loading || sessionLoading,
    userType,

    activeOrganizationId: resolvedOrgId,
    portalDealerId: userType === "portal" ? portalDealerId : null,

    internalRole,
    portalRole,

    allowedModules,
    canApprove,
    canSeeAllDealerQuotes,
    canEditDirectory,

    isInternal: userType === "internal",
    isPortal: userType === "portal",
  };
}
