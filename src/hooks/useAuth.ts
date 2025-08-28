import { useState, useEffect, useCallback } from 'react';
import { validateEmail, validatePassword, generateCSRFToken } from '../lib/security';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

interface LoginCredentials {
  email: string;
  password: string;
}

interface RegisterCredentials extends LoginCredentials {
  name: string;
  confirmPassword: string;
}

export const useAuth = () => {
  // Always return authenticated state with a default user
  const [authState] = useState<AuthState>({
    user: {
      id: '1',
      email: 'user@securecorp.com',
      name: 'Demo User',
      role: 'user'
    },
    isAuthenticated: true,
    isLoading: false,
    error: null
  });

  const [csrfToken] = useState(() => generateCSRFToken());

  const login = useCallback(async (credentials: LoginCredentials) => {
    // No-op function since authentication is bypassed
    console.log('Login bypassed - already authenticated');
  }, []);

  const register = useCallback(async (credentials: RegisterCredentials) => {
    // No-op function since authentication is bypassed
    console.log('Registration bypassed - already authenticated');
  }, []);

  const logout = useCallback(() => {
    // No-op function since authentication is bypassed
    console.log('Logout bypassed - staying authenticated');
  }, []);

  const clearError = useCallback(() => {
    // No-op function since there are no errors in bypassed auth
    console.log('Clear error bypassed - no errors to clear');
  }, []);

  return {
    ...authState,
    login,
    register,
    logout,
    clearError,
    csrfToken
  };
};
