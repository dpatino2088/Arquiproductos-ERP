import React, { useEffect, useState } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { AlertCircle, Box } from 'lucide-react';

/**
 * AuthCallback - Handles OAuth callbacks, password recovery tokens, and Magic Links from Supabase
 * 
 * This component processes the URL hash/fragment that Supabase sends after:
 * - Password reset email link click (type=recovery) → redirects to /auth/reset-password
 * - Magic Link click (no type) → redirects to /signup?action=set-password if user needs to set password
 * - OAuth provider redirects → processes and redirects to dashboard
 * - Email confirmation links (type=signup/invite) → processes and redirects to dashboard
 */
export default function AuthCallback() {
  const [isProcessing, setIsProcessing] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const processCallback = async () => {
      try {
        // Get hash parameters from URL (Supabase sends tokens in the hash)
        const hashParams = new URLSearchParams(window.location.hash.substring(1));
        const accessToken = hashParams.get('access_token');
        const type = hashParams.get('type');
        const errorParam = hashParams.get('error');
        const errorDescription = hashParams.get('error_description');

        console.log('🔐 AuthCallback: Processing callback...', { 
          hasAccessToken: !!accessToken, 
          type,
          error: errorParam 
        });

        // Handle OAuth/API errors
        if (errorParam) {
          console.error('❌ Auth error in callback:', errorParam, errorDescription);
          setError(errorDescription || errorParam || 'Authentication failed');
          setIsProcessing(false);
          // Redirect to login after showing error
          setTimeout(() => {
            router.navigate('/login', true);
          }, 3000);
          return;
        }

        // Handle password recovery flow
        if (accessToken && type === 'recovery') {
          console.log('🔐 Password recovery token detected, redirecting to reset-password page...');
          
          // Supabase automatically processes the token and creates a session
          // We need to verify the session exists, then redirect to reset-password
          // DO NOT sign out - Supabase needs the session to validate the token
          
          // Wait a moment for Supabase to process the token
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // Verify session was created
          const { data: { session }, error: sessionError } = await supabase.auth.getSession();
          
          if (sessionError || !session) {
            console.error('❌ Error getting session after recovery token:', sessionError);
            setError('Invalid or expired password reset link. Please request a new one.');
            setIsProcessing(false);
            setTimeout(() => {
              router.navigate('/reset-password', true);
            }, 3000);
            return;
          }

          console.log('✅ Recovery session established, redirecting to reset-password...');
          
          // Clear the hash from URL to avoid reprocessing
          window.history.replaceState(null, '', '/auth/reset-password');
          
          // Redirect to reset-password page
          router.navigate('/auth/reset-password', true);
          return;
        }

        // Handle Magic Link (OTP) - redirect to signup for password setup
        if (accessToken && !type) {
          console.log('🔐 Magic Link detected, redirecting to signup for password setup...');
          
          // Wait a moment for Supabase to process the token
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // Verify session was created
          const { data: { session }, error: sessionError } = await supabase.auth.getSession();
          
          if (sessionError || !session) {
            console.error('❌ Error getting session after magic link:', sessionError);
            setError('Invalid or expired magic link. Please request a new one.');
            setIsProcessing(false);
            setTimeout(() => {
              router.navigate('/login', true);
            }, 3000);
            return;
          }

          if (session?.user) {
            console.log('✅ Magic Link session established, checking if user needs to set password...');
            
            // Check if user already has a password set
            // For Magic Links, we'll always redirect to signup to allow password setup
            // The signup page will handle the logic of whether to update or create
            // This ensures users can set/change their password via Magic Link
            window.history.replaceState(null, '', '/signup?action=set-password');
            router.navigate('/signup?action=set-password', true);
            return;
          }
        }

        // Handle other auth types (signup, invite, etc.)
        if (accessToken && (type === 'signup' || type === 'invite')) {
          console.log('🔐 Processing email confirmation/invite...', { type });
          
          // Supabase should have already processed the token
          // Just verify session and redirect to dashboard
          const { data: { session }, error: sessionError } = await supabase.auth.getSession();
          
          if (sessionError) {
            console.error('❌ Error getting session:', sessionError);
            setError('Failed to process authentication. Please try logging in manually.');
            setIsProcessing(false);
            setTimeout(() => {
              router.navigate('/login', true);
            }, 3000);
            return;
          }

          if (session?.user) {
            console.log('✅ Email confirmed/invite accepted, redirecting to dashboard...');
            window.history.replaceState(null, '', '/dashboard');
            router.navigate('/dashboard', true);
            return;
          }
        }

        // No token or unknown type - redirect to login
        console.log('⚠️ No valid token or unknown type, redirecting to login...');
        window.history.replaceState(null, '', '/login');
        router.navigate('/login', true);
      } catch (err: any) {
        console.error('❌ Error processing auth callback:', err);
        setError(err.message || 'An error occurred while processing authentication');
        setIsProcessing(false);
        setTimeout(() => {
          router.navigate('/login', true);
        }, 3000);
      }
    };

    processCallback();
  }, []);

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white p-8">
        <div className="w-full max-w-md">
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6 text-center">
              <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
              <h2 className="text-2xl font-semibold text-foreground mb-2">Authentication Error</h2>
              <p className="text-muted-foreground mb-4">{error}</p>
              <p className="text-sm text-muted-foreground">Redirecting to login...</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-white">
      <div className="text-center">
        <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-sm text-muted-foreground">Processing authentication...</p>
      </div>
    </div>
  );
}

