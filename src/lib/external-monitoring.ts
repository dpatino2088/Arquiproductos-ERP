/// <reference types="vite/client" />
// External monitoring service integrations
import { logger } from './logger';

// Extend Window interface for external monitoring services
declare global {
  interface Window {
    dataLayer?: unknown[];
    DD_RUM?: {
      addUserAction(name: string, properties: Record<string, unknown>): void;
      addError(error: Error, properties: Record<string, unknown>): void;
      startView(path: string): void;
    };
    Sentry?: {
      captureException(error: Error, options: Record<string, unknown>): void;
      setUser(user: Record<string, unknown>): void;
    };
    LogRocket?: {
      track(action: string, properties: Record<string, unknown>): void;
      identify(id: string, properties: Record<string, unknown>): void;
    };
  }
}

declare function _gtag(...args: unknown[]): void;

interface MonitoringConfig {
  sentryDsn?: string;
  datadogApiKey?: string;
  logRocketAppId?: string;
  enableAnalytics?: boolean;
  environment?: string;
}

interface PerformanceMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
  timestamp: number;
  url: string;
}

interface ErrorEvent {
  message: string;
  stack?: string;
  filename?: string;
  lineno?: number;
  colno?: number;
  timestamp: number;
  userAgent: string;
  url: string;
}

class ExternalMonitoringManager {
  private config: MonitoringConfig;
  private isInitialized = false;

