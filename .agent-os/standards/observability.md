# Standard: Observability

## Overview

Implement client-side observability to monitor application health, user experience, and performance metrics.

## Core Requirements

### 1. Logging

- Implement structured logging
- Log user actions and errors
- Implement log levels (debug, info, warn, error)
- Provide log aggregation capabilities

### 2. Error Tracking

- Implement error boundaries
- Track JavaScript errors
- Monitor API errors
- Provide error context and stack traces

### 3. Performance Monitoring

- Track Core Web Vitals
- Monitor user interactions
- Track API response times
- Implement performance budgets

### 4. User Analytics

- Track user journeys
- Monitor feature usage
- Track conversion funnels
- Implement A/B testing support

## Implementation Guidelines

### Logging Implementation

```typescript
class Logger {
  private logLevel: LogLevel = "info";

  info(message: string, data?: any) {
    if (this.shouldLog("info")) {
      console.info(`[INFO] ${message}`, data);
    }
  }

  error(message: string, error?: Error) {
    if (this.shouldLog("error")) {
      console.error(`[ERROR] ${message}`, error);
    }
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = { debug: 0, info: 1, warn: 2, error: 3 };
    return levels[level] >= levels[this.logLevel];
  }
}
```

### Error Tracking

```typescript
class ErrorTracker {
  trackError(error: Error, context?: any) {
    // Send to error tracking service
    console.error("Error tracked:", error, context);

    // Log additional context
    this.logError(error, context);
  }

  private logError(error: Error, context?: any) {
    const errorInfo = {
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
      context,
    };

    // Store or send error info
    console.error("Error details:", errorInfo);
  }
}
```

### Performance Monitoring

```typescript
import { getCLS, getFID, getFCP, getLCP, getTTFB } from "web-vitals";

export function setupPerformanceMonitoring() {
  getCLS((metric) => {
    console.log("CLS:", metric);
    // Send to analytics
  });

  getFID((metric) => {
    console.log("FID:", metric);
    // Send to analytics
  });

  getFCP((metric) => {
    console.log("FCP:", metric);
    // Send to analytics
  });

  getLCP((metric) => {
    console.log("LCP:", metric);
    // Send to analytics
  });

  getTTFB((metric) => {
    console.log("TTFB:", metric);
    // Send to analytics
  });
}
```

## Observability Targets

- Error rate: < 1%
- API response time: < 200ms
- Page load time: < 2s
- User interaction response: < 100ms

## Best Practices

- Implement structured logging with consistent format
- Use appropriate log levels
- Track errors with sufficient context
- Monitor performance metrics continuously
- Implement alerting for critical issues
- Use correlation IDs for request tracing
