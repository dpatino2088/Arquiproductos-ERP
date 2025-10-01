import React, { useState } from 'react';
import { ArrowLeft, Mail, CheckCircle, AlertCircle, Shield, Clock } from 'lucide-react';
import RhemoLogo from '../../../RHEMO Logo + Icon White.svg';

export default function ResetPassword() {
  const [resetType, setResetType] = useState<'email' | 'company'>('email');
  const [email, setEmail] = useState('');
  const [companyId, setCompanyId] = useState('');
  const [username, setUsername] = useState('');
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    
    // Simulate reset password process
    setTimeout(() => {
      setIsLoading(false);
      if (resetType === 'email') {
        if (email) {
          setIsSubmitted(true);
        } else {
          setError('Please enter a valid email address');
        }
      } else {
        if (companyId && username) {
          setIsSubmitted(true);
        } else {
          setError('Please enter both Company ID and Username');
        }
      }
    }, 2000);
  };

  const handleBackToLogin = () => {
    // Navigate back to login
    window.history.back();
  };

  const handleResendEmail = () => {
    setIsSubmitted(false);
    setEmail('');
  };

  if (isSubmitted) {
    return (
      <div className="min-h-screen flex">
        {/* Left Side - Success Form */}
        <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
          <div className="w-full max-w-md">
            {/* Mobile Header */}
            <div className="lg:hidden text-center mb-8">
              <div className="mx-auto mb-4 flex items-center justify-center">
                <img src={RhemoLogo} alt="RHEMO Logo" className="w-48 h-32" />
              </div>
              <h1 className="text-2xl font-semibold text-foreground mb-2">
                Check Your Email
              </h1>
              <p className="text-muted-foreground">
                We've sent a password reset link to <strong>{email}</strong>
              </p>
            </div>

            {/* Success Form */}
            <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Check Your Email</h2>
              <p className="text-muted-foreground">
                We've sent a password reset link to <strong>{resetType === 'email' ? email : `${username}@${companyId}.com`}</strong>
              </p>
            </div>

              {/* Instructions */}
              <div className="space-y-4 mb-6">
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-xs font-semibold text-primary">1</span>
                  </div>
                  <div>
                    <p className="text-sm text-foreground font-medium">Check your email inbox</p>
                    <p className="text-xs text-muted-foreground">Look for an email from RHEMO</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-xs font-semibold text-primary">2</span>
                  </div>
                  <div>
                    <p className="text-sm text-foreground font-medium">Click the reset link</p>
                    <p className="text-xs text-muted-foreground">The link will expire in 24 hours</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 bg-primary/10 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                    <span className="text-xs font-semibold text-primary">3</span>
                  </div>
                  <div>
                    <p className="text-sm text-foreground font-medium">Create a new password</p>
                    <p className="text-xs text-muted-foreground">Follow the security requirements</p>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="space-y-3">
                <button
                  onClick={handleResendEmail}
                  className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 transition-colors"
                >
                  Resend Email
                </button>
                
                <button
                  onClick={handleBackToLogin}
                  className="w-full bg-secondary text-secondary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-secondary/90 transition-colors flex items-center justify-center gap-2"
                >
                  <ArrowLeft className="w-4 h-4" />
                  Back to Login
                </button>
              </div>
            </div>

            {/* Help Text */}
            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
                <Mail className="w-4 h-4" />
                <span>Didn't receive the email?</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Check your spam folder or contact your administrator if you continue to have issues.
              </p>
            </div>
          </div>
        </div>

        {/* Right Side - Graphite Black Background */}
        <div className="hidden lg:flex lg:w-1/2 bg-[#1A1A1A] items-center justify-center p-12">
          <div className="max-w-md text-center text-white">
            <div className="mb-8">
              <div className="w-20 h-20 bg-green-500/20 backdrop-blur-sm rounded-2xl mx-auto mb-6 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
              <h1 className="text-4xl font-bold mb-4">Email Sent!</h1>
              <p className="text-xl text-white/80 leading-relaxed">
                We've sent a secure password reset link to your email address.
              </p>
            </div>
            
            <div className="space-y-4 text-left">
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Secure password reset process</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>24-hour link expiration</span>
              </div>
              <div className="flex items-center gap-3 text-white/90">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Follow the instructions in your email</span>
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
                <img src={RhemoLogo} alt="RHEMO Logo" className="w-48 h-32" />
              </div>
          </div>

          {/* Reset Form */}
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Reset Password</h2>
              <p className="text-muted-foreground">Enter your credentials and we'll send you a secure reset link</p>
            </div>

            {/* Reset Type Toggle */}
            <div className="mb-6">
              <div className="flex bg-gray-100 rounded-md p-0.5">
                <button
                  type="button"
                  onClick={() => setResetType('email')}
                  className={`flex-1 py-1 px-2 rounded text-xs font-medium transition-colors ${
                    resetType === 'email'
                      ? 'bg-white text-foreground shadow-sm'
                      : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  Email Reset
                </button>
                <button
                  type="button"
                  onClick={() => setResetType('company')}
                  className={`flex-1 py-1 px-2 rounded text-xs font-medium transition-colors ${
                    resetType === 'company'
                      ? 'bg-white text-foreground shadow-sm'
                      : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  Company ID
                </button>
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Email Input - Only show for email reset */}
              {resetType === 'email' && (
                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-foreground mb-2">
                    Email Address
                  </label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                    <input
                      id="email"
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                      placeholder="Enter your email address"
                      required
                    />
                  </div>
                </div>
              )}

              {/* Company ID and Username - Only show for company reset */}
              {resetType === 'company' && (
                <>
                  <div>
                    <label htmlFor="companyId" className="block text-sm font-medium text-foreground mb-2">
                      Company ID
                    </label>
                    <div className="relative">
                      <input
                        id="companyId"
                        type="text"
                        value={companyId}
                        onChange={(e) => setCompanyId(e.target.value)}
                        className="w-full pl-3 pr-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                        placeholder="Enter your company ID"
                        required
                      />
                    </div>
                  </div>
                  
                  <div>
                    <label htmlFor="username" className="block text-sm font-medium text-foreground mb-2">
                      Username
                    </label>
                    <div className="relative">
                      <input
                        id="username"
                        type="text"
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                        className="w-full pl-3 pr-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                        placeholder="Enter your username"
                        required
                      />
                    </div>
                  </div>
                </>
              )}

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
                disabled={isLoading}
                className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
              >
                {isLoading ? (
                  <div className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
                ) : (
                  'Send Reset Link'
                )}
              </button>
            </form>

            {/* Back to Login */}
            <div className="mt-6 pt-4 border-t border-gray-200">
              <button
                onClick={handleBackToLogin}
                className="w-full bg-secondary text-secondary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-secondary/90 transition-colors flex items-center justify-center gap-2"
              >
                <ArrowLeft className="w-4 h-4" />
                Back to Login
              </button>
            </div>
          </div>

        </div>
      </div>

      {/* Right Side - Graphite Black Background */}
      <div className="hidden lg:flex lg:w-1/2 bg-[#1A1A1A] items-center justify-center p-12">
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center">
              <img src={RhemoLogo} alt="RHEMO Logo" className="w-64 h-40" />
            </div>
          </div>
          
        </div>
      </div>
    </div>
  );
}
