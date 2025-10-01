import React from 'react';
import { ArrowLeft, Network, RefreshCw } from 'lucide-react';

export default function BadGateway() {
  const handleGoBack = () => {
    window.history.back();
  };

  const handleRefresh = () => {
    window.location.reload();
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        {/* 502 Illustration */}
        <div className="mb-8">
          <div className="text-6xl font-bold text-primary mb-4">502</div>
          <div className="w-24 h-1 bg-primary mx-auto rounded-full"></div>
        </div>

        {/* Error Message */}
        <div className="mb-8">
          <div className="flex items-center justify-center gap-2 mb-4">
            <Network className="w-6 h-6 text-destructive" />
            <h1 className="text-2xl font-semibold text-foreground">
              Bad Gateway
            </h1>
          </div>
          <p className="text-muted-foreground mb-6">
            The server received an invalid response from an upstream server. This is usually a temporary issue that will resolve itself.
          </p>
        </div>

        {/* Action Buttons */}
        <div className="mb-8 space-y-3">
          <button
            onClick={handleRefresh}
            className="w-full bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors flex items-center justify-center gap-2"
            aria-label="Refresh the page"
          >
            <RefreshCw className="w-4 h-4" />
            Try Again
          </button>
          
          <button
            onClick={handleGoBack}
            className="w-full bg-secondary text-secondary-foreground px-4 py-2 rounded-lg hover:bg-secondary/90 transition-colors flex items-center justify-center gap-2"
            aria-label="Go back to previous page"
          >
            <ArrowLeft className="w-4 h-4" />
            Go Back
          </button>
        </div>

        {/* Help Text */}
        <div className="p-4 bg-muted rounded-lg">
          <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground mb-2">
            <Network className="w-4 h-4" />
            <span>Gateway Error</span>
          </div>
          <p className="text-xs text-muted-foreground">
            This is typically a temporary network issue. Please wait a moment and try again.
          </p>
        </div>

        {/* Current URL Display (for debugging) */}
        {import.meta.env.DEV && (
          <div className="mt-6 p-3 bg-destructive/10 border border-destructive/20 rounded-lg">
            <p className="text-xs text-destructive font-mono">
              Current URL: {window.location.pathname}
            </p>
            <p className="text-xs text-destructive font-mono mt-1">
              Status: 502 Bad Gateway
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
