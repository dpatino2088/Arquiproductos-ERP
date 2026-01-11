import React, { useEffect, useState } from 'react';
import { Lock, Eye, EyeOff, ArrowRight, AlertCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useAuthStore } from '../../stores/auth-store';
import { router } from '../../lib/router';
import { getUserProfile } from '../../lib/supabase/client';
import { fetchAuthContext } from '../../auth/authContext';

export default function SetPasswordPage() {
  const navigate = router; // Using custom router
  const { setAuth } = useAuthStore();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [msg, setMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [checkingSession, setCheckingSession] = useState(true);
  const [userEmail, setUserEmail] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      // Check if there's a hash in URL (token from magic link/reset password)
      const hash = window.location.hash.substring(1);
      const hasHash = hash.includes('access_token');
      
      if (hasHash) {
        console.log('[SetPassword] Hash found in URL, redirecting to AuthCallback...');
        // If there's a hash, redirect to AuthCallback to process it properly
        window.history.replaceState(null, '', '/auth/callback');
        navigate.navigate('/auth/callback', true);
        return;
      }

      // Wait a moment for Supabase to process any tokens
      await new Promise(resolve => setTimeout(resolve, 300));
      
      // Check for session with retries (Supabase may still be processing)
      let session: any = null;
      for (let attempt = 0; attempt < 5; attempt++) {
        const { data, error } = await supabase.auth.getSession();
        
        if (error) {
          console.error(`[SetPassword] getSession error (attempt ${attempt + 1}):`, error);
          // Continue trying unless it's a critical error
          if (error.message.includes('JWT') || error.message.includes('invalid')) {
            break;
          }
        } else if (data.session) {
          session = data.session;
          console.log('[SetPassword] Session found!', {
            userId: session.user.id,
            email: session.user.email
          });
          break;
        }
        
        if (attempt < 4) {
          console.log(`[SetPassword] No session yet, waiting... (attempt ${attempt + 1}/5)`);
          await new Promise(resolve => setTimeout(resolve, 500));
        }
      }

      if (!session) {
        console.error('[SetPassword] No session found after retries');
        setMsg('No valid session found. Please request a new magic link or password reset.');
        setCheckingSession(false);
        setTimeout(() => {
          navigate.navigate('/login', true);
        }, 3000);
        return;
      }

      // Verify membership using get_auth_context()
      const { fetchAuthContext } = await import('../../auth/authContext');
      const context = await fetchAuthContext(supabase);

      // Check if user has membership
      if (!context.access_allowed) {
        console.error('[SetPassword] User has no active membership');
        setMsg('You do not have permission to set a password. Please contact support.');
        setCheckingSession(false);
        setTimeout(() => {
          navigate.navigate('/access-denied', true);
        }, 3000);
        return;
      }

      // If password is already set, redirect (shouldn't happen normally, but just in case)
      if (!context.needs_password) {
        console.log('[SetPassword] Password already set, redirecting to dashboard');
        navigate.navigate('/dashboard', true);
        return;
      }

      setUserEmail(session.user.email || null);
      setCheckingSession(false);
    })();
  }, [navigate]);

  const onSave = async () => {
    setMsg(null);
    if (password.length < 8) {
      setMsg('Password mínimo 8 caracteres');
      return;
    }
    if (password !== confirm) {
      setMsg('Passwords no coinciden');
      return;
    }

    setLoading(true);
    const { data: updateData, error } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (error) {
      setMsg(error.message);
      return;
    }

    if (updateData.user) {
      setMsg('✅ Password creado. Guardando información del usuario...');
      
      const userId = updateData.user.id;
      const userMetadata = updateData.user.user_metadata || {};
      
      // Update Profiles.password_set_at
      try {
        const { error: profileError } = await supabase
          .from('Profiles')
          .update({
            password_set_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', userId);

        if (profileError) {
          console.error('[SetPassword] Error updating password_set_at:', profileError);
          // Continue anyway - password is set in auth
        } else {
          console.log('✅ password_set_at updated successfully');
        }
      } catch (profileErr) {
        console.warn('[SetPassword] Profile update failed:', profileErr);
        // Continue anyway - password is set in auth
      }

      // Optionally update membership status from 'invited' to 'active'
      // Get auth context to determine user type
      const { data: authContext } = await supabase.rpc('get_auth_context');
      if (authContext && authContext.length > 0) {
        const context = authContext[0];
        
        if (context.is_org_user) {
          // Update OrganizationUsers status
          const { error: orgUpdateError } = await supabase
            .from('OrganizationUsers')
            .update({ status: 'active' })
            .eq('user_id', userId)
            .eq('status', 'invited');

          if (orgUpdateError) {
            console.warn('[SetPassword] Error updating OrganizationUsers status:', orgUpdateError);
          } else {
            console.log('✅ OrganizationUsers status updated to active');
          }
        } else if (context.is_portal_user) {
          // Update CompanyPortalUsers status
          const { error: portalUpdateError } = await supabase
            .from('CompanyPortalUsers')
            .update({ status: 'active' })
            .eq('user_id', userId)
            .eq('status', 'invited');

          if (portalUpdateError) {
            console.warn('[SetPassword] Error updating CompanyPortalUsers status:', portalUpdateError);
          } else {
            console.log('✅ CompanyPortalUsers status updated to active');
          }
        }
      }
      
      setMsg('✅ Password creado. Redirigiendo...');
      
      // Get fresh session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        // Set auth state
        setAuth(
          {
            id: updateData.user.id,
            email: updateData.user.email || '',
            name: userMetadata.name || updateData.user.email || '',
            role: 'user',
          },
          session.access_token
        );

        // Background enrich profile (no await)
        getUserProfile(updateData.user.id)
          .then((profile) => {
            if (!profile) return;
            useAuthStore.getState().updateUser({
              name: profile.name || userMetadata.name || updateData.user?.email || '',
              role: (profile.role as 'user' | 'admin') || 'user',
              department: profile.department,
              position: profile.position,
            });
          })
          .catch(() => {});

        // Redirect to dashboard after a short delay
        setTimeout(() => {
          navigate.navigate('/dashboard', true);
        }, 1500);
      } else {
        // If no session, redirect to login
        setMsg('⚠️ Error: No se pudo crear la sesión. Redirigiendo a login...');
        setTimeout(() => {
          navigate.navigate('/login', true);
        }, 2000);
      }
    }
  };

  if (checkingSession) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-white">
        <div className="text-center">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-sm text-muted-foreground">Validating magic link...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex">
      {/* Left Side - Set Password Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Set Password</h2>
              <p className="text-muted-foreground text-sm">
                {userEmail 
                  ? `Create a new password for ${userEmail}`
                  : 'Create a new password'
                }
              </p>
              {msg && (
                <div className={`mt-3 p-3 rounded text-sm ${
                  msg.includes('✅') 
                    ? 'bg-green-50 border border-green-200 text-green-800' 
                    : 'bg-red-50 border border-red-200 text-red-700'
                }`}>
                  {msg}
                </div>
              )}
            </div>

            <div className="space-y-4">
              <div>
                <label htmlFor="password" className="block text-sm font-medium text-foreground mb-2">
                  New password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="New password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
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

              <div>
                <label htmlFor="confirm" className="block text-sm font-medium text-foreground mb-2">
                  Confirm password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="confirm"
                    type={showConfirm ? 'text' : 'password'}
                    placeholder="Confirm password"
                    value={confirm}
                    onChange={(e) => setConfirm(e.target.value)}
                    className="w-full pl-10 pr-10 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    required
                    minLength={8}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirm(!showConfirm)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <button
                onClick={onSave}
                disabled={loading || !password || !confirm}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
                ) : (
                  <>
                    Save password
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Right Side - Brand Background */}
      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#172554' }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center gap-3">
              <Lock size={48} style={{ color: 'var(--primary-brand-hex)' }} />
              <span className="text-4xl font-semibold text-white">Secure Your Account</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
