/**
 * SuperAdminActingGate — pass-through.
 *
 * With DB-persisted acting-as (AppUserPreferences + set_acting_dealer RPC),
 * dealer validation is handled server-side. No client-side gating needed.
 */
export function SuperAdminActingGate({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
