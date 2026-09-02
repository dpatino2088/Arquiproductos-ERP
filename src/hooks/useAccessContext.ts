import { useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase/client";
import { useAuthSession } from "./useAuthSession";
import { useOrganizationContext } from "../context/OrganizationContext";
import { useActingAsDealer } from "./useActingAsDealer";

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
  | "partners"
  | "service"
  | "reports"
  | "settings";

export type PortalMembership = {
  dealerId: string;
  roleCode: string | null;
};

type AccessContextState = {
  loading: boolean;
  userType: AccessUserType;

  activeOrganizationId: string | null;
  /** When userType === 'portal', the ACTIVE dealer_id for the current dealer user
   *  (follows the selected membership when the user belongs to several dealers). */
  portalDealerId: string | null;
  /** All dealer memberships of the portal user (1 row per dealer). Empty for internal users. */
  portalMemberships: PortalMembership[];

  internalRole?: string | null;
  portalRole?: PortalRole | null;

  allowedModules: ModuleKey[];
  canApprove: boolean;
  canSeeAllDealerQuotes: boolean;
  canEditDirectory: boolean;

  isInternal: boolean;
  isPortal: boolean;
};

const PORTAL_ALLOWED_MODULES: ModuleKey[] = ["dashboard", "directory", "sales", "financials", "service"];

/**
 * Map role_code string to PortalRole.
 * Only `dealer_manager` and `dealer_member` are valid portal roles.
 * Legacy values (`manager`, `member_manager`, `member`) are no longer supported.
 */
function roleCodeToPortalRole(v: any): PortalRole | null {
  const s = (v ?? "").toString().trim().toLowerCase();
  if (s === "dealer_manager") return "dealer_manager";
  if (s === "dealer_member") return "dealer_member";
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
  const [portalMemberships, setPortalMemberships] = useState<PortalMembership[]>([]);

  // Active dealer (DB-persisted). For multi-dealer portal users this is the
  // membership they selected in the header switcher.
  const { activeDealerId: actingDealerId } = useActingAsDealer();

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
          setPortalMemberships([]);
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

      // One row per dealer membership (a portal user may belong to several dealers).
      const { data: appUserRows, error: appUserErr } = await supabase
        .from("AppUsers")
        .select("id, organization_id, dealer_id, role_code, status, deleted, email")
        .eq("user_type", "dealer")
        .eq("deleted", false)
        .in("status", ["active", "invited"])
        .or(appUserOrFilter)
        .order("created_at", { ascending: true });

      const appUserRow = (appUserRows ?? [])[0] ?? null;
      if (!cancelled && appUserRow && !appUserErr) {
        if (import.meta.env.DEV) {
          console.log("[useAccessContext] Portal user from AppUsers (role_code):", {
            id: appUserRow.id,
            role_code: appUserRow.role_code,
            organization_id: appUserRow.organization_id,
            email: appUserRow.email,
            status: appUserRow.status,
            memberships: (appUserRows ?? []).length,
          });
        }
        setUserType("portal");
        setInternalRole(null);
        setPortalMemberships(
          (appUserRows ?? [])
            .filter((r: { dealer_id: string | null }) => r.dealer_id)
            .map((r: { dealer_id: string | null; role_code: string | null }) => ({
              dealerId: r.dealer_id as string,
              roleCode: r.role_code ?? null,
            }))
        );
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
          setPortalMemberships(
            cpuRow.dealer_id ? [{ dealerId: cpuRow.dealer_id, roleCode: cpuRow.role ?? null }] : []
          );
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
        setPortalMemberships([]);

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
        setPortalMemberships([]);
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
        setPortalMemberships([]);
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

  // Multi-dealer portal users: the effective dealer (and its role — a user can be
  // manager at one dealer and member at another) follows the ACTIVE membership
  // selected via the header switcher (persisted in DB by set_acting_dealer).
  const activeMembership = useMemo(() => {
    if (userType !== "portal" || portalMemberships.length === 0) return null;
    return (
      (actingDealerId ? portalMemberships.find((m) => m.dealerId === actingDealerId) : null) ??
      portalMemberships[0]
    );
  }, [userType, portalMemberships, actingDealerId]);

  const effectivePortalDealerId = activeMembership?.dealerId ?? portalDealerId;
  const effectivePortalRole = activeMembership
    ? roleCodeToPortalRole(activeMembership.roleCode) ?? portalRole
    : portalRole;

  const allowedModules = useMemo<ModuleKey[]>(() => {
    if (userType === "portal") return PORTAL_ALLOWED_MODULES;
    if (userType === "internal") {
      return ["dashboard", "directory", "sales", "catalog", "inventory", "manufacturing", "financials", "partners", "service", "reports", "settings"];
    }
    return ["dashboard"];
  }, [userType]);

  const canApprove = useMemo(() => {
    if (userType === "portal") return effectivePortalRole === "dealer_manager";
    return true; // Internal users: approve logic tied to permissions
  }, [userType, effectivePortalRole]);

  const canSeeAllDealerQuotes = useMemo(() => {
    // Only dealer_manager portal users can see all dealer quotes
    return userType === "portal" && effectivePortalRole === "dealer_manager";
  }, [userType, effectivePortalRole]);

  const canEditDirectory = useMemo(() => {
    // Both portal roles (dealer_member and dealer_manager) can edit Directory
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
    portalDealerId: userType === "portal" ? effectivePortalDealerId : null,
    portalMemberships: userType === "portal" ? portalMemberships : [],

    internalRole,
    portalRole: effectivePortalRole,

    allowedModules,
    canApprove,
    canSeeAllDealerQuotes,
    canEditDirectory,

    isInternal: userType === "internal",
    isPortal: userType === "portal",
  };
}
