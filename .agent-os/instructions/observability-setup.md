# Instruction: Observability Setup

## Overview

Implement comprehensive observability for the frontend application, including logging, error tracking, performance monitoring, and user analytics. This setup should provide insights into application health, user experience, and performance metrics.

## Core Requirements

### 1. Logging System

- Structured logging with different levels
- Error logging and tracking
- Performance logging
- User action logging

### 2. Error Tracking

- Error boundary implementation
- Error reporting to external services
- Error categorization and prioritization
- User feedback collection

### 3. Performance Monitoring

- Web Vitals tracking
- Custom performance metrics
- User interaction monitoring
- Performance budgets

### 4. Analytics

- User behavior tracking
- Feature usage analytics
- Conversion tracking
- A/B testing support

## Implementation Steps

### Step 1: Logging System

```typescript
// src/lib/logger.ts
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4,
}

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  context?: Record<string, any>;
  userId?: string;
  sessionId?: string;
  url?: string;
  userAgent?: string;
}

class Logger {
  private level: LogLevel;
  private sessionId: string;
  private userId?: string;

  constructor(level: LogLevel = LogLevel.INFO) {
    this.level = level;
    this.sessionId = this.generateSessionId();
  }

  private generateSessionId(): string {
    return Math.random().toString(36).substring(2, 15);
  }

  setUserId(userId: string) {
    this.userId = userId;
  }

  private createLogEntry(
    level: LogLevel,
    message: string,
    context?: Record<string, any>
  ): LogEntry {
    return {
      level,
      message,
      timestamp: new Date().toISOString(),
      context,
      userId: this.userId,
      sessionId: this.sessionId,
      url: window.location.href,
      userAgent: navigator.userAgent,
    };
  }

  private shouldLog(level: LogLevel): boolean {
    return level >= this.level;
  }

  private formatLog(entry: LogEntry): string {
    const levelName = LogLevel[entry.level];
    const timestamp = entry.timestamp;
    const context = entry.context ? ` ${JSON.stringify(entry.context)}` : "";

    return `[${timestamp}] ${levelName}: ${entry.message}${context}`;
  }

  private sendToExternalService(entry: LogEntry) {
    // Send to external logging service (e.g., Sentry, LogRocket)
    if (entry.level >= LogLevel.ERROR) {
      this.sendErrorToService(entry);
    }
  }

  private sendErrorToService(entry: LogEntry) {
    // Example: Send to Sentry
    if (typeof Sentry !== "undefined") {
      Sentry.captureMessage(entry.message, {
        level: this.mapLogLevelToSentry(entry.level),
        extra: entry.context,
        user: { id: entry.userId },
        tags: { sessionId: entry.sessionId },
      });
    }
  }

  private mapLogLevelToSentry(level: LogLevel): string {
    const mapping = {
      [LogLevel.DEBUG]: "debug",
      [LogLevel.INFO]: "info",
      [LogLevel.WARN]: "warning",
      [LogLevel.ERROR]: "error",
      [LogLevel.FATAL]: "fatal",
    };
    return mapping[level];
  }

  debug(message: string, context?: Record<string, any>) {
    if (this.shouldLog(LogLevel.DEBUG)) {
      const entry = this.createLogEntry(LogLevel.DEBUG, message, context);
      console.debug(this.formatLog(entry));
      this.sendToExternalService(entry);
    }
  }

  info(message: string, context?: Record<string, any>) {
    if (this.shouldLog(LogLevel.INFO)) {
      const entry = this.createLogEntry(LogLevel.INFO, message, context);
      console.info(this.formatLog(entry));
      this.sendToExternalService(entry);
    }
  }

  warn(message: string, context?: Record<string, any>) {
    if (this.shouldLog(LogLevel.WARN)) {
      const entry = this.createLogEntry(LogLevel.WARN, message, context);
      console.warn(this.formatLog(entry));
      this.sendToExternalService(entry);
    }
  }

  error(message: string, context?: Record<string, any>) {
    if (this.shouldLog(LogLevel.ERROR)) {
      const entry = this.createLogEntry(LogLevel.ERROR, message, context);
      console.error(this.formatLog(entry));
      this.sendToExternalService(entry);
    }
  }

  fatal(message: string, context?: Record<string, any>) {
    if (this.shouldLog(LogLevel.FATAL)) {
      const entry = this.createLogEntry(LogLevel.FATAL, message, context);
      console.error(this.formatLog(entry));
      this.sendToExternalService(entry);
    }
  }
}

export const logger = new Logger(
  import.meta.env.DEV ? LogLevel.DEBUG : LogLevel.INFO
);

// src/hooks/useLogger.ts
import { useCallback } from "react";
import { logger } from "@/lib/logger";

export function useLogger() {
  const logDebug = useCallback(
    (message: string, context?: Record<string, any>) => {
      logger.debug(message, context);
    },
    []
  );

  const logInfo = useCallback(
    (message: string, context?: Record<string, any>) => {
      logger.info(message, context);
    },
    []
  );

  const logWarn = useCallback(
    (message: string, context?: Record<string, any>) => {
      logger.warn(message, context);
    },
    []
  );

  const logError = useCallback(
    (message: string, context?: Record<string, any>) => {
      logger.error(message, context);
    },
    []
  );

  const logFatal = useCallback(
    (message: string, context?: Record<string, any>) => {
      logger.fatal(message, context);
    },
    []
  );

  return {
    logDebug,
    logInfo,
    logWarn,
    logError,
    logFatal,
  };
}
```

