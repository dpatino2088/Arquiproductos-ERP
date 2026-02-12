import React, { useState, useEffect } from 'react';
import { Lock, Eye, EyeOff, ArrowRight } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';

export default function SetPasswordPage() {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [msg, setMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [hasSession, setHasSession] = useState<boolean | null>(null); // null = checking

  // ✅ Validate session on mount
  useEffect(() => {
    const checkSession = async () => {
      try {
        const { data, error } = await supabase.auth.getSession();
        if (error) {
          console.error('[SetPassword] getSession error:', error);
          setHasSession(false);
          setMsg('No hay sesión activa. Por favor, abre el link de invitación nuevamente.');
          return;
      }

        if (!data.session) {
          console.error('[SetPassword] No session found');
          setHasSession(false);
          setMsg('No hay sesión activa. Por favor, abre el link de invitación nuevamente.');
          setTimeout(() => router.navigate('/login', true), 3000);
        return;
      }

        console.log('[SetPassword] Session OK, user:', data.session.user?.email);
        setHasSession(true);
      } catch (e) {
        console.error('[SetPassword] Fatal error checking session:', e);
        setHasSession(false);
        setMsg('Error verificando sesión. Intenta abrir el link nuevamente.');
      }
    };

    checkSession();
  }, []);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMsg(null);

    // ✅ Don't allow submit without session
    if (!hasSession) {
      setMsg('No hay sesión activa. Por favor, abre el link de invitación nuevamente.');
        return;
      }

    if (password.length < 8) {
      setMsg('La contraseña debe tener al menos 8 caracteres');
      return;
    }

    if (password !== confirm) {
      setMsg('Las contraseñas no coinciden');
      return;
    }

    setLoading(true);
    try {
      // ✅ Get current session
      const { data: sessionData } = await supabase.auth.getSession();
      const userId = sessionData.session?.user?.id;

      if (!userId) {
        throw new Error('No hay sesión activa');
      }

      const now = new Date().toISOString();
      const clearFlags = {
        must_change_password: false,
        temp_password_set_at: null,
        updated_at: now,
      };

      // ✅ IMPORTANT: Clear must_change_password in DB *before* updating password.
      // Otherwise onAuthStateChange (after updateUser) can run AuthGate while DB still has
      // needs_password=true, causing redirect back to /set-password.
      console.log('[SetPassword] Clearing must_change_password flags in DB first...');
      const { error: orgErr } = await supabase
        .from('OrganizationUsers')
        .update(clearFlags)
        .eq('user_id', userId);
      if (orgErr) console.warn('[SetPassword] OrganizationUsers update warning:', orgErr);

      const { error: portalErr } = await supabase
        .from('DealerUsers')
        .update(clearFlags)
        .eq('user_id', userId);
      if (portalErr) console.warn('[SetPassword] DealerUsers update warning:', portalErr);

      const { error: appErr } = await supabase
        .from('AppUsers')
        .update(clearFlags)
        .eq('auth_user_id', userId);
      if (appErr) console.warn('[SetPassword] AppUsers update warning:', appErr);

      console.log('[SetPassword] Flags cleared, now updating password in Auth...');
      const { error: passwordError } = await supabase.auth.updateUser({ password });
      if (passwordError) throw passwordError;

      console.log('[SetPassword] Password and flags updated successfully');
      setMsg('✅ Contraseña establecida correctamente');
      setTimeout(() => router.navigate('/dashboard', true), 800);
    } catch (error: any) {
      console.error('[SetPassword] Error setting password:', error);
      setMsg(error?.message || 'Error al establecer contraseña');
    } finally {
      setLoading(false);
  }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-white p-8">
        <div className="w-full max-w-md">
        <div className="bg-white border border-gray-200 rounded-lg py-8 px-8 shadow-card">
          <div className="mb-8 text-center">
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <Lock className="w-8 h-8 text-primary" />
            </div>
              <h2 className="text-2xl font-semibold text-foreground mb-2">Set Password</h2>
              <p className="text-muted-foreground text-sm">
              Crear una nueva contraseña
              </p>
          </div>

              {msg && (
            <div className={`mb-6 p-3 rounded-md text-sm ${
                  msg.includes('✅') 
                ? 'bg-green-50 text-green-700 border border-green-200'
                : 'bg-red-50 text-red-700 border border-red-200'
                }`}>
                  {msg}
                </div>
              )}

          <form onSubmit={onSubmit} className="space-y-4">
              <div>
              <label className="block text-sm font-medium text-foreground mb-2">
                Nueva contraseña
                </label>
                <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-10 pr-10 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                  placeholder="Mínimo 8 caracteres"
                  disabled={loading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div>
              <label className="block text-sm font-medium text-foreground mb-2">
                Confirmar contraseña
                </label>
                <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    type={showConfirm ? 'text' : 'password'}
                    value={confirm}
                    onChange={(e) => setConfirm(e.target.value)}
                  className="w-full pl-10 pr-10 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                  placeholder="Repite la contraseña"
                  disabled={loading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirm(!showConfirm)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  >
                    {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <button
              type="submit"
              disabled={loading || password.length < 8 || password !== confirm}
              className="w-full bg-primary text-primary-foreground py-2 px-4 rounded-md hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 transition-colors"
              >
                {loading ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                  Guardando...
                </>
                ) : (
                  <>
                  Guardar contraseña
                    <ArrowRight className="w-4 h-4" />
                  </>
                )}
              </button>
          </form>
        </div>
      </div>
    </div>
  );
}
