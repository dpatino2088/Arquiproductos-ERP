import { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase/client';
import type { Session } from '@supabase/supabase-js';

/**
 * Central hook for auth session management
 * Prevents multiple calls to supabase.auth.getUser() by maintaining a single session source
 */
export function useAuthSession() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const listenerSetRef = useRef(false);

  useEffect(() => {
    let mounted = true;

    // Load initial session
    const loadSession = async () => {
      try {
        const { data: { session }, error } = await supabase.auth.getSession();
        
        if (!mounted) return;
        
        if (error) {
          if (import.meta.env.DEV) {
            console.warn('[useAuthSession] Error loading session:', error);
          }
          setSession(null);
          setLoading(false);
          return;
        }

        setSession(session);
        setLoading(false);
      } catch (err) {
        if (!mounted) return;
        if (import.meta.env.DEV) {
          console.error('[useAuthSession] Exception loading session:', err);
        }
        setSession(null);
        setLoading(false);
      }
    };

    loadSession();

    // Set up auth state change listener (only once)
    if (!listenerSetRef.current) {
      listenerSetRef.current = true;
      
      const { data: { subscription } } = supabase.auth.onAuthStateChange((event, newSession) => {
        if (!mounted) return;
        
        if (import.meta.env.DEV) {
          console.log('[useAuthSession] Auth state changed:', event);
        }
        
        setSession(newSession);
        
        // If session is cleared, set loading to false
        if (!newSession) {
          setLoading(false);
        }
      });

      return () => {
        mounted = false;
        subscription.unsubscribe();
        listenerSetRef.current = false;
      };
    }

    return () => {
      mounted = false;
    };
  }, []);

  return {
    session,
    user: session?.user ?? null,
    userId: session?.user?.id ?? null,
    loading,
  };
}