### Step 2: Error Tracking

```typescript
// src/components/ErrorBoundary.tsx
import React, { Component, ErrorInfo, ReactNode } from 'react'
import { logger } from '@/lib/logger'

interface Props {
  children: ReactNode
  fallback?: ReactNode
  onError?: (error: Error, errorInfo: ErrorInfo) => void
}

interface State {
  hasError: boolean
  error?: Error
  errorInfo?: ErrorInfo
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Log error to our logging system
    logger.error('Error boundary caught an error', {
      error: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
    })

    // Call custom error handler
    this.props.onError?.(error, errorInfo)

    // Send to external error tracking service
    this.sendErrorToService(error, errorInfo)
  }

  private sendErrorToService(error: Error, errorInfo: ErrorInfo) {
    // Example: Send to Sentry
    if (typeof Sentry !== 'undefined') {
      Sentry.captureException(error, {
        extra: {
          componentStack: errorInfo.componentStack,
        },
      })
    }
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }

      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <div className="max-w-md w-full bg-white shadow-lg rounded-lg p-6">
            <div className="text-center">
              <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100">
                <svg
                  className="h-6 w-6 text-red-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z"
                  />
                </svg>
              </div>
              <h3 className="mt-4 text-lg font-medium text-gray-900">
                Something went wrong
              </h3>
              <p className="mt-2 text-sm text-gray-500">
                We're sorry, but something unexpected happened. Please try refreshing the page.
              </p>
              <div className="mt-6">
                <button
                  onClick={() => window.location.reload()}
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
                >
                  Refresh Page
                </button>
              </div>
            </div>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}

// src/hooks/useErrorHandler.ts
import { useCallback } from 'react'
import { logger } from '@/lib/logger'

export function useErrorHandler() {
  const handleError = useCallback((error: Error, context?: Record<string, any>) => {
    // Log the error
    logger.error('Application error occurred', {
      error: error.message,
      stack: error.stack,
      ...context,
    })

    // Send to external error tracking service
    if (typeof Sentry !== 'undefined') {
      Sentry.captureException(error, {
        extra: context,
      })
    }

    // You could also show a user-friendly error message
    // or trigger error reporting UI
  }, [])

  const handleAsyncError = useCallback(async <T>(
    promise: Promise<T>,
    context?: Record<string, any>
  ): Promise<T | null> => {
    try {
      return await promise
    } catch (error) {
      handleError(error as Error, context)
      return null
    }
  }, [handleError])

  return {
    handleError,
    handleAsyncError,
  }
}
```

### Step 3: Performance Monitoring

