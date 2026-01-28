import { useCallback, useEffect, useRef, useState } from "react";
import { supabase } from '../lib/supabase/client';
import type { Session } from "@supabase/supabase-js";

type AuthState = {
  session: Session | null;
  userId: string | null;
  loading: boolean;
  error: string | null;
  reload: () => Promise<void>;
};

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  const timeoutPromise = new Promise<T>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`[auth] timeout: ${label} (${ms}ms)`));
    }, ms);
  });

  return Promise.race([promise, timeoutPromise]).finally(() => {
    if (timeoutId) clearTimeout(timeoutId);
  }) as Promise<T>;
}

// Global flags to prevent duplicate link_my_org_invites calls
let globalLinkingInvitesInProgress = false;
let globalLinkingInvitesTimeout: ReturnType<typeof setTimeout> | null = null;

export function useAuthSession(timeoutMs: number = 8000): AuthState {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const mountedRef = useRef(true);
  const inflightRef = useRef<Promise<void> | null>(null);

  const loadSession = useCallback(async () => {
    // Evita múltiples llamadas paralelas que se pisan y causan loops
    if (inflightRef.current) return inflightRef.current;

    const run = (async () => {
      setLoading(true);
      setError(null);

      try {
        if (import.meta.env.DEV) console.log("[auth] loadSession:start");

        const result = await withTimeout(
          supabase.auth.getSession(),
          timeoutMs,
          "supabase.auth.getSession"
        ) as { data: { session: Session | null } | null; error: Error | null };
        const { data, error: sessionErr } = result;

        if (sessionErr) throw sessionErr;

        // data.session puede ser null y eso es válido (signed out)
        const nextSession: Session | null = data?.session ?? null;

        if (!mountedRef.current) return;
        setSession(nextSession);

        if (import.meta.env.DEV) {
          console.log("[auth] loadSession:done", {
            hasSession: !!nextSession,
            userId: nextSession?.user?.id ?? null,
          });
        }
      } catch (e: any) {
        if (!mountedRef.current) return;

        const msg =
          typeof e?.message === "string" ? e.message : "Failed to load session";
        console.warn("[auth] loadSession:error", msg);
        setSession(null);
        setError(msg);
      } finally {
        if (!mountedRef.current) return;
        setLoading(false);
        inflightRef.current = null;
        if (import.meta.env.DEV) console.log("[auth] loadSession:finally");
      }
    })();

    inflightRef.current = run;
    return run;
  }, [timeoutMs]);

  useEffect(() => {
    mountedRef.current = true;

    // 1) Carga inicial
    void loadSession();

    // 2) Listener: cuando cambia la auth, actualiza rápido sin bloquear
    const { data: sub } = supabase.auth.onAuthStateChange((event: string, nextSession: Session | null) => {
      if (!mountedRef.current) return;
      setSession(nextSession);
      setLoading(false); // IMPORTANT: no dejes loading true por eventos
      setError(null);
      if (import.meta.env.DEV) console.log("[auth] onAuthStateChange", event);

      // Link organization invites when user signs in (only once globally)
      if (event === 'SIGNED_IN' && nextSession?.user?.id && !globalLinkingInvitesInProgress) {
        globalLinkingInvitesInProgress = true;
        
        // Clear any existing timeout
        if (globalLinkingInvitesTimeout) {
          clearTimeout(globalLinkingInvitesTimeout);
        }
        
        (async () => {
          try {
            const { data: linkData, error: linkError } = await supabase.rpc('link_my_org_invites');
            if (linkError) {
              console.error('[useAuthSession] link_my_org_invites error:', linkError);
            } else if (linkData && linkData[0]?.linked_count > 0) {
              console.log('[useAuthSession] ✅ Invites linked:', linkData);
            }
          } catch (err) {
            console.error('[useAuthSession] Error linking invites:', err);
          } finally {
            // Reset global flag after 3 seconds to allow retry if needed
            globalLinkingInvitesTimeout = setTimeout(() => {
              globalLinkingInvitesInProgress = false;
              globalLinkingInvitesTimeout = null;
            }, 3000);
          }
        })();
      }
      
      // Reset global linking flag on sign out
      if (event === 'SIGNED_OUT') {
        globalLinkingInvitesInProgress = false;
        if (globalLinkingInvitesTimeout) {
          clearTimeout(globalLinkingInvitesTimeout);
          globalLinkingInvitesTimeout = null;
        }
      }
    });

    return () => {
      mountedRef.current = false;
      sub?.subscription?.unsubscribe();
    };
  }, [loadSession]);

  return {
    session,
    userId: session?.user?.id ?? null,
    loading,
    error,
    reload: loadSession,
  };
}
