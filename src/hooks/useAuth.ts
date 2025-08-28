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
  const [authState, setAuthState] = useState<AuthState>({
    user: null,
    isAuthenticated: false,
    isLoading: false,
    error: null
  });

  const [csrfToken] = useState(() => generateCSRFToken());

  // Check for existing session on mount
  useEffect(() => {
    const checkSession = async () => {
      try {
        const token = localStorage.getItem('auth_token');
        const userData = localStorage.getItem('user_data');
        
        if (token && userData) {
          const user = JSON.parse(userData);
          setAuthState(prev => ({
            ...prev,
            user,
            isAuthenticated: true
          }));
        }
      } catch (error) {
        console.error('Session check failed:', error);
        // Clear invalid data
        localStorage.removeItem('auth_token');
        localStorage.removeItem('user_data');
        localStorage.removeItem('csrf_token');
      }
    };

    checkSession();
  }, []);

  const login = useCallback(async (credentials: LoginCredentials) => {
    setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

    try {
      // Validate inputs
      if (!validateEmail(credentials.email)) {
        throw new Error('Invalid email format');
      }

      if (credentials.password.length < 8) {
        throw new Error('Password must be at least 8 characters');
      }

      // Simulate API call (replace with actual authentication)
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Mock user data (replace with actual API response)
      const user: User = {
        id: '1',
        email: credentials.email,
        name: credentials.email.split('@')[0] || 'User', // Use email prefix as name
        role: 'user'
      };

      // Store authentication data securely
      localStorage.setItem('auth_token', 'mock_jwt_token_' + Date.now());
      localStorage.setItem('user_data', JSON.stringify(user));
      localStorage.setItem('csrf_token', csrfToken);

      setAuthState({
        user,
        isAuthenticated: true,
        isLoading: false,
        error: null
      });

      console.log('Login successful:', user);

    } catch (error) {
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Login failed'
      }));
    }
  }, [csrfToken]);

  const register = useCallback(async (credentials: RegisterCredentials) => {
    setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

    try {
      // Validate inputs
      if (!validateEmail(credentials.email)) {
        throw new Error('Invalid email format');
      }

      const passwordValidation = validatePassword(credentials.password);
      if (!passwordValidation.isValid) {
        throw new Error(passwordValidation.errors.join(', '));
      }

      if (credentials.password !== credentials.confirmPassword) {
        throw new Error('Passwords do not match');
      }

      // Simulate API call (replace with actual registration)
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Mock user data (replace with actual API response)
      const user: User = {
        id: '1',
        email: credentials.email,
        name: credentials.name,
        role: 'user'
      };

      // Store authentication data securely
      localStorage.setItem('auth_token', 'mock_jwt_token_' + Date.now());
      localStorage.setItem('user_data', JSON.stringify(user));
      localStorage.setItem('csrf_token', csrfToken);

      setAuthState({
        user,
        isAuthenticated: true,
        isLoading: false,
        error: null
      });

      console.log('Registration successful:', user);

    } catch (error) {
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Registration failed'
      }));
    }
  }, [csrfToken]);

  const logout = useCallback(() => {
    // Clear all authentication data
    localStorage.removeItem('auth_token');
    localStorage.removeItem('user_data');
    localStorage.removeItem('csrf_token');

    setAuthState({
      user: null,
      isAuthenticated: false,
      isLoading: false,
      error: null
    });

    console.log('Logout successful');
  }, []);

  const clearError = useCallback(() => {
    setAuthState(prev => ({ ...prev, error: null }));
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
