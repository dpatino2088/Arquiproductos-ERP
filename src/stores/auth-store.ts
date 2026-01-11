import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { logger } from '../lib/logger';
import { errorTracker } from '../lib/error-tracker';
import { externalMonitoring } from '../lib/external-monitoring';
import { supabase, getUserProfile } from '../lib/supabase/client';
import type { User as SupabaseUser } from '@supabase/supabase-js';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
  department?: string;
  position?: string;
}

interface AuthState {
  // State
  user: User | null;
  accessToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;

  // Actions
  init: () => Promise<void>;
  setAuth: (user: User, token: string) => void;
  clearAuth: () => Promise<void>;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  updateUser: (userData: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      // Initial state - Start as loading to check session
      user: null,
      accessToken: null,
      isAuthenticated: false,
      isLoading: true, // Start as loading to check session
      error: null,

      // Initialize: Check for existing session
      init: async () => {
        // Helper: Wrap promise with timeout and proper error handling
        const withTimeout = async <T>(
          promise: Promise<T>,
          ms: number,
          label: string
        ): Promise<T> => {
          const timeoutPromise = new Promise<T>((_, reject) => {
            setTimeout(() => {
              if (import.meta.env.DEV) {
                console.warn(`[auth] timeout ${label} after ${ms}ms`);
              }
              reject(new Error(`${label} timeout after ${ms}ms`));
            }, ms);
          });

          return Promise.race([promise, timeoutPromise]);
        };

        try {
          // #region agent log
          fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:65',message:'init() ENTRY - setting loading=true',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
          // #endregion
          set({ isLoading: true, error: null });
          
          if (import.meta.env.DEV) {
            console.log('[auth] step: init start');
          }

          // Check if Supabase is configured
          const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
          const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
          
          if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes('placeholder')) {
            // If Supabase is not configured, set default demo state
            logger.warn('Supabase not configured, using demo mode');
            set({ 
              isLoading: false,
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: null,
            });
            return;
          }
          
          // Check for existing session with timeout (5000ms = 5 seconds)
          if (import.meta.env.DEV) {
            console.log('[auth] step: getSession start');
          }

          // #region agent log
          fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:94',message:'BEFORE getSession await',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
          // #endregion
          let sessionResult;
          try {
            sessionResult = await withTimeout(
              supabase.auth.getSession(),
              5000,
              'getSession'
            );
            // #region agent log
            fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:102',message:'AFTER getSession await - SUCCESS',data:{hasSession:!!sessionResult?.data?.session},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
            // #endregion
          } catch (timeoutError) {
            // #region agent log
            fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:106',message:'getSession TIMEOUT CATCH - setting loading=false',data:{errorMsg:timeoutError instanceof Error?timeoutError.message:String(timeoutError)},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
            // #endregion
            if (import.meta.env.DEV) {
              console.warn('[auth] getSession timeout or failed:', timeoutError);
            }
            // Session check failed - treat as no session
            set({ 
              isLoading: false, 
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: timeoutError instanceof Error ? timeoutError.message : 'Session check failed',
            });
            return;
          }

          if (import.meta.env.DEV) {
            console.log('[auth] step: getSession done', sessionResult?.data?.session ? 'session found' : 'no session');
          }

          const { data: { session }, error: sessionError } = sessionResult || { data: { session: null }, error: null };
          
          if (sessionError) {
            if (import.meta.env.DEV) {
              console.error('[auth] Error getting session:', sessionError);
            }
            logger.error('Error getting session', sessionError as Error);
            set({ 
              isLoading: false, 
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: sessionError.message || 'Failed to get session',
            });
            return;
          }
          
          if (session?.user) {
            // Set basic user immediately for fast UI
            const basicUser: User = {
              id: session.user.id,
              email: session.user.email || '',
              name: session.user.user_metadata?.name || session.user.email || '',
              role: 'user',
            };
            get().setAuth(basicUser, session.access_token);

            if (import.meta.env.DEV) {
              console.log('[auth] step: fetchProfile start');
            }

            // Load profile in background with timeout
            try {
              const profile = await withTimeout(
                getUserProfile(session.user.id),
                5000,
                'getUserProfile'
              );

              if (import.meta.env.DEV) {
                console.log('[auth] step: fetchProfile done', profile ? 'profile found' : 'no profile');
              }

              if (profile) {
                const updatedUser: User = {
                  id: session.user.id,
                  email: session.user.email || '',
                  name: profile.name || session.user.user_metadata?.name || session.user.email || '',
                  role: (profile.role as 'user' | 'admin') || 'user',
                  department: profile.department,
                  position: profile.position,
                };
                set({ user: updatedUser });
              }
            } catch (profileError) {
              if (import.meta.env.DEV) {
                console.warn('[auth] Profile fetch failed (non-critical):', profileError);
              }
              // ignore profile errors for speed - we already have basic user
            } finally {
              // #region agent log
              fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:179',message:'PROFILE FETCH FINALLY - setting loading=false',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'B'})}).catch(()=>{});
              // #endregion
              // Always set loading to false after profile attempt
              set({ isLoading: false });
            }
          } else {
            // No session - user is signed out
            // #region agent log
            fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:187',message:'NO SESSION PATH - setting loading=false',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'B'})}).catch(()=>{});
            // #endregion
            if (import.meta.env.DEV) {
              console.log('[auth] step: no session -> signedOut');
            }
            set({ 
              isLoading: false, 
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: null,
            });
          }

          // Subscribe to auth state changes once - ALWAYS set up listener
          // This is critical to capture login/logout/token refresh events
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const storeAny: any = useAuthStore as any;
          if (!storeAny.__authListenerSet) {
            const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
              // Reducir logging para disminuir overhead
              if (import.meta.env.DEV) {
                console.log('🔔 Auth state change:', event, session?.user?.email);
              }
              
              // Handle password recovery - DO NOT auto-redirect or set auth
              // The AuthCallback component will handle the redirect to /auth/reset-password
              if (event === 'PASSWORD_RECOVERY') {
                // Reducir logging
                if (import.meta.env.DEV) {
                  console.log('🔐 Password recovery event detected - AuthCallback will handle redirect');
                }
                // Don't set auth in store - user needs to complete password reset first
                // Don't redirect - AuthCallback component handles this
                return;
              }
              
              // Handle USER_UPDATED (after password change) - don't auto-set auth during recovery
              if (event === 'USER_UPDATED') {
                // Reducir logging
                if (import.meta.env.DEV) {
                  console.log('🔐 User updated event');
                }
                // If we're in the recovery flow, don't auto-set auth
                // The ResetPasswordForm component will handle sign out after password update
                if (window.location.pathname.includes('/auth/reset-password') || 
                    window.location.pathname.includes('/new-password')) {
                  if (import.meta.env.DEV) {
                    console.log('✅ Password updated during recovery flow - ResetPasswordForm will handle');
                  }
                  return;
                }
              }
              
              if (event === 'SIGNED_IN' && session?.user) {
                // Reducir logging
                if (import.meta.env.DEV) {
                  console.log('✅ User signed in:', session.user.email);
                }
                const basicUser: User = {
                  id: session.user.id,
                  email: session.user.email || '',
                  name: session.user.user_metadata?.name || session.user.email || '',
                  role: 'user',
                };
                get().setAuth(basicUser, session.access_token);
                // Background enrich
                getUserProfile(session.user.id)
                  .then((profile) => {
                    if (!profile) return;
                    set({
                      user: {
                        id: session.user.id,
                        email: session.user.email || '',
                        name: profile.name || session.user.email || '',
                        role: (profile.role as 'user' | 'admin') || 'user',
                        department: profile.department,
                        position: profile.position,
                      },
                    });
                  })
                  .catch(() => {});
              } else if (event === 'SIGNED_OUT') {
                // Reducir logging
                if (import.meta.env.DEV) {
                  console.log('👋 User signed out');
                }
                set({
                  user: null,
                  accessToken: null,
                  isAuthenticated: false,
                  error: null,
                  isLoading: false,
                });
              }
            });
            storeAny.__authListenerSet = subscription;
            if (import.meta.env.DEV) {
              console.log('✅ Auth state listener established');
            }
          } else {
            if (import.meta.env.DEV) {
              console.log('ℹ️ Auth state listener already exists');
            }
          }
        } catch (error) {
          // #region agent log
          fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:208',message:'init() CATCH BLOCK - error caught',data:{errorMsg:error instanceof Error?error.message:String(error)},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
          // #endregion
          if (import.meta.env.DEV) {
            console.error('[auth] Error initializing auth:', error);
          }
          logger.error('Error initializing auth', error as Error);
          
          // #region agent log
          fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:216',message:'CATCH PATH - setting loading=false',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
          // #endregion
          // Always set loading to false, even on error
          set({ 
            isLoading: false,
            isAuthenticated: false,
            user: null,
            accessToken: null,
            error: error instanceof Error ? error.message : 'Failed to initialize auth',
          });
          
          // Still try to set up listener even on error (but don't block)
          const storeAny: any = useAuthStore as any;
          if (!storeAny.__authListenerSet) {
            try {
              const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
                if (import.meta.env.DEV) {
                  console.log('🔔 Auth state change (fallback listener):', event, session?.user?.email);
                }
                if (event === 'SIGNED_IN' && session?.user) {
                  const basicUser: User = {
                    id: session.user.id,
                    email: session.user.email || '',
                    name: session.user.user_metadata?.name || session.user.email || '',
                    role: 'user',
                  };
                  get().setAuth(basicUser, session.access_token);
                } else if (event === 'SIGNED_OUT') {
                  set({
                    user: null,
                    accessToken: null,
                    isAuthenticated: false,
                    error: null,
                    isLoading: false,
                  });
                }
              });
              storeAny.__authListenerSet = subscription;
              if (import.meta.env.DEV) {
                console.log('✅ Fallback auth state listener established');
              }
            } catch (listenerError) {
              if (import.meta.env.DEV) {
                console.error('❌ Failed to establish fallback auth listener:', listenerError);
              }
            }
          }
        } finally {
          // #region agent log
          fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:248',message:'init() FINALLY BLOCK ENTRY',data:{currentLoading:get().isLoading},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
          // #endregion
          // GUARANTEE: loading is always false after init completes (even if listener setup fails)
          // This prevents infinite loading states
          const currentState = get();
          if (currentState.isLoading) {
            // #region agent log
            fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:252',message:'FINALLY - forcing loading=false (safety net)',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
            // #endregion
            if (import.meta.env.DEV) {
              console.warn('[auth] Forcing loading=false in finally block (should not happen)');
            }
            set({ isLoading: false });
          } else {
            // #region agent log
            fetch('http://127.0.0.1:7242/ingest/ad52049f-725d-41d8-812c-491bc7b292e1',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'auth-store.ts:258',message:'FINALLY - loading already false',data:{},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'E'})}).catch(()=>{});
            // #endregion
          }
        }
      },

      // Actions
      setAuth: (user: User, token: string) => {
        logger.info('User authenticated', { userId: user.id, email: user.email });
        
        // Set user context for external monitoring
        externalMonitoring.setUser({
          id: user.id,
          email: user.email,
          name: user.name,
        });
        
        set({
          user,
          accessToken: token,
          isAuthenticated: true,
          error: null,
        });
      },

      clearAuth: async () => {
        const currentUser = get().user;
        logger.info('User logged out', { userId: currentUser?.id });
        
        // Sign out from Supabase
        try {
          await supabase.auth.signOut();
        } catch (error) {
          logger.error('Error signing out from Supabase', error as Error);
        }
        
        set({
          user: null,
          accessToken: null,
          isAuthenticated: false,
          error: null,
        });
      },

      setLoading: (loading: boolean) => {
        set({ isLoading: loading });
      },

      setError: (error: string | null) => {
        if (error) {
          logger.error('Auth error occurred', new Error(error));
          errorTracker.trackError(new Error(error), {
            component: 'auth-store',
            action: 'setError',
          });
        }
        set({ error });
      },

      updateUser: (userData: Partial<User>) => {
        const currentUser = get().user;
        if (!currentUser) {
          logger.warn('Attempted to update user data when no user is authenticated');
          return;
        }

        const updatedUser = { ...currentUser, ...userData };
        logger.info('User data updated', { 
          userId: currentUser.id, 
          updatedFields: Object.keys(userData) 
        });
        
        set({ user: updatedUser });
      },
    }),
    {
      name: 'auth-storage',
      // Only persist non-sensitive data
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated,
        // Note: We don't persist the access token for security
      }),
    }
  )
);
