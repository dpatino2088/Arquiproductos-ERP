/// <reference types="vite/client" />
import React, { Component, ErrorInfo, ReactNode } from 'react';
import { errorTracker } from '../lib/error-tracker';
import { logger } from '../lib/logger';
import { isChunkLoadFailureText, recoverFromChunkLoadFailure } from '../lib/chunk-recovery';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error?: Error;
  recovering: boolean;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, recovering: false };
  }

  static getDerivedStateFromError(error: Error): State {
    // A failed React.lazy import surfaces here (not as unhandledrejection), so
    // detect chunk-load failures and show the "updating" state while we recover.
    const recovering = isChunkLoadFailureText(error?.message || '');
    return { hasError: true, error, recovering };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Stale chunk after a new deploy: clear caches/SW and reload (bounded retries).
    if (isChunkLoadFailureText(error?.message || '')) {
      void recoverFromChunkLoadFailure(error?.message).then((scheduled) => {
        // Budget exhausted: fall back to the normal error UI so the user can
        // refresh manually instead of staying on a blank "updating" screen.
        if (!scheduled) this.setState({ recovering: false });
      });
      logger.warn('Error boundary caught a chunk load failure; attempting recovery', {
        message: error?.message,
      });
      return;
    }

    // Log the error
    logger.error('Error boundary caught an error', error, {
      errorInfo,
      componentStack: errorInfo.componentStack,
    });

    // Track the error
    errorTracker.trackError(error, {
      type: 'error_boundary',
      componentStack: errorInfo.componentStack,
      errorBoundary: true,
    });

    // Call custom error handler if provided
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }
  }

  render() {
    if (this.state.hasError) {
      // Chunk-load failure recovery in progress: show a lightweight updating
      // state instead of "Something went wrong" while the reload kicks in.
      if (this.state.recovering) {
        return (
          <div className="min-h-[400px] flex items-center justify-center p-6">
            <div className="text-center max-w-md">
              <div className="w-10 h-10 mx-auto mb-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
              <h2 className="text-lg font-semibold text-gray-900 mb-1">
                Updating to the latest version…
              </h2>
              <p className="text-sm text-gray-600">
                A new version was deployed. Reloading automatically.
              </p>
            </div>
          </div>
        );
      }

      // Custom fallback UI
      if (this.props.fallback) {
        return this.props.fallback;
      }

      // Default fallback UI
      return (
        <div className="min-h-[400px] flex items-center justify-center p-6">
          <div className="text-center max-w-md">
            <div className="text-red-500 mb-4">
              <svg
                className="w-16 h-16 mx-auto"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.082 16.5c-.77.833.192 2.5 1.732 2.5z"
                />
              </svg>
            </div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">
              Something went wrong
            </h2>
            <p className="text-gray-600 mb-6">
              We're sorry, but something unexpected happened. Please try refreshing the page.
            </p>
            <div className="space-y-3">
              <button
                onClick={() => window.location.reload()}
                className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Refresh Page
              </button>
              <button
                onClick={() => this.setState({ hasError: false })}
                className="inline-flex items-center px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 ml-3"
              >
                Try Again
              </button>
            </div>
            {import.meta.env.DEV && this.state.error && (
              <details className="mt-6 text-left">
                <summary className="cursor-pointer text-sm text-gray-500">
                  Error Details (Development)
                </summary>
                <pre className="mt-2 text-xs text-red-600 bg-red-50 p-3 rounded overflow-auto max-h-40">
                  {this.state.error.message}
                  {this.state.error.stack && `\n\n${this.state.error.stack}`}
                </pre>
              </details>
            )}
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
