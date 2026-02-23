import { create } from "zustand";
import { persist } from "zustand/middleware";
import { logger } from "../lib/logger";
import { errorTracker } from "../lib/error-tracker";
import { externalMonitoring } from "../lib/external-monitoring";
import { supabase, getUserProfile } from "../lib/supabase/client";

interface User {
  id: string;
  email: string;
  name: string;
  role: "user" | "admin";
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
  syncSession: () => Promise<void>; // Force sync without auth flow page check
  setAuth: (user: User, token: string | null) => void;
  clearAuth: () => Promise<void>;
  hardClearAuthStorage: () => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  updateUser: (userData: Partial<User>) => void;
}

const DEMO_MODE = () => {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
  return !supabaseUrl || !supabaseAnonKey || supabaseUrl.includes("placeholder");
};

// 🔥 Hard clear sb auth keys (cuando Supabase se queda "pegado" en storage)
const hardClearAuthStorage = () => {
  try {
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const k = localStorage.key(i);
      if (k && k.startsWith("sb-") && k.includes("auth")) localStorage.removeItem(k);
    }
  } catch {}
  try {
    for (let i = sessionStorage.length - 1; i >= 0; i--) {
      const k = sessionStorage.key(i);
      if (k && k.startsWith("sb-") && k.includes("auth")) sessionStorage.removeItem(k);
    }
  } catch {}
};

// ✅ Helper: check if current path is an auth flow page
function isAuthFlowPage(): boolean {
  if (typeof window === 'undefined') return false;
  
  const path = window.location.pathname;
  const authPaths = [
    '/login',
    '/signup',
    '/auth/',
    '/set-password',
    '/reset-password',
    '/new-password',
    '/company-registration',
  ];
  
  return authPaths.some(p => path.startsWith(p));
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      isAuthenticated: false,
      isLoading: false, // ✅ Start with false (será true solo si init() corre)
      error: null,

      hardClearAuthStorage: () => hardClearAuthStorage(),

      syncSession: async () => {
        // ✅ Force session sync (used by AuthCallback) - NO auth page check
        set({ isLoading: true, error: null });

        try {
          if (DEMO_MODE()) {
            set({ isLoading: false, isAuthenticated: false, user: null, accessToken: null });
            return;
          }

          const { data: { user: sbUser }, error: userError } = await supabase.auth.getUser();

          if (userError || !sbUser) {
            set({ isLoading: false, isAuthenticated: false, user: null, accessToken: null });
            return;
          }

          const { data: { session } } = await supabase.auth.getSession();
          const token = session?.access_token ?? null;

          const basicUser: User = {
            id: sbUser.id,
            email: sbUser.email || "",
            name: (sbUser.user_metadata as any)?.name || sbUser.email || "",
            role: "user",
          };

          get().setAuth(basicUser, token);

          set({ isLoading: false });
        } catch (error) {
          console.error("[auth-store] syncSession error:", error);
          set({ isLoading: false, isAuthenticated: false, user: null, accessToken: null });
        }
      },

      init: async () => {
        // ✅ CRITICAL: Skip auth init completely on auth flow pages
        if (isAuthFlowPage()) {
          console.log('[auth-store] Skipping init on auth flow page:', window.location.pathname);
          set({ isLoading: false, error: null });
          return;
        }

        set({ isLoading: true, error: null });

        try {
          if (DEMO_MODE()) {
            logger.warn("Supabase not configured, using demo mode");
            set({
              isLoading: false,
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: null,
            });
            return;
          }

          // Get user from Supabase (with short timeout)
          const { data: { user: sbUser }, error: userError } = await supabase.auth.getUser();

          if (userError || !sbUser) {
            // No user => signed out
            set({
              isLoading: false,
              isAuthenticated: false,
              user: null,
              accessToken: null,
              error: null,
            });
            return;
          }

          // Get session for token
          const { data: { session } } = await supabase.auth.getSession();
          const token = session?.access_token ?? null;

          // Set basic user first (fast UI update)
            const basicUser: User = {
              id: sbUser.id,
              email: sbUser.email || "",
            name: (sbUser.user_metadata as any)?.name || sbUser.email || "",
              role: "user",
            };

            get().setAuth(basicUser, token);

          // ✅ Enrich profile in background (non-blocking)
          // ✅ Guard: solo busca profile si userId existe
          const userId = sbUser.id;
          if (userId) {
            getUserProfile(userId)
              .then((profile) => {
                // ✅ NO revientes la app por profile missing
                if (!profile) return;
                set({
                  user: {
                    id: sbUser.id,
                    email: sbUser.email || "",
                    name: profile.name || sbUser.email || "",
                    role: (profile.role as "user" | "admin") || "user",
                    department: profile.department,
                    position: profile.position,
                  },
                });
              })
              .catch((e) => {
                // ✅ Log warning pero NO bloquees
                console.warn("[auth-store] profile read warning:", e instanceof Error ? e.message : String(e));
              })
              .finally(() => {
                // ✅ CLAVE: SIEMPRE apaga loading
              set({ isLoading: false });
              });
          } else {
            // ✅ Si no hay userId, apaga loading de inmediato
            set({ isLoading: false });
              }

        } catch (error) {
          console.error("[auth-store] init error:", error);
          logger.error("Error initializing auth", error as Error);
          set({
            isLoading: false,
            isAuthenticated: false,
            user: null,
            accessToken: null,
            error: error instanceof Error ? error.message : "Failed to initialize auth",
          });
        }
      },

      setAuth: (user: User, token: string | null) => {
        set({
          user,
          accessToken: token,
          isAuthenticated: true,
          isLoading: false,
          error: null,
        });

        // Track user
        if (user) {
          try {
            externalMonitoring.setUser({
              id: user.id,
              email: user.email,
              name: user.name,
            });
          } catch (e) {
            logger.error("Error setting user in tracking", e instanceof Error ? e : new Error(String(e)));
          }
        }
      },

      clearAuth: async () => {
        try {
          await supabase.auth.signOut();
        } catch (error) {
          logger.error("Error signing out", error as Error);
        }
        try {
          const { clearDirectoryContextCache } = await import('../lib/directoryContext');
          clearDirectoryContextCache();
        } catch { /* ignore */ }

        set({
          user: null,
          accessToken: null,
          isAuthenticated: false,
          isLoading: false,
          error: null,
        });
      },

      setLoading: (loading: boolean) => {
        set({ isLoading: loading });
      },

      setError: (error: string | null) => {
        set({ error, isLoading: false });
      },

      updateUser: (userData: Partial<User>) => {
        const currentUser = get().user;
        if (currentUser) {
          set({ user: { ...currentUser, ...userData } });
        }
      },
    }),
    {
      name: "auth-storage",
      partialize: (state) => ({
        user: state.user,
        accessToken: state.accessToken,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
