import { logger } from '../logger';

// Get Supabase URL/Key for health checks (avoid circular dependency with client.ts)
const getSupabaseUrl = () =>
  import.meta.env.VITE_SUPABASE_URL || '';

const getSupabaseKey = () =>
  import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || '';

// ✅ No second createClient: use fetch to avoid "Multiple GoTrueClient instances" warning.
// Health check only needs to know if Supabase REST is reachable.

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
    const url = getSupabaseUrl();
    const key = getSupabaseKey();

    if (!url || !key) {
      const status: HealthStatus = {
        healthy: false,
        timestamp,
        responseTime: 0,
        error: 'Missing VITE_SUPABASE_URL or anon key',
      };
      this.lastCheck = status;
      this.notifySubscribers(status);
      return status;
    }

    try {
      const res = await Promise.race([
        fetch(`${url}/rest/v1/`, {
          method: 'GET',
          headers: { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Accept': 'application/json' },
        }),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error('Health check timeout')), 5000)
        ),
      ]);

      const responseTime = Date.now() - startTime;
      const healthy = res.ok || res.status === 401 || res.status === 404;

      const status: HealthStatus = {
        healthy,
        timestamp,
        responseTime,
        error: healthy ? undefined : res.statusText || `HTTP ${res.status}`,
        status: res.status,
      };

      this.lastCheck = status;
      this.notifySubscribers(status);
      return status;
    } catch (error: unknown) {
      const responseTime = Date.now() - startTime;
      const msg = error instanceof Error ? error.message : String(error);
      const status: HealthStatus = {
        healthy: false,
        timestamp,
        responseTime,
        error: msg || 'Health check failed',
        status: 0,
      };

      this.lastCheck = status;
      this.notifySubscribers(status);

      logger.warn('Supabase health check failed', { timestamp, error: msg, responseTime });
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

