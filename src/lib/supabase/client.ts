import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { logger } from '../logger';
import { devLog } from '../dev-logger';
import { retryWithBackoff } from './retry-handler';
import { supabaseCircuitBreaker } from './circuit-breaker';
import { useSupabaseStatus } from '../services/supabase-status';

const getSupabaseConfig = () => {
  const url = import.meta.env.VITE_SUPABASE_URL || '';
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || '';
  
  devLog('🔧 Supabase config loaded:', {
    url: url || 'MISSING',
    hasKey: !!key,
    keyLength: key?.length || 0,
    keyStart: key?.substring(0, 20) || 'N/A'
  });
  
  return { url, key };
};

const { url: supabaseUrl, key: supabaseAnonKey } = getSupabaseConfig();

// Create base Supabase client
const baseClient = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseAnonKey || 'placeholder-key',
  {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true,
    },
    global: {
      headers: {
        'X-Client-Info': 'adaptio-erp',
      },
    },
  }
);

// Setup fetch interceptor for error tracking
if (typeof window !== 'undefined') {
  const originalFetch = window.fetch;
  window.fetch = async (...args) => {
    const url = args[0]?.toString() || '';
    const isSupabaseRequest = url.includes(supabaseUrl) || 
                              url.includes('/auth/') || 
                              url.includes('/rest/v1/');

    if (isSupabaseRequest) {
      const timestamp = new Date().toISOString();
      const startTime = Date.now();

      try {
        const response = await originalFetch(...args);
        const duration = Date.now() - startTime;

        // SOLO loguear errores críticos para reducir overhead
        // No loguear requests exitosos ni lentos para reducir carga
        
        // Log server errors (500+) - estos son críticos
        if (response.status >= 500) {
          const errorData = {
            timestamp,
            url,
            status: response.status,
            statusText: response.statusText,
            duration,
          };

          logger.error('Supabase server error', undefined, errorData);
          
          // Update status store (safely)
          try {
            const statusStore = useSupabaseStatus.getState();
            if (statusStore && statusStore.recordError) {
              statusStore.recordError({
                message: `Server error ${response.status}`,
                status: response.status,
              });
            }
          } catch (storeError) {
            // Store no disponible, solo loguear
            logger.debug('Supabase status store not available', { storeError });
          }
        }

        return response;
      } catch (error: any) {
        const duration = Date.now() - startTime;
        
        // Solo loguear errores críticos
        logger.error('Supabase request failed', error, {
          timestamp,
          url,
          duration,
        });

        // Update status store (safely)
        try {
          const statusStore = useSupabaseStatus.getState();
          if (statusStore && statusStore.recordError) {
            statusStore.recordError(error);
          }
        } catch (storeError) {
          // Store no disponible, solo loguear
          logger.debug('Supabase status store not available', { storeError });
        }

        throw error;
      }
    }

    return originalFetch(...args);
  };
}

// Enhanced Supabase client with error handling
class EnhancedSupabaseClient {
  private client: SupabaseClient;

  constructor(client: SupabaseClient) {
    this.client = client;
  }

  // Wrapper methods with circuit breaker and retry
  async getSession() {
    return supabaseCircuitBreaker.execute(() =>
      retryWithBackoff(
        () => this.client.auth.getSession(),
        { maxRetries: 3, baseDelay: 1000 },
        (attempt, error) => {
          logger.debug('Retrying getSession', {
            attempt,
            error: error?.message,
          });
        }
      )
    );
  }

  async getUser() {
    return supabaseCircuitBreaker.execute(() =>
      retryWithBackoff(
        () => this.client.auth.getUser(),
        { maxRetries: 3, baseDelay: 1000 }
      )
    );
  }

  // Proxy all other methods
  get auth() {
    const self = this;
    return {
      ...this.client.auth,
      getSession: () => self.getSession(),
      getUser: () => self.getUser(),
      signInWithPassword: this.client.auth.signInWithPassword.bind(this.client.auth),
      signUp: this.client.auth.signUp.bind(this.client.auth),
      signOut: this.client.auth.signOut.bind(this.client.auth),
      onAuthStateChange: this.client.auth.onAuthStateChange.bind(this.client.auth),
      resetPasswordForEmail: this.client.auth.resetPasswordForEmail.bind(this.client.auth),
      updateUser: this.client.auth.updateUser.bind(this.client.auth),
    };
  }

  get from() {
    return this.client.from.bind(this.client);
  }

  get storage() {
    return this.client.storage;
  }

  get functions() {
    return this.client.functions;
  }

  get rpc() {
    return this.client.rpc.bind(this.client);
  }
}

// Export enhanced client
// Type assertion is safe here as EnhancedSupabaseClient implements all SupabaseClient methods
export const supabase = new EnhancedSupabaseClient(baseClient) as unknown as SupabaseClient;

// Helper function to get current user (with retry)
export const getCurrentUser = async () => {
  try {
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error) throw error;
    return user;
  } catch (error) {
    logger.error('Error getting current user', error instanceof Error ? error : undefined);
    return null;
  }
};

// Helper function to get user profile (with retry)
export const getUserProfile = async (userId: string) => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) throw error;
    return data;
  } catch (error) {
    logger.error('Error getting user profile', error instanceof Error ? error : undefined);
    return null;
  }
};

