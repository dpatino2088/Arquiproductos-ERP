import { useCallback } from 'react';
import { useAuthStore } from '../stores/auth-store';
import { generateCSRFToken } from '../lib/security';
import { logger } from '../lib/logger';
import { LoginFormData, RegistrationFormData } from '../lib/validation';

export const useAuth = () => {
  const {
    user,
    accessToken,
    isAuthenticated,
    isLoading,
    error,
    setError,
    updateUser,
  } = useAuthStore();

  const login = useCallback(async (credentials: LoginFormData) => {
    // No-op function since authentication is bypassed
    logger.info('Login bypassed - already authenticated', { email: credentials.email });
  }, []);

  const register = useCallback(async (credentials: RegistrationFormData) => {
    // No-op function since authentication is bypassed
    logger.info('Registration bypassed - already authenticated', { email: credentials.email });
  }, []);

  const logout = useCallback(() => {
    // No-op function since authentication is bypassed
    logger.info('Logout bypassed - staying authenticated');
  }, []);

  const clearError = useCallback(() => {
    setError(null);
  }, [setError]);

  // Generate CSRF token (in real app, this would come from server)
  const csrfToken = generateCSRFToken();

  return {
    user,
    accessToken,
    isAuthenticated,
    isLoading,
    error,
    login,
    register,
    logout,
    clearError,
    updateUser,
    csrfToken,
  };
};
