import { useCallback } from 'react';
import { useAuthStore } from '../stores/auth-store';
import { generateCSRFToken } from '../lib/security';
import { logger } from '../lib/logger';

export const useAuth = () => {
  const {
    user,
    accessToken,
    isAuthenticated,
    isLoading,
    error,
    setError,
    updateUser,
    clearAuth,
  } = useAuthStore();


  const logout = useCallback(async () => {
    logger.info('Logging out user');
    await clearAuth();
  }, [clearAuth]);

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
    logout,
    clearError,
    updateUser,
    csrfToken,
  };
};
