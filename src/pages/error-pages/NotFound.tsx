import React from 'react';
import { ArrowLeft, Search } from 'lucide-react';

export default function NotFound() {
  const handleGoBack = () => {
    window.history.back();
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        {/* 404 Illustration */}
        <div className="mb-8">
          <div className="text-6xl font-bold text-primary mb-4">404</div>
          <div className="w-24 h-1 bg-primary mx-auto rounded-full"></div>
        </div>

        {/* Error Message */}
        <div className="mb-8">
          <h1 className="text-2xl font-semibold text-foreground mb-4">
            Page Not Found
          </h1>
          <p className="text-muted-foreground mb-6">
            Sorry, we couldn't find the page you're looking for. The page might have been moved, deleted, or you might have entered the wrong URL.
          </p>
        </div>

        {/* Action Button */}
        <div className="mb-8">
          <button
            onClick={handleGoBack}
            className="w-full bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors flex items-center justify-center gap-2"
            aria-label="Go back to previous page"
          >
            <ArrowLeft className="w-4 h-4" />
            Go Back
          </button>
        </div>

        {/* Help Text */}
        <div className="p-4 bg-muted rounded-lg">
          <div className="flex items-center justify-center gap-2 text-sm text-muted-foreground mb-2">
            <Search className="w-4 h-4" />
            <span>Need help?</span>
          </div>
          <p className="text-xs text-muted-foreground">
            Try checking the URL for typos, or contact support if you believe this is an error.
          </p>
        </div>

        {/* Current URL Display (for debugging) */}
        {import.meta.env.DEV && (
          <div className="mt-6 p-3 bg-destructive/10 border border-destructive/20 rounded-lg">
            <p className="text-xs text-destructive font-mono">
              Current URL: {window.location.pathname}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}