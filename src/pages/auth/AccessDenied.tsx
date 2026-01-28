import React from 'react';
import { AlertCircle, Box, ArrowLeft, Mail } from 'lucide-react';
import { router } from '../../lib/router';

/**
 * AccessDenied - Page shown when user doesn't have membership
 * 
 * This page is displayed when:
 * - User has a valid Supabase session but no active membership in OrganizationUsers or CompanyPortalUsers
 * - User's membership status is 'disabled' or 'deleted'
 */
export default function AccessDenied() {
  const handleGoToLogin = () => {
    router.navigate('/login', true);
  };

  return (
    <div className="min-h-screen flex">
      {/* Left Side - Access Denied Message */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          {/* Mobile Header */}
          <div className="lg:hidden text-center mb-8">
            <div className="mx-auto mb-4 flex items-center justify-center gap-2">
              <Box size={32} style={{ color: 'var(--primary-brand-hex)' }} />
              <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
            </div>
          </div>

          {/* Access Denied Card */}
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6 text-center">
              <div className="mx-auto mb-4 w-16 h-16 bg-red-50 rounded-full flex items-center justify-center">
                <AlertCircle className="w-8 h-8 text-red-500" />
              </div>
              <h2 className="text-2xl font-semibold text-foreground mb-2">Access Denied</h2>
              <p className="text-muted-foreground text-sm">
                You don't have permission to access this application.
              </p>
            </div>

            {/* Message */}
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded text-sm text-red-800">
              <p className="font-medium mb-2">Why am I seeing this?</p>
              <ul className="list-disc list-inside space-y-1 text-red-700">
                <li>Your account is not associated with any organization</li>
                <li>Your membership has been disabled or removed</li>
                <li>You haven't been invited to access this system</li>
              </ul>
            </div>

            {/* Instructions */}
            <div className="mb-6 space-y-3">
              <div className="flex items-start gap-3">
                <div className="w-6 h-6 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <Mail className="w-3 h-3 text-primary" />
                </div>
                <div>
                  <p className="text-sm text-foreground font-medium">Contact your administrator</p>
                  <p className="text-xs text-muted-foreground">
                    Ask them to invite you or reactivate your account
                  </p>
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="space-y-3">
              <button
                onClick={handleGoToLogin}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                <ArrowLeft className="w-4 h-4" />
                Back to Login
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Right Side - Brand Background */}
      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#1f4456' }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center gap-3">
              <Box size={48} style={{ color: 'var(--primary-brand-hex)' }} />
              <span className="text-4xl font-semibold text-white">Adaptio</span>
            </div>
            <p className="text-white/80">
              Access requires an invitation from your organization administrator
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
