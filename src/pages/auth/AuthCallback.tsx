import React, { useEffect, useState } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { AlertCircle, Box } from 'lucide-react';

/**
 * AuthCallback - Handles OAuth callbacks, password recovery tokens, and Magic Links from Supabase
 * 
 * This component processes the URL hash/fragment that Supabase sends after:
 * - Password reset email link click (type=recovery) → redirects to /set-password
 * - Magic Link click (no type) → redirects to /set-password for new user password setup
 * - Signup confirmation (type=signup) → redirects to /set-password for new user password setup
 * - OAuth provider redirects → processes and redirects to dashboard
 * - Invite confirmation (type=invite) → processes and redirects to dashboard
 */
export default function AuthCallback() {
  const [isProcessing, setIsProcessing] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const processCallback = async () => {
      try {
        // Get hash parameters from URL (Supabase sends tokens in the hash)
        const hash = window.location.hash.substring(1);
        const hashParams = new URLSearchParams(hash);
        const accessToken = hashParams.get('access_token');
        const type = hashParams.get('type');
        const errorParam = hashParams.get('error');
        const errorDescription = hashParams.get('error_description');

        // Also check query params (sometimes Supabase sends them there)
        const queryParams = new URLSearchParams(window.location.search);
        const queryType = queryParams.get('type');
        const queryToken = queryParams.get('access_token');

        console.log('🔐 AuthCallback: Processing callback...', { 
          hash: hash.substring(0, 100) + '...',
          hasAccessToken: !!accessToken,
          hasQueryToken: !!queryToken,
          type: type || queryType,
          error: errorParam,
          fullHash: hash
        });

        // Use query params if hash params are not available
        const finalAccessToken = accessToken || queryToken;
        const finalType = type || queryType;

        // Handle OAuth/API errors
        if (errorParam) {
          console.error('❌ Auth error in callback:', errorParam, errorDescription);
          setError(errorDescription || errorParam || 'Authentication failed');
          setIsProcessing(false);
          setTimeout(() => {
            router.navigate('/login', true);
          }, 3000);
          return;
        }

        // If no token in URL at all, check if there's already a session
        if (!finalAccessToken) {
          console.log('⚠️ No access token found in URL, checking for existing session...');
          const { data: { session } } = await supabase.auth.getSession();
          
          if (session?.user) {
            console.log('✅ Existing session found, redirecting to set-password...');
            window.history.replaceState(null, '', '/set-password');
            router.navigate('/set-password', true);
            return;
          }
          
          console.log('❌ No session found, redirecting to login...');
          window.history.replaceState(null, '', '/login');
          router.navigate('/login', true);
          return;
        }

        // We have a token - wait for Supabase to process it and create session
        console.log('⏳ Token found in URL, waiting for Supabase to process...');
        
        // Give Supabase a moment to detect and process the hash
        // The client has detectSessionInUrl: true, but it needs a render cycle
        await new Promise(resolve => setTimeout(resolve, 100));
        
        let sessionFound = false;
        let authListener: any = null;

        // Listen for auth state changes
        const { data: listenerData } = supabase.auth.onAuthStateChange((event, session) => {
          console.log('🔔 Auth state changed:', event, session ? 'has session' : 'no session');
          if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') && session) {
            sessionFound = true;
            console.log('✅ Session created via auth state change!');
          }
        });
        authListener = listenerData;

        // Wait for Supabase to process the hash (up to 6 seconds with retries)
        let session: any = null;
        for (let i = 0; i < 12; i++) {
          // Check session first
          const { data: { session: currentSession }, error: sessionError } = await supabase.auth.getSession();
          
          if (sessionError) {
            console.error(`❌ Error getting session (attempt ${i + 1}):`, sessionError.message);
            // Only fail if it's a critical error
            if (sessionError.message.includes('JWT') || sessionError.message.includes('invalid')) {
              break;
            }
          } else if (currentSession?.user) {
            session = currentSession;
            sessionFound = true;
            console.log('✅ Session found!', {
              userId: session.user.id,
              email: session.user.email,
              type: finalType,
              attempt: i + 1
            });
            break;
          }

          if (i < 11) {
            console.log(`⏳ Waiting for session... (attempt ${i + 1}/12)`);
            await new Promise(resolve => setTimeout(resolve, 500));
          }
        }

        // Clean up listener
        if (authListener?.subscription) {
          authListener.subscription.unsubscribe();
        }

        // Handle based on type and session
        if (!sessionFound || !session) {
          console.error('❌ Failed to create session after processing token');
          setError('No se pudo crear la sesión. El link puede haber expirado. Por favor solicita un nuevo magic link.');
          setIsProcessing(false);
          setTimeout(() => {
            router.navigate('/login', true);
          }, 4000);
          return;
        }

        // Session established - now check membership and password status using get_auth_context()
        console.log('✅ Session established, checking membership and password status...', {
          userId: session.user.id,
          email: session.user.email,
          type: finalType || 'magic-link',
        });

        // Call get_auth_context() RPC to check membership and password requirement
        const { data: authContext, error: contextError } = await supabase.rpc('get_auth_context');

        if (contextError) {
          console.error('❌ Error calling get_auth_context:', contextError);
          setError('Failed to verify membership. Please contact support.');
          setIsProcessing(false);
          setTimeout(() => {
            router.navigate('/login', true);
          }, 3000);
          return;
        }

        if (!authContext || authContext.length === 0) {
          console.error('❌ No auth context returned');
          setError('Unable to verify membership. Please contact support.');
          setIsProcessing(false);
          setTimeout(() => {
            router.navigate('/login', true);
          }, 3000);
          return;
        }

        const context = authContext[0];
        console.log('📋 Auth context:', context);

        // Check if user has membership (access_allowed)
        if (!context.access_allowed) {
          console.log('❌ User has no active membership');
          window.history.replaceState(null, '', '/access-denied');
          router.navigate('/access-denied', true);
          return;
        }

        // Check if password needs to be set
        if (context.needs_password) {
          console.log('🔐 Password not set, redirecting to set-password...');
          window.history.replaceState(null, '', '/set-password');
          router.navigate('/set-password', true);
          return;
        }

        // User has membership and password is set - redirect to destination
        const queryParams = new URLSearchParams(window.location.search);
        const nextParam = queryParams.get('next') || '/dashboard';
        console.log('✅ Access granted, redirecting to:', nextParam);
        window.history.replaceState(null, '', nextParam);
        router.navigate(nextParam, true);
        return;

        // Invite - redirect to dashboard
        if (finalType === 'invite') {
          console.log('✅ Invite accepted, redirecting to dashboard...');
          window.history.replaceState(null, '', '/dashboard');
          router.navigate('/dashboard', true);
          return;
        }

        // Handle invite confirmation - redirect to dashboard (invited users may already have password set)
        if (finalAccessToken && finalType === 'invite') {
          console.log('🔐 Processing invite confirmation...', { type });
          
          // Wait a moment for Supabase to process the token
          await new Promise(resolve => setTimeout(resolve, 500));
          
          // Verify session was created
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
            console.log('✅ Invite accepted, redirecting to dashboard...');
            
            // Note: link_my_org_invites() is handled by useAuthSession hook when SIGNED_IN event fires
            // No need to call it here to avoid duplicate calls
            
            window.history.replaceState(null, '', '/dashboard');
            router.navigate('/dashboard', true);
            return;
          }
        }

        // No token or unknown type - redirect to login
        console.log('⚠️ No valid token or unknown type, redirecting to login...', {
          hasToken: !!finalAccessToken,
          type: finalType
        });
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

