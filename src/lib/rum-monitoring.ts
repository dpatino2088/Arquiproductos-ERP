// Real User Monitoring (RUM) implementation
import { logger } from './logger';

export interface RUMMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  timestamp: number;
  url: string;
  userAgent: string;
  connectionType?: string;
  userId?: string;
}

export interface UserSession {
  sessionId: string;
  userId?: string;
  startTime: number;
  pageViews: number;
  interactions: number;
  errors: number;
  totalDuration: number;
}

class RUMMonitor {
  private session: UserSession;
  private metrics: RUMMetric[] = [];
  private interactions: number = 0;
  private errors: number = 0;

  constructor() {
    this.session = {
      sessionId: this.generateSessionId(),
      startTime: Date.now(),
      pageViews: 0,
      interactions: 0,
      errors: 0,
      totalDuration: 0
    };

    this.initializeMonitoring();
  }

  private generateSessionId(): string {
    return `rum_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private initializeMonitoring(): void {
    if (typeof window === 'undefined') return;

    // Track page views
    this.trackPageView();

    // Track user interactions
    this.trackInteractions();

    // Track JavaScript errors
    this.trackErrors();

    // Track network information
    this.trackNetworkInfo();

    // Track session duration
    this.trackSessionDuration();

    // Send data before page unload
    window.addEventListener('beforeunload', () => {
      this.sendSessionData();
    });

    // Send data periodically
    setInterval(() => {
      this.sendMetrics();
    }, 30000); // Every 30 seconds
  }

  private trackPageView(): void {
    this.session.pageViews++;
    
    const metric: RUMMetric = {
      name: 'page_view',
      value: Date.now(),
      rating: 'good',
      timestamp: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      userId: this.session.userId
    };

    this.addMetric(metric);
    logger.info('Page view tracked', { url: window.location.href });
  }

  private trackInteractions(): void {
    const interactionTypes = ['click', 'keydown', 'touchstart', 'scroll'];
    
    interactionTypes.forEach(type => {
      document.addEventListener(type, () => {
        this.interactions++;
        this.session.interactions = this.interactions;
      }, { passive: true });
    });
  }

  private trackErrors(): void {
    window.addEventListener('error', (event) => {
      this.errors++;
      this.session.errors = this.errors;

      const metric: RUMMetric = {
        name: 'javascript_error',
        value: 1,
        rating: 'poor',
        timestamp: Date.now(),
        url: window.location.href,
        userAgent: navigator.userAgent,
        userId: this.session.userId
      };

      this.addMetric(metric);
      logger.error('JavaScript error tracked', new Error(event.message), {
        filename: (event as ErrorEvent).filename || 'unknown',
        lineno: (event as ErrorEvent).lineno || 0,
        colno: (event as ErrorEvent).colno || 0
      });
    });

    window.addEventListener('unhandledrejection', (event) => {
      this.errors++;
      this.session.errors = this.errors;

      const metric: RUMMetric = {
        name: 'unhandled_promise_rejection',
        value: 1,
        rating: 'poor',
        timestamp: Date.now(),
        url: window.location.href,
        userAgent: navigator.userAgent,
        userId: this.session.userId
      };

      this.addMetric(metric);
      logger.error('Unhandled promise rejection tracked', new Error('Promise rejection'), {
        reason: String((event as PromiseRejectionEvent).reason)
      });
    });
  }

  private trackNetworkInfo(): void {
    if ('connection' in navigator) {
      const connection = (navigator as Navigator & { connection?: { downlink?: number; effectiveType?: string } }).connection;
      
      if (connection) {
        const metric: RUMMetric = {
          name: 'network_info',
          value: connection.downlink || 0,
          rating: this.getNetworkRating(connection.effectiveType || 'unknown'),
          timestamp: Date.now(),
          url: window.location.href,
          userAgent: navigator.userAgent,
          connectionType: connection.effectiveType,
          userId: this.session.userId
        };

        this.addMetric(metric);
      }
    }
  }

  private getNetworkRating(effectiveType: string): 'good' | 'needs-improvement' | 'poor' {
    switch (effectiveType) {
      case '4g':
        return 'good';
      case '3g':
        return 'needs-improvement';
      default:
        return 'poor';
    }
  }

  private trackSessionDuration(): void {
    setInterval(() => {
      this.session.totalDuration = Date.now() - this.session.startTime;
    }, 1000);
  }

  public addMetric(metric: RUMMetric): void {
    this.metrics.push(metric);
    
    // Limit metrics array size
    if (this.metrics.length > 100) {
      this.metrics = this.metrics.slice(-50);
    }
  }

  public setUserId(userId: string): void {
    this.session.userId = userId;
    logger.info('RUM user ID set', { userId });
  }

  public trackCustomMetric(name: string, value: number, rating?: 'good' | 'needs-improvement' | 'poor'): void {
    const metric: RUMMetric = {
      name,
      value,
      rating: rating || 'good',
      timestamp: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      userId: this.session.userId
    };

    this.addMetric(metric);
    logger.info('Custom RUM metric tracked', { name, value, rating });
  }

  private sendMetrics(): void {
    if (this.metrics.length === 0) return;

    const _payload = {
      session: this.session,
      metrics: [...this.metrics],
      timestamp: Date.now()
    };

    // In a real implementation, send to your analytics service
    // For now, we'll log it and clear the metrics
    logger.info('RUM metrics batch', { 
      metricsCount: this.metrics.length,
      sessionId: this.session.sessionId 
    });

    // Clear sent metrics
    this.metrics = [];
  }

  private sendSessionData(): void {
    this.session.totalDuration = Date.now() - this.session.startTime;
    
    const _payload = {
      session: this.session,
      finalMetrics: [...this.metrics],
      timestamp: Date.now()
    };

    // Send final session data
    logger.info('RUM session ended', _payload);

          // Use sendBeacon for reliable delivery on page unload
    if (navigator.sendBeacon) {
      const blob = new Blob([JSON.stringify(_payload)], { type: 'application/json' });
      navigator.sendBeacon('/api/rum', blob);
    }
  }

  public getSessionInfo(): UserSession {
    return { ...this.session };
  }

  public getMetrics(): RUMMetric[] {
    return [...this.metrics];
  }
}

// Initialize RUM monitoring
export const rumMonitor = new RUMMonitor();

// Export for external use
export { RUMMonitor };
