// src/auth/AuthGate.tsx
// Global route guard component for protected routes
// 
// This component:
// - Checks for valid session
// - Calls get_auth_context() to verify membership
// - Redirects to /login if no session
// - Redirects to /access-denied if no membership
// - Redirects to /set-password if password not set
// - Renders children if all checks pass

import React, { useEffect, useState } from 'react';
import { router } from '../lib/router';
import { supabase } from '../lib/supabase/client';
import { fetchAuthContext, type AuthContextRow } from './authContext';

type Props = {
  children: React.ReactNode;
};

/**
 * AuthGate - Route guard component for protected routes
 * 
 * This component wraps protected routes and ensures:
 * 1. User has a valid session
 * 2. User has active membership (OrganizationUsers or DealerUsers)
 * 3. User has set their password (if required)
 * 
 * If any check fails, redirects appropriately.
 */
export default function AuthGate({ children }: Props) {
  const [loading, setLoading] = useState(true);
  const [sessionUserId, setSessionUserId] = useState<string | null>(null);
  const [ctx, setCtx] = useState<AuthContextRow | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    async function run() {
      try {
        setLoading(true);
        setError(null);

        // 1) Get session
        const { data: sessionData, error: sessionErr } = await supabase.auth.getSession();
        if (sessionErr) {
          console.error('[AuthGate] getSession error:', sessionErr);
          throw sessionErr;
        }

        const uid = sessionData.session?.user?.id ?? null;

        if (!mounted) return;
        setSessionUserId(uid);

        if (!uid) {
          // No session - will redirect to login
          setCtx(null);
          setLoading(false);
          return;
        }

        // 2) Get auth context to verify membership
        const row = await fetchAuthContext(supabase);

        if (!mounted) return;
        setCtx(row);
        setLoading(false);
      } catch (e: any) {
        console.error('[AuthGate] Error:', e);
        if (!mounted) return;
        setError(e?.message ?? 'Unknown error');
        setLoading(false);
      }
    }

    run();

    // Listen for auth state changes (login/logout)
    const { data: subscription } = supabase.auth.onAuthStateChange(() => {
      run();
    });

    return () => {
      mounted = false;
      if (subscription?.subscription) {
        subscription.subscription.unsubscribe();
      }
    };
  }, []);

  // Loading state
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-sm text-muted-foreground">Verifying access...</p>
        </div>
      </div>
    );
  }

  // If no session => redirect to login
  // Preserve current path as next parameter
  if (!sessionUserId) {
    const currentPath = window.location.pathname + window.location.search;
    const next = encodeURIComponent(currentPath);
    router.navigate(`/login?next=${next}`, true);
    return null;
  }

  // If RPC failed, fail closed (deny access)
  if (error) {
    console.error('[AuthGate] Error fetching auth context:', error);
    router.navigate('/access-denied', true);
    return null;
  }

  // If missing ctx (shouldn't happen), fail closed
  if (!ctx) {
    console.warn('[AuthGate] No auth context returned');
    router.navigate('/access-denied', true);
    return null;
  }

  // Invite-only enforcement: if no membership, deny access
  if (!ctx.access_allowed) {
    console.log('[AuthGate] Access denied - no active membership');
    router.navigate('/access-denied', true);
    return null;
  }

  // Mandatory first password
  // Avoid redirect loop if user is already on set-password page
  const currentPath = window.location.pathname;
  if (ctx.needs_password && currentPath !== '/set-password') {
    console.log('[AuthGate] Password not set, redirecting to /set-password');
    router.navigate('/set-password', true);
    return null;
  }

  // All checks passed - render children
  return <>{children}</>;
}
