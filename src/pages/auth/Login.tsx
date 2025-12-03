import React, { useState } from 'react';
import { Eye, EyeOff, Mail, Lock, ArrowRight, Phone, Box } from 'lucide-react';

// Microsoft and Google SVG Icons
const MicrosoftIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <rect x="1" y="1" width="8" height="8" fill="#F25022"/>
    <rect x="11" y="1" width="8" height="8" fill="#7FBA00"/>
    <rect x="1" y="11" width="8" height="8" fill="#00A4EF"/>
    <rect x="11" y="11" width="8" height="8" fill="#FFB900"/>
  </svg>
);

const GoogleIcon = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M19.6 10.23c0-.82-.1-1.42-.25-2.05H10v3.72h5.5c-.15.96-.74 2.38-2.13 3.34v2.66h3.44c2.01-1.85 3.19-4.58 3.19-7.67z" fill="#4285F4"/>
    <path d="M10 20c2.7 0 4.96-.89 6.61-2.4l-3.44-2.66c-.9.6-2.06 1.03-3.17 1.03-2.44 0-4.5-1.64-5.24-3.85H1.3v2.75A9.99 9.99 0 0010 20z" fill="#34A853"/>
    <path d="M4.76 11.12c-.18-.6-.28-1.24-.28-1.9s.1-1.3.28-1.9V4.57H1.3A9.99 9.99 0 000 10c0 1.61.39 3.14 1.3 4.43l3.46-2.31z" fill="#FBBC05"/>
    <path d="M10 3.98c1.35 0 2.56.46 3.51 1.36l2.64-2.64C14.96.89 12.7 0 10 0 6.09 0 2.72 2.25 1.3 5.57l3.46 2.75c.74-2.21 2.8-3.85 5.24-3.85z" fill="#EA4335"/>
  </svg>
);

export default function Login() {
  const [emailOrPhone, setEmailOrPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    // Simulate login process
    setTimeout(() => {
      setIsLoading(false);
      // Handle email or phone login logic here
      console.log('Login:', { emailOrPhone, password });
    }, 2000);
  };

  const handleO365Login = () => {
    // Handle O365 login
    console.log('O365 login clicked');
  };

  const handleGoogleLogin = () => {
    // Handle Google login
    console.log('Google login clicked');
  };

  return (
    <div className="min-h-screen flex">
      {/* Left Side - Login Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          {/* Mobile Header */}
          <div className="lg:hidden text-center mb-8">
            <div className="mx-auto mb-4 flex items-center justify-center gap-2">
              <Box size={32} style={{ color: 'var(--primary-brand-hex)' }} />
              <span className="text-2xl font-semibold text-gray-900">PROLOGIX</span>
            </div>
          </div>

          {/* Login Form */}
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Sign In</h2>
              <p className="text-muted-foreground">Enter your credentials to access your company portal</p>
            </div>


            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Email or Phone Input */}
              <div>
                <label htmlFor="emailOrPhone" className="block text-sm font-medium text-foreground mb-2">
                  Email or Phone
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="emailOrPhone"
                    type="text"
                    value={emailOrPhone}
                    onChange={(e) => setEmailOrPhone(e.target.value)}
                    className="w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Enter your email or phone number"
                    required
                  />
                </div>
              </div>

              {/* Password Input */}
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-foreground mb-2">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Enter your password"
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

              {/* Remember Me & Forgot Password */}
              <div className="flex items-center justify-between">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-1 focus:ring-primary/20"
                  />
                  <span className="ml-2 text-sm text-muted-foreground">Remember me</span>
                </label>
                {/* Forgot Password - Available for both login types */}
                <button
                  type="button"
                  onClick={() => window.location.href = '/reset-password'}
                  className="text-sm text-primary hover:text-primary/80 transition-colors"
                >
                  Forgot password?
                </button>
              </div>

              {/* Login Button */}
              <button
                type="submit"
                disabled={isLoading}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isLoading ? (
                  <div className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    Sign In
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </form>

            {/* Divider and Social Login */}
            <div className="my-6">
              <div className="relative">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-gray-200" />
                </div>
                <div className="relative flex justify-center text-sm">
                  <span className="px-2 bg-white text-muted-foreground">Or continue with</span>
                </div>
              </div>
            </div>

            {/* Social Login Buttons */}
            <div className="space-y-3">
                  <button
                    onClick={handleO365Login}
                    className="w-full flex items-center justify-center gap-2 px-4 h-8 border border-gray-300 rounded text-sm text-foreground hover:bg-gray-50 transition-colors"
                  >
                    <MicrosoftIcon />
                    Microsoft
                  </button>

                  <button
                    onClick={handleGoogleLogin}
                    className="w-full flex items-center justify-center gap-2 px-4 h-8 border border-gray-300 rounded text-sm text-foreground hover:bg-gray-50 transition-colors"
                  >
                    <GoogleIcon />
                    Google
                  </button>
            </div>
          </div>

          {/* Footer */}
          <div className="text-center mt-6">
            <p className="text-sm text-muted-foreground">
              Don't have a user account? Contact your administrator, or{' '}
              <button 
                onClick={() => window.location.href = '/company-registration'}
                className="text-primary hover:text-primary/80 transition-colors"
              >
                register your company
              </button>
              {' '}to create a new portal.
            </p>
          </div>
        </div>
      </div>

      {/* Right Side - Graphite Black Background */}
      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: 'var(--gray-950)' }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center gap-3">
              <Box size={48} style={{ color: 'var(--primary-brand-hex)' }} />
              <span className="text-4xl font-semibold text-white">PROLOGIX</span>
            </div>
          </div>
          
        </div>
      </div>
    </div>
  );
}