```typescript
// src/lib/performance.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from "web-vitals";

interface PerformanceMetric {
  name: string;
  value: number;
  rating: "good" | "needs-improvement" | "poor";
  delta: number;
  id: string;
}

interface PerformanceBudget {
  fcp: number;
  lcp: number;
  fid: number;
  cls: number;
  ttfb: number;
}

const PERFORMANCE_BUDGET: PerformanceBudget = {
  fcp: 1800, // 1.8s
  lcp: 2500, // 2.5s
  fid: 100, // 100ms
  cls: 0.1, // 0.1
  ttfb: 800, // 800ms
};

class PerformanceMonitor {
  private metrics: Map<string, PerformanceMetric> = new Map();
  private logger: any;

  constructor(logger: any) {
    this.logger = logger;
  }

  private checkBudget(metric: PerformanceMetric): boolean {
    const budget =
      PERFORMANCE_BUDGET[metric.name.toLowerCase() as keyof PerformanceBudget];
    if (budget === undefined) return true;

    const isWithinBudget = metric.value <= budget;
    if (!isWithinBudget) {
      this.logger.warn(`Performance budget exceeded for ${metric.name}`, {
        metric: metric.name,
        value: metric.value,
        budget,
        rating: metric.rating,
      });
    }

    return isWithinBudget;
  }

  private sendToAnalytics(metric: PerformanceMetric) {
    // Send to Google Analytics
    if (typeof gtag !== "undefined") {
      gtag("event", metric.name, {
        event_category: "Web Vitals",
        value: Math.round(metric.value),
        event_label: metric.rating,
        custom_metric_1: metric.delta,
      });
    }

    // Send to custom analytics
    this.sendToCustomAnalytics(metric);
  }

  private sendToCustomAnalytics(metric: PerformanceMetric) {
    // Example: Send to your analytics service
    fetch("/api/analytics/performance", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(metric),
    }).catch((error) => {
      this.logger.error("Failed to send performance metric", {
        error: error.message,
      });
    });
  }

  startMonitoring() {
    getCLS((metric) => this.handleMetric(metric));
    getFID((metric) => this.handleMetric(metric));
    getFCP((metric) => this.handleMetric(metric));
    getLCP((metric) => this.handleMetric(metric));
    getTTFB((metric) => this.handleMetric(metric));
  }

  private handleMetric(metric: PerformanceMetric) {
    this.metrics.set(metric.name, metric);

    // Check against budget
    this.checkBudget(metric);

    // Send to analytics
    this.sendToAnalytics(metric);

    // Log the metric
    this.logger.info(`Performance metric: ${metric.name}`, {
      value: metric.value,
      rating: metric.rating,
      delta: metric.delta,
    });
  }

  getMetrics(): PerformanceMetric[] {
    return Array.from(this.metrics.values());
  }

  getMetric(name: string): PerformanceMetric | undefined {
    return this.metrics.get(name);
  }
}

export const performanceMonitor = new PerformanceMonitor(logger);

// src/hooks/usePerformanceMonitor.ts
import { useEffect, useRef } from "react";
import { performanceMonitor } from "@/lib/performance";
import { logger } from "@/lib/logger";

export function usePerformanceMonitor() {
  const observerRef = useRef<PerformanceObserver | null>(null);

  useEffect(() => {
    // Start monitoring Web Vitals
    performanceMonitor.startMonitoring();

    // Monitor long tasks
    if ("PerformanceObserver" in window) {
      observerRef.current = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.duration > 50) {
            logger.warn("Long task detected", {
              duration: entry.duration,
              startTime: entry.startTime,
              name: entry.name,
            });
          }
        }
      });

      observerRef.current.observe({ entryTypes: ["longtask"] });
    }

    // Monitor memory usage
    if ("memory" in performance) {
      const memory = (performance as any).memory;
      logger.info("Memory usage", {
        used: Math.round(memory.usedJSHeapSize / 1048576),
        total: Math.round(memory.totalJSHeapSize / 1048576),
        limit: Math.round(memory.jsHeapSizeLimit / 1048576),
      });
    }

    return () => {
      if (observerRef.current) {
        observerRef.current.disconnect();
      }
    };
  }, []);

  return {
    getMetrics: () => performanceMonitor.getMetrics(),
    getMetric: (name: string) => performanceMonitor.getMetric(name),
  };
}
```

### Step 4: Analytics System