  constructor(config: MonitoringConfig = {}) {
    this.config = {
      environment: import.meta.env.MODE || 'development',
      enableAnalytics: import.meta.env.PROD,
      ...config,
    };
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      // Initialize Sentry if DSN provided
      if (this.config.sentryDsn) {
        await this.initializeSentry();
      }

      // Initialize DataDog if API key provided
      if (this.config.datadogApiKey) {
        await this.initializeDataDog();
      }

      // Initialize LogRocket if App ID provided
      if (this.config.logRocketAppId) {
        await this.initializeLogRocket();
      }

      // Initialize Google Analytics if enabled
      if (this.config.enableAnalytics) {
        await this.initializeAnalytics();
      }

      this.isInitialized = true;
      logger.info('External monitoring initialized', {
        sentry: !!this.config.sentryDsn,
        datadog: !!this.config.datadogApiKey,
        logRocket: !!this.config.logRocketAppId,
        analytics: !!this.config.enableAnalytics,
      });
    } catch (error) {
      logger.error('Failed to initialize external monitoring', error instanceof Error ? error : new Error(String(error)));
    }
  }

  private async initializeSentry(): Promise<void> {
    try {
      // Mock Sentry initialization - replace with actual implementation when needed
      logger.info('Sentry initialization skipped (not installed)');
    } catch (error) {
      logger.warn('Sentry not available or failed to initialize', error instanceof Error ? error : new Error(String(error)));
    }
  }

  private async initializeDataDog(): Promise<void> {
    try {
      // Mock DataDog initialization - replace with actual implementation when needed
      logger.info('DataDog RUM initialization skipped (not installed)');
    } catch (error) {
      logger.warn('DataDog RUM not available or failed to initialize', error instanceof Error ? error : new Error(String(error)));
    }
  }

  private async initializeLogRocket(): Promise<void> {
    try {
      // Mock LogRocket initialization - replace with actual implementation when needed
      logger.info('LogRocket initialization skipped (not installed)');
    } catch (error) {
      logger.warn('LogRocket not available or failed to initialize', error instanceof Error ? error : new Error(String(error)));
    }
  }

  private async initializeAnalytics(): Promise<void> {
    try {
      // Mock Google Analytics initialization - replace with actual implementation when needed
      logger.info('Google Analytics initialization skipped (not configured)');
    } catch (error) {
      logger.warn('Google Analytics failed to initialize', error instanceof Error ? error : new Error(String(error)));
    }
  }

  // Send performance metrics to external services
  sendPerformanceMetric(metric: PerformanceMetric): void {
    if (!this.isInitialized) return;

    try {
      // Mock analytics - replace with actual implementation when needed
      logger.debug('Performance metric would be sent to analytics', metric);

      // Send to DataDog (if available)
      if (window.DD_RUM) {
        window.DD_RUM.addUserAction(metric.name, {
          value: metric.value,
          rating: metric.rating,
          delta: metric.delta,
        });
      }

      // Send to custom analytics endpoint
      this.sendToCustomAnalytics('performance', metric);
    } catch (error) {
      logger.error('Failed to send performance metric to external services', error instanceof Error ? error : new Error(String(error)));
    }
  }

  // Send error to external services
  sendError(error: ErrorEvent): void {
    if (!this.isInitialized) return;

    try {
      // Send to Sentry (if available)
      if (window.Sentry) {
        window.Sentry.captureException(new Error(error.message), {
          extra: {
            stack: error.stack,
            filename: error.filename,
            lineno: error.lineno,
            colno: error.colno,
            url: error.url,
          },
        });
      }

      // Send to DataDog (if available)
      if (window.DD_RUM) {
        window.DD_RUM.addError(new Error(error.message), {
          stack: error.stack,
          filename: error.filename,
          lineno: error.lineno,
          colno: error.colno,
        });
      }

      // Send to custom analytics endpoint
      this.sendToCustomAnalytics('error', error);
    } catch (err) {
      logger.error('Failed to send error to external services', err instanceof Error ? err : new Error(String(err)));
    }
  }

  // Send user action/event
  trackUserAction(action: string, properties: Record<string, unknown> = {}): void {
    if (!this.isInitialized) return;

    try {
      // Mock user action tracking - replace with actual implementation when needed
      logger.debug('User action would be tracked', { action, properties });

      // Send to DataDog (if available)
      if (window.DD_RUM) {
        window.DD_RUM.addUserAction(action, properties);
      }

      // Send to LogRocket (if available)
      if (window.LogRocket) {
        window.LogRocket.track(action, properties);
      }

      // Send to custom analytics endpoint
      this.sendToCustomAnalytics('user_action', { action, ...properties });
    } catch (error) {
      logger.error('Failed to track user action', error instanceof Error ? error : new Error(String(error)));
    }
  }

  // Send page view
  trackPageView(path: string, title?: string): void {
    if (!this.isInitialized) return;

    try {
      // Mock page view tracking - replace with actual implementation when needed
      logger.debug('Page view would be tracked', { path, title });

      // Send to DataDog (if available)
      if (window.DD_RUM) {
        window.DD_RUM.startView(path);
      }

      // Send to custom analytics endpoint
      this.sendToCustomAnalytics('page_view', { path, title });
    } catch (error) {
      logger.error('Failed to track page view', error instanceof Error ? error : new Error(String(error)));
    }
  }

  // Send to custom analytics endpoint
  private async sendToCustomAnalytics(type: string, data: unknown): Promise<void> {
    try {
      // In a real implementation, this would send to your analytics API
      const payload = {
        type,
        data,
        timestamp: Date.now(),
        session_id: this.getSessionId(),
        user_agent: navigator.userAgent,
        url: window.location.href,
        environment: this.config.environment,
      };

      // Mock implementation - replace with actual API call
      logger.debug('Custom analytics payload', payload);
      
      // Example API call (uncomment and modify for your endpoint):
      // await fetch('/api/analytics', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify(payload),
      // });
    } catch (error) {
      logger.error('Failed to send to custom analytics', error instanceof Error ? error : new Error(String(error)));
    }
  }

  // Generate or get session ID
  private getSessionId(): string {
    let sessionId = sessionStorage.getItem('PROLOGIX_session_id');
    if (!sessionId) {
      sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      sessionStorage.setItem('PROLOGIX_session_id', sessionId);
    }
    return sessionId;
  }

  // Set user context for monitoring services
  setUser(user: { id: string; email?: string; name?: string }): void {
    try {
      // Set user in Sentry
      if (window.Sentry) {
        window.Sentry.setUser({
          id: user.id,
          email: user.email,
          username: user.name,
        });
      }

      // Set user in DataDog
      if (window.DD_RUM && 'setUser' in window.DD_RUM) {
        (window.DD_RUM as unknown as { setUser: (user: Record<string, unknown>) => void }).setUser({
          id: user.id,
          email: user.email,
          name: user.name,
        });
      }

      // Set user in LogRocket
      if (window.LogRocket) {
        window.LogRocket.identify(user.id, {
          name: user.name,
          email: user.email,
        });
      }

      logger.info('User context set for monitoring services', { userId: user.id });
    } catch (error) {
      logger.error('Failed to set user context', error instanceof Error ? error : new Error(String(error)));
    }
  }
}

// Create and export singleton instance
export const externalMonitoring = new ExternalMonitoringManager({
  // Configure with environment variables
  sentryDsn: import.meta.env.VITE_SENTRY_DSN,
  datadogApiKey: import.meta.env.VITE_DATADOG_API_KEY,
  logRocketAppId: import.meta.env.VITE_LOGROCKET_APP_ID,
  enableAnalytics: import.meta.env.VITE_ENABLE_ANALYTICS === 'true',
});

// Initialize on module load
if (typeof window !== 'undefined') {
  externalMonitoring.initialize();
}
