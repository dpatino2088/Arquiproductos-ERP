import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { logger } from '../lib/logger';
import { errorTracker } from '../lib/error-tracker';
import { externalMonitoring } from '../lib/external-monitoring';

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
  setAuth: (user: User, token: string) => void;
  clearAuth: () => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  updateUser: (userData: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      // Initial state
      user: {
        id: '1',
        email: 'user@securecorp.com',
        name: 'Demo User',
        role: 'user',
      },
      accessToken: 'demo_token',
      isAuthenticated: true,
      isLoading: false,
      error: null,

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

      clearAuth: () => {
        const currentUser = get().user;
        logger.info('User logged out', { userId: currentUser?.id });
        
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
