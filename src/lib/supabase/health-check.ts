import { createClient } from '@supabase/supabase-js';
import { logger } from '../logger';

// Get Supabase URL for health checks (avoid circular dependency)
const getSupabaseUrl = () => {
  return import.meta.env.VITE_SUPABASE_URL || '';
};

const getSupabaseKey = () => {
  return import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || '';
};

// Create a minimal client for health checks
const healthCheckClient = createClient(
  getSupabaseUrl() || 'https://placeholder.supabase.co',
  getSupabaseKey() || 'placeholder-key',
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

export interface HealthStatus {
  healthy: boolean;
  timestamp: string;
  responseTime: number;
  error?: string;
  status?: number;
}

class SupabaseHealthChecker {
  private lastCheck: HealthStatus | null = null;
  private checkInterval: number | null = null;
  private subscribers: Set<(status: HealthStatus) => void> = new Set();

  async checkHealth(): Promise<HealthStatus> {
    const startTime = Date.now();
    const timestamp = new Date().toISOString();

    try {
      // Simple health check - try to get session (lightweight)
      const { error } = await Promise.race([
        healthCheckClient.auth.getSession(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Health check timeout')), 5000)
        ),
      ]) as any;

      const responseTime = Date.now() - startTime;

      // Even if there's an error, if we got a response, service is up
      // (auth errors are different from service being down)
      const healthy = !error || (error.status < 500);

      const status: HealthStatus = {
        healthy,
        timestamp,
        responseTime,
        error: error?.message,
        status: error?.status,
      };

      this.lastCheck = status;

      // Notify subscribers
      this.notifySubscribers(status);

      return status;
    } catch (error: any) {
      const responseTime = Date.now() - startTime;
      const status: HealthStatus = {
        healthy: false,
        timestamp,
        responseTime,
        error: error?.message || 'Health check failed',
        status: error?.status || 0,
      };

      this.lastCheck = status;
      this.notifySubscribers(status);

      logger.warn('Supabase health check failed', {
        timestamp,
        error: error?.message,
        responseTime,
      });

      return status;
    }
  }

  startPeriodicCheck(intervalMs: number = 60000): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
    }

    // Initial check
    this.checkHealth();

    // Periodic checks
    this.checkInterval = window.setInterval(() => {
      this.checkHealth();
    }, intervalMs);
  }

  stopPeriodicCheck(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  subscribe(callback: (status: HealthStatus) => void): () => void {
    this.subscribers.add(callback);

    // Immediately notify with last status if available
    if (this.lastCheck) {
      callback(this.lastCheck);
    }

    // Return unsubscribe function
    return () => {
      this.subscribers.delete(callback);
    };
  }

  private notifySubscribers(status: HealthStatus): void {
    this.subscribers.forEach(callback => {
      try {
        callback(status);
      } catch (error) {
        logger.error('Error in health check subscriber', error as Error);
      }
    });
  }

  getLastStatus(): HealthStatus | null {
    return this.lastCheck;
  }
}

export const supabaseHealthChecker = new SupabaseHealthChecker();

