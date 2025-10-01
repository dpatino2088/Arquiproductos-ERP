import React, { useState } from 'react';
import { Eye, EyeOff, Lock, CheckCircle, AlertCircle, ArrowRight, Shield } from 'lucide-react';
import RhemoLogo from '../../../RHEMO Logo + Icon White.svg';

export default function NewPassword() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [error, setError] = useState('');

  const passwordRequirements = [
    { text: 'At least 8 characters', met: password.length >= 8 },
    { text: 'One uppercase letter', met: /[A-Z]/.test(password) },
    { text: 'One lowercase letter', met: /[a-z]/.test(password) },
    { text: 'One number', met: /\d/.test(password) },
    { text: 'One special character', met: /[!@#$%^&*(),.?":{}|<>]/.test(password) },
  ];

  const allRequirementsMet = passwordRequirements.every(req => req.met);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (!allRequirementsMet) {
      setError('Password does not meet all requirements');
      return;
    }

    setIsLoading(true);
    
    // Simulate password reset process
    setTimeout(() => {
      setIsLoading(false);
      setIsSuccess(true);
    }, 2000);
  };

  const handleBackToLogin = () => {
    // Navigate back to login
    window.location.href = '/login';
  };

  if (isSuccess) {
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

                <button
                  onClick={handleBackToLogin}
                  className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 transition-colors flex items-center justify-center gap-2"
                >
                  Continue to Login
                  <ArrowRight className="w-4 h-4" />
                </button>
              </div>
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
                <img src={RhemoLogo} alt="RHEMO Logo" className="w-48 h-32" />
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
                    className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                    placeholder="Enter your new password"
                    required
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
                    className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
                    placeholder="Confirm your new password"
                    required
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
                <div className="flex items-center gap-2 text-sm text-destructive">
                  <AlertCircle className="w-4 h-4" />
                  {error}
                </div>
              )}

              {/* Submit Button */}
              <button
                type="submit"
                disabled={isLoading || !allRequirementsMet || password !== confirmPassword}
                className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md text-sm font-medium hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
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
