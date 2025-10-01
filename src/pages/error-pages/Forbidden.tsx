import React from 'react';
import { ArrowLeft, Lock, AlertTriangle } from 'lucide-react';

export default function Forbidden() {
  const handleGoBack = () => {
    window.history.back();
  };

  const handleContactAdmin = () => {
    // In a real app, this would open a contact form or email client
    window.open('mailto:admin@company.com?subject=Access Request', '_blank');
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        {/* 403 Illustration */}
        <div className="mb-8">
          <div className="text-6xl font-bold text-primary mb-4">403</div>
          <div className="w-24 h-1 bg-primary mx-auto rounded-full"></div>
        </div>

        {/* Error Message */}
        <div className="mb-8">
          <div className="flex items-center justify-center gap-2 mb-4">
            <Lock className="w-6 h-6 text-destructive" />
            <h1 className="text-2xl font-semibold text-foreground">
              Access Forbidden
            </h1>
          </div>
          <p className="text-muted-foreground mb-6">
            You don't have the necessary permissions to access this resource. This area is restricted to authorized personnel only.
          </p>
        </div>

        {/* Action Buttons */}
        <div className="mb-8 space-y-3">
          <button
            onClick={handleContactAdmin}
            className="w-full bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors flex items-center justify-center gap-2"
            aria-label="Contact administrator for access"
          >
            <AlertTriangle className="w-4 h-4" />
            Request Access
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
            <Lock className="w-4 h-4" />
            <span>Permission Required</span>
          </div>
          <p className="text-xs text-muted-foreground">
            This resource requires specific permissions. Contact your administrator if you believe you should have access to this area.
          </p>
        </div>

        {/* Current URL Display (for debugging) */}
        {import.meta.env.DEV && (
          <div className="mt-6 p-3 bg-destructive/10 border border-destructive/20 rounded-lg">
            <p className="text-xs text-destructive font-mono">
              Current URL: {window.location.pathname}
            </p>
            <p className="text-xs text-destructive font-mono mt-1">
              Status: 403 Forbidden
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
