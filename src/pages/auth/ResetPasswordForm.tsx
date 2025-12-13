import React, { useState, useEffect } from 'react';
import { Eye, EyeOff, Lock, CheckCircle, AlertCircle, ArrowRight, Box } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';

/**
 * ResetPasswordForm - Page for users to set a new password after clicking recovery link
 * 
 * This page is accessed after clicking the password reset link in the email.
 * The user should already have a valid session from Supabase (created by the recovery token).
 * 
 * Flow:
 * 1. User clicks recovery link → Supabase creates session → redirects to /auth/callback
 * 2. /auth/callback detects type=recovery → redirects to /auth/reset-password (this page)
 * 3. User enters new password → supabase.auth.updateUser({ password })
 * 4. On success → show success message → redirect to /login
 */
export default function ResetPasswordForm() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState('');
  const [hasValidSession, setHasValidSession] = useState(false);
  const [isCheckingSession, setIsCheckingSession] = useState(true);

  const passwordRequirements = [
    { text: 'At least 8 characters', met: password.length >= 8 },
    { text: 'One uppercase letter', met: /[A-Z]/.test(password) },
    { text: 'One lowercase letter', met: /[a-z]/.test(password) },
    { text: 'One number', met: /\d/.test(password) },
    { text: 'One special character', met: /[!@#$%^&*(),.?":{}|<>]/.test(password) },
  ];

  const allRequirementsMet = passwordRequirements.every(req => req.met);

  // Check for valid session on mount
  useEffect(() => {
    const checkSession = async () => {
      try {
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) {
          console.error('❌ Error getting session:', sessionError);
          setError('Invalid or expired password reset link. Please request a new one.');
          setHasValidSession(false);
          setIsCheckingSession(false);
          return;
        }

        if (session?.user) {
          console.log('✅ Valid session found, user can reset password:', session.user.email);
          setHasValidSession(true);
        } else {
          console.log('❌ No session found');
          setError('No valid password reset session found. Please request a new password reset.');
          setHasValidSession(false);
        }
      } catch (err: any) {
        console.error('Error checking session:', err);
        setError('Error validating reset link. Please try again.');
        setHasValidSession(false);
      } finally {
        setIsCheckingSession(false);
      }
    };

    checkSession();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    if (!hasValidSession) {
      setError('No valid password reset session. Please request a new password reset.');
      return;
    }
    
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (!allRequirementsMet) {
      setError('Password does not meet all requirements');
      return;
    }

    setIsLoading(true);
    
    try {
      // Update password using Supabase
      const { data, error: updateError } = await supabase.auth.updateUser({
        password: password,
      });

      if (updateError) {
        console.error('Error updating password:', updateError);
        throw updateError;
      }

      if (data.user) {
        console.log('✅ Password updated successfully');
        
        // Sign out the user after password reset (security best practice)
        // They should log in again with the new password
        await supabase.auth.signOut();
        
        setIsLoading(false);
        setIsSuccess(true);
        
        // Show success notification
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Password Updated',
          message: 'Your password has been successfully updated. Please sign in with your new password.',
        });
        
        // Redirect to login after 3 seconds
        setTimeout(() => {
          router.navigate('/login', true);
        }, 3000);
      } else {
        throw new Error('Password update succeeded but no user data returned');
      }
    } catch (err: any) {
      console.error('Error updating password:', err);
      setError(err.message || 'Failed to update password. Please try again.');
      setIsLoading(false);
    }
  };

  const handleBackToLogin = () => {
    supabase.auth.signOut().then(() => {
      router.navigate('/login', true);
    });
  };

  const handleRequestNewLink = () => {
    supabase.auth.signOut().then(() => {
      router.navigate('/reset-password', true);
    });
  };

  // Show loading state while checking session
  if (isCheckingSession) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-sm text-muted-foreground">Validating reset link...</p>
        </div>
      </div>
    );
  }

  // Show error if no valid session
  if (!hasValidSession && error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white p-8">
        <div className="w-full max-w-md">
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6 text-center">
              <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
              <h2 className="text-2xl font-semibold text-foreground mb-2">Invalid Reset Link</h2>
              <p className="text-muted-foreground mb-4">{error}</p>
            </div>
            <div className="space-y-3">
              <button
                onClick={handleRequestNewLink}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                Request New Reset Link
              </button>
              <button
                onClick={handleBackToLogin}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors"
              >
                Back to Login
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (isSuccess) {
    return (
      <div className="min-h-screen flex">
        {/* Left Side - Success Form */}
        <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
          <div className="w-full max-w-md">
            {/* Mobile Header */}
            <div className="lg:hidden text-center mb-8">
              <div className="mx-auto mb-4 flex items-center justify-center">
                <div className="flex items-center justify-center gap-2">
                  <Box size={32} style={{ color: 'var(--primary-brand-hex)' }} />
                  <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
                </div>
              </div>
              <h1 className="text-2xl font-semibold text-foreground mb-2">
                Password Updated!
              </h1>
              <p className="text-muted-foreground">
                Your password has been successfully updated. You can now sign in with your new password.
              </p>
            </div>

            {/* Success Form */}
            <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
              <div className="mb-6">
                <h2 className="text-2xl font-semibold text-foreground mb-2">Password Updated!</h2>
                <p className="text-muted-foreground">
                  Your password has been successfully updated. You can now sign in with your new password.
                </p>
              </div>

              <div className="space-y-4 mb-6">
                <div className="flex items-center gap-3 p-3 bg-green-50 rounded-lg">
                  <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0" />
                  <div>
                    <p className="text-sm text-green-800 font-medium">Password successfully updated</p>
                    <p className="text-xs text-green-600">Your account is now secure with your new password</p>
                  </div>
                </div>

                <p className="text-sm text-muted-foreground text-center">
                  Redirecting to sign in page in a few seconds...
                </p>

                <button
                  onClick={handleBackToLogin}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  Continue to Sign In
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Right Side - Brand Background */}
        <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#172554' }}>
          <div className="max-w-md text-center text-white">
            <div className="mb-8">
              <div className="w-20 h-20 bg-green-500/20 backdrop-blur-sm rounded-2xl mx-auto mb-6 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
              <h1 className="text-4xl font-bold mb-4">Password Updated!</h1>
              <p className="text-xl text-white/80 leading-relaxed">
                Your account is now secure with your new password. You can sign in with your updated credentials.
              </p>
            </div>
            
            <div className="space-y-4 text-left">
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Account security enhanced</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Strong password requirements met</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Ready to access your portal</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex">
      {/* Left Side - Password Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          {/* Mobile Header */}
          <div className="lg:hidden text-center mb-8">
            <div className="mx-auto mb-4 flex items-center justify-center">
              <div className="flex items-center justify-center gap-2">
                <Box size={32} style={{ color: 'var(--primary-brand-hex)' }} />
                <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
              </div>
            </div>
          </div>

          {/* Password Form */}
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Create New Password</h2>
              <p className="text-muted-foreground">Choose a strong password to secure your account</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Password Input */}
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-foreground mb-2">
                  New Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Enter your new password"
                    required
                    minLength={8}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* Confirm Password Input */}
              <div>
                <label htmlFor="confirmPassword" className="block text-sm font-medium text-foreground mb-2">
                  Confirm Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="confirmPassword"
                    type={showConfirmPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Confirm your new password"
                    required
                    minLength={8}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* Password Match Indicator */}
              {password && confirmPassword && (
                <div className={`text-xs ${password === confirmPassword ? 'text-green-600' : 'text-red-600'}`}>
                  {password === confirmPassword ? (
                    <span className="flex items-center gap-1">
                      <CheckCircle className="w-3 h-3" />
                      Passwords match
                    </span>
                  ) : (
                    <span className="flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" />
                      Passwords do not match
                    </span>
                  )}
                </div>
              )}

              {/* Password Requirements */}
              <div className="space-y-2">
                <p className="text-sm font-medium text-foreground">Password Requirements:</p>
                <div className="space-y-1">
                  {passwordRequirements.map((req, index) => (
                    <div key={index} className="flex items-center gap-2 text-sm">
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${
                        req.met ? 'bg-green-100' : 'bg-gray-100'
                      }`}>
                        {req.met ? (
                          <CheckCircle className="w-3 h-3 text-green-600" />
                        ) : (
                          <div className="w-2 h-2 bg-gray-400 rounded-full" />
                        )}
                      </div>
                      <span className={req.met ? 'text-green-600' : 'text-muted-foreground'}>
                        {req.text}
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Error Message */}
              {error && (
                <div className="flex items-center gap-2 text-sm text-destructive bg-red-50 p-3 rounded">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{error}</span>
                </div>
              )}

              {/* Submit Button */}
              <button
                type="submit"
                disabled={isLoading || !allRequirementsMet || password !== confirmPassword}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isLoading ? (
                  <div className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    Update Password
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>
          </div>
        </div>
      </div>

      {/* Right Side - Brand Background */}
      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#172554' }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center">
              <div className="flex items-center justify-center gap-3">
                <Box size={48} style={{ color: 'var(--primary-brand-hex)' }} />
                <span className="text-4xl font-semibold text-white">Adaptio</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

