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
  } = useAuthStore();


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
    logout,
    clearError,
    updateUser,
    csrfToken,
  };
};
