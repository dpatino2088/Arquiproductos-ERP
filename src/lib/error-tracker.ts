import { logger } from './logger';

interface ErrorContext {
  userId?: string;
  route?: string;
  component?: string;
  action?: string;
  timestamp?: string;
  userAgent?: string;
  url?: string;
  [key: string]: any;
}

interface TrackedError {
  id: string;
  message: string;
  stack?: string;
  name: string;
  timestamp: string;
  context: ErrorContext;
  fingerprint: string;
}

class ErrorTracker {
  private errors: TrackedError[] = [];
  private maxStoredErrors = 100;

  trackError(error: Error, context?: ErrorContext): string {
    const errorId = this.generateErrorId();
    const fingerprint = this.generateFingerprint(error);
    
    const trackedError: TrackedError = {
      id: errorId,
      message: error.message,
      stack: error.stack,
      name: error.name,
      timestamp: new Date().toISOString(),
      context: {
        ...context,
        userAgent: navigator.userAgent,
        url: window.location.href,
        timestamp: new Date().toISOString(),
      },
      fingerprint,
    };

    // Store error locally
    this.storeError(trackedError);

    // Log error
    logger.error('Error tracked', error, trackedError.context);

    // In production, you would send to error tracking service
    if (!import.meta.env.DEV) {
      this.sendToErrorService(trackedError);
    }

    return errorId;
  }

  trackApiError(error: any, endpoint: string, method: string, context?: ErrorContext): string {
    const apiError = new Error(`API Error: ${method} ${endpoint} - ${error.message || 'Unknown error'}`);
    
    return this.trackError(apiError, {
      ...context,
      type: 'api_error',
      endpoint,
      method,
      statusCode: error.status,
      responseData: error.data,
    });
  }

  trackUserAction(action: string, context?: ErrorContext) {
    logger.info('User action tracked', {
      action,
      ...context,
      timestamp: new Date().toISOString(),
      url: window.location.href,
    });
  }

  getStoredErrors(): TrackedError[] {
    return [...this.errors];
  }

  clearErrors() {
    this.errors = [];
  }

  private generateErrorId(): string {
    return `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private generateFingerprint(error: Error): string {
    // Create a fingerprint based on error type and stack trace
    const stackLines = error.stack?.split('\n').slice(0, 3).join('') || '';
    const content = `${error.name}:${error.message}:${stackLines}`;
    
    // Simple hash function
    let hash = 0;
    for (let i = 0; i < content.length; i++) {
      const char = content.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    
    return Math.abs(hash).toString(36);
  }

  private storeError(error: TrackedError) {
    this.errors.unshift(error);
    
    // Keep only the most recent errors
    if (this.errors.length > this.maxStoredErrors) {
      this.errors = this.errors.slice(0, this.maxStoredErrors);
    }
  }

  private sendToErrorService(error: TrackedError) {
    // In a real implementation, you would send to services like:
    // - Sentry
    // - Rollbar
    // - Bugsnag
    // - Custom error tracking API
    
    console.log('Would send to error service:', error);
    
    // Example implementation:
    // fetch('/api/errors', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(error),
    // }).catch(err => {
    //   logger.error('Failed to send error to service', err);
    // });
  }
}

// Export singleton instance
export const errorTracker = new ErrorTracker();

// Global error handler
window.addEventListener('error', (event) => {
  errorTracker.trackError(event.error, {
    type: 'global_error',
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno,
  });
});

// Unhandled promise rejection handler
window.addEventListener('unhandledrejection', (event) => {
  const error = event.reason instanceof Error ? event.reason : new Error(String(event.reason));
  errorTracker.trackError(error, {
    type: 'unhandled_promise_rejection',
  });
});
