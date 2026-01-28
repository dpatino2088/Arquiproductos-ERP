import React, { useState } from 'react';
import { ArrowLeft, Mail, CheckCircle, AlertCircle, Box } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';

export default function ResetPassword() {
  const [emailOrPhone, setEmailOrPhone] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [sendingOtp, setSendingOtp] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!emailOrPhone) {
      setError('Please enter your email address');
      return;
    }

    const email = emailOrPhone.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setError('Please enter a valid email address');
      return;
    }

    setSendingOtp(true);
    setError('');

    try {
      // ✅ OTP sin emailRedirectTo (envía código, no magic link) - EXACTAMENTE igual que Login.tsx
      // IMPORTANTE: Para que Supabase envíe OTP numérico en lugar de Magic Link:
      // 1. NO incluir emailRedirectTo en options
      // 2. La plantilla de email en Supabase Dashboard debe usar {{ .Token }} en lugar de {{ .ConfirmationURL }}
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: true, // ✅ Mismo que Login.tsx
          // CRITICAL: NO incluir emailRedirectTo - esto fuerza Magic Link
          // Si incluyes emailRedirectTo, Supabase enviará Magic Link en lugar de OTP
        },
      });

      if (otpError) throw otpError;
      setOtpSent(true);
    } catch (err: any) {
      setError(err?.message || 'Failed to send OTP code. Please try again.');
    } finally {
      setSendingOtp(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!otpCode || otpCode.length !== 6) {
      setError('Please enter the 6-digit code');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const email = emailOrPhone.trim().toLowerCase();
      // ✅ Verify OTP con type 'email' (igual que Login.tsx)
      const { data, error: verifyError } = await supabase.auth.verifyOtp({
        email,
        token: otpCode,
        type: 'email',
      });

      if (verifyError) throw verifyError;

      if (data.user && data.session) {
        // ✅ OTP verified, redirect to set password page
        console.log('[ResetPassword] OTP verified, redirecting to /set-password');
        router.navigate('/set-password', true);
      } else {
        throw new Error('OTP verification succeeded but no session was created');
      }
    } catch (err: any) {
      setError(err?.message || 'Invalid code. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleBackToLogin = () => {
    router.navigate('/login', true);
  };

  const handleResendOtp = async () => {
    setOtpSent(false);
    setOtpCode('');
    setError('');
    // Re-enviar OTP automáticamente
    if (emailOrPhone) {
      const email = emailOrPhone.trim().toLowerCase();
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (emailRegex.test(email)) {
        setSendingOtp(true);
        try {
          const { error: otpError } = await supabase.auth.signInWithOtp({
            email,
            options: {
              shouldCreateUser: false,
            },
          });
          if (otpError) throw otpError;
          setOtpSent(true);
        } catch (err: any) {
          setError(err?.message || 'Failed to resend OTP code. Please try again.');
        } finally {
          setSendingOtp(false);
        }
      }
    }
  };

  if (otpSent) {
    return (
      <div className="min-h-screen flex">
        {/* Left Side - OTP Form */}
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
                Enter Verification Code
              </h1>
              <p className="text-muted-foreground">
                We've sent a 6-digit code to <strong>{emailOrPhone}</strong>
              </p>
            </div>

            {/* OTP Form */}
            <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
              <div className="mb-6">
                <h2 className="text-2xl font-semibold text-foreground mb-2">Enter Verification Code</h2>
                <p className="text-muted-foreground">
                  We've sent a 6-digit code to <strong>{emailOrPhone}</strong>
                </p>
              </div>

              <form onSubmit={handleVerifyOtp} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-foreground mb-2">
                    Enter 6-digit code
                  </label>
                  <input
                    type="text"
                    maxLength={6}
                    value={otpCode}
                    onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 h-10 border border-gray-300 rounded text-center text-lg tracking-widest focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="000000"
                    required
                    autoFocus
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    Check your email for the code
                  </p>
                </div>

                {error && (
                  <div className="flex items-center gap-2 text-sm text-destructive">
                    <AlertCircle className="w-4 h-4" />
                    {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isLoading || otpCode.length !== 6}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  {isLoading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Verifying...
                    </>
                  ) : (
                    'Verify Code'
                  )}
                </button>

                <button
                  type="button"
                  onClick={handleResendOtp}
                  disabled={sendingOtp}
                  className="w-full text-sm text-primary hover:text-primary/80 transition-colors disabled:opacity-50"
                >
                  {sendingOtp ? 'Sending...' : 'Resend Code'}
                </button>
                
                <button
                  type="button"
                  onClick={handleBackToLogin}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors"
                >
                  <ArrowLeft className="w-4 h-4" />
                  Back to Login
                </button>
              </form>
            </div>

            {/* Help Text */}
            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
                <Mail className="w-4 h-4" />
                <span>Didn't receive the code?</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Check your spam folder or contact your administrator if you continue to have issues.
              </p>
            </div>
          </div>
        </div>

        {/* Right Side - Brand Background */}
        <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#1f4456' }}>
          <div className="max-w-md text-center text-white">
            <div className="mb-8">
              <div className="w-20 h-20 bg-green-500/20 backdrop-blur-sm rounded-2xl mx-auto mb-6 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
              <h1 className="text-4xl font-bold mb-4">Code Sent!</h1>
              <p className="text-xl text-white/80 leading-relaxed">
                We've sent a 6-digit verification code to your email address.
              </p>
            </div>
            
            <div className="space-y-4 text-left">
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Secure password reset process</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Code expires in 10 minutes</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Enter the code to continue</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex">
      {/* Left Side - Reset Form */}
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

          {/* Reset Form */}
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Reset Password</h2>
              <p className="text-muted-foreground">Enter your email and we'll send you a verification code</p>
            </div>

            <form onSubmit={handleSendOtp} className="space-y-4">
              {/* Email Input */}
              <div>
                <label htmlFor="emailOrPhone" className="block text-sm font-medium text-foreground mb-2">
                  Email
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="emailOrPhone"
                    type="email"
                    value={emailOrPhone}
                    onChange={(e) => setEmailOrPhone(e.target.value)}
                    className="w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Enter your email"
                    required
                    disabled={otpSent}
                  />
                </div>
              </div>

              {/* Error Message */}
              {error && (
                <div className="flex items-center gap-2 text-sm text-destructive">
                  <AlertCircle className="w-4 h-4" />
                  {error}
                </div>
              )}

              {/* Submit Button */}
              <button
                type="submit"
                disabled={sendingOtp || !emailOrPhone || otpSent}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {sendingOtp ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    Sending...
                  </>
                ) : (
                  'Send Verification Code'
                )}
              </button>
            </form>

            {/* Back to Login */}
            <div className="mt-6 pt-4 border-t border-gray-200">
              <button
                onClick={handleBackToLogin}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors"
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