```typescript
// src/lib/analytics.ts
interface AnalyticsEvent {
  name: string;
  category: string;
  action?: string;
  label?: string;
  value?: number;
  properties?: Record<string, any>;
}

class Analytics {
  private userId?: string;
  private sessionId: string;
  private logger: any;

  constructor(logger: any) {
    this.sessionId = this.generateSessionId();
    this.logger = logger;
  }

  private generateSessionId(): string {
    return Math.random().toString(36).substring(2, 15);
  }

  setUserId(userId: string) {
    this.userId = userId;
  }

  track(event: AnalyticsEvent) {
    // Log the event
    this.logger.info("Analytics event", event);

    // Send to Google Analytics
    if (typeof gtag !== "undefined") {
      gtag("event", event.name, {
        event_category: event.category,
        event_action: event.action,
        event_label: event.label,
        value: event.value,
        ...event.properties,
      });
    }

    // Send to custom analytics service
    this.sendToCustomAnalytics(event);
  }

  private sendToCustomAnalytics(event: AnalyticsEvent) {
    fetch("/api/analytics/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ...event,
        userId: this.userId,
        sessionId: this.sessionId,
        timestamp: new Date().toISOString(),
        url: window.location.href,
        userAgent: navigator.userAgent,
      }),
    }).catch((error) => {
      this.logger.error("Failed to send analytics event", {
        error: error.message,
      });
    });
  }

  // Convenience methods
  trackPageView(page: string) {
    this.track({
      name: "page_view",
      category: "Navigation",
      properties: { page },
    });
  }

  trackUserAction(action: string, label?: string) {
    this.track({
      name: "user_action",
      category: "User Interaction",
      action,
      label,
    });
  }

  trackFeatureUsage(feature: string) {
    this.track({
      name: "feature_usage",
      category: "Features",
      label: feature,
    });
  }

  trackError(error: string, context?: Record<string, any>) {
    this.track({
      name: "error",
      category: "Errors",
      label: error,
      properties: context,
    });
  }
}

export const analytics = new Analytics(logger);

// src/hooks/useAnalytics.ts
import { useCallback } from "react";
import { analytics } from "@/lib/analytics";

export function useAnalytics() {
  const trackEvent = useCallback((event: any) => {
    analytics.track(event);
  }, []);

  const trackPageView = useCallback((page: string) => {
    analytics.trackPageView(page);
  }, []);

  const trackUserAction = useCallback((action: string, label?: string) => {
    analytics.trackUserAction(action, label);
  }, []);

  const trackFeatureUsage = useCallback((feature: string) => {
    analytics.trackFeatureUsage(feature);
  }, []);

  const trackError = useCallback(
    (error: string, context?: Record<string, any>) => {
      analytics.trackError(error, context);
    },
    []
  );

  return {
    trackEvent,
    trackPageView,
    trackUserAction,
    trackFeatureUsage,
    trackError,
  };
}
```

## Best Practices

### 1. Logging

- Use appropriate log levels
- Include relevant context
- Avoid logging sensitive information
- Structure logs consistently

### 2. Error Tracking

- Implement comprehensive error boundaries
- Categorize errors by severity
- Provide user-friendly error messages
- Track error trends over time

### 3. Performance Monitoring

- Set realistic performance budgets
- Monitor real user metrics
- Alert on performance regressions
- Track performance trends

### 4. Analytics

- Respect user privacy
- Track meaningful events
- Avoid tracking sensitive data
- Use consistent event naming

## Quality Gates

### 1. Logging Coverage

- All errors are logged
- Performance metrics are tracked
- User actions are monitored
- Logs are properly structured

### 2. Error Handling

- Error boundaries catch errors
- Errors are reported to services
- User experience is maintained
- Error recovery is implemented

### 3. Performance Monitoring

- Web Vitals are tracked
- Performance budgets are enforced
- Long tasks are detected
- Memory usage is monitored

### 4. Analytics

- Events are properly tracked
- Data is sent to services
- Privacy is respected
- Performance impact is minimal

## Next Steps

After completing observability setup:

1. Configure external services (Sentry, LogRocket)
2. Set up monitoring dashboards
3. Implement alerting systems
4. Add performance budgets
5. Create analytics reports
