import React, { useState } from "react";
import { Eye, EyeOff, Mail, Lock, ArrowRight, Box } from "lucide-react";
import { supabase, getUserProfile } from "../../lib/supabase/client";
import { useAuthStore } from "../../stores/auth-store";
import { router } from "../../lib/router";


function safeNext(raw: string | null) {
  if (!raw) return "/dashboard";
  try {
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      const u = new URL(raw);
      return u.pathname + u.search + u.hash;
    }
  } catch {}
  if (!raw.startsWith("/")) return "/dashboard";
  return raw;
}

export default function Login() {
  const { setAuth, setError } = useAuthStore();

  const [emailOrPhone, setEmailOrPhone] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState("");
  const [sendingOtp, setSendingOtp] = useState(false);
  const [connectionTest, setConnectionTest] = useState<{ status: 'idle' | 'testing' | 'ok' | 'fail'; message?: string }>({ status: 'idle' });

  const params = new URLSearchParams(window.location.search);
  const reason = params.get("reason");
  const showInviteMismatch = reason === "invite_mismatch";

  const next = safeNext(params.get("next"));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setLoginError(null);
    setError(null);
    
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
      
      if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes("placeholder")) {
        setLoginError(
          "Supabase no está configurado. Configura VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env.local y REINICIA Vite."
        );
        return;
      }

      const email = emailOrPhone.trim().toLowerCase();
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;

      if (data.user && data.session) {
        setAuth(
          {
            id: data.user.id,
            email: data.user.email || "",
            name: data.user.user_metadata?.name || data.user.email || "",
            role: "user",
          },
          data.session.access_token
        );

        // ✅ Check if user must change password (temp password flow)
        const { data: orgCheck } = await supabase
          .from('OrganizationUsers')
          .select('must_change_password')
          .eq('user_id', data.user.id)
          .eq('deleted', false)
          .maybeSingle();

        const { data: portalCheck } = await supabase
          .from('DealerUsers')
          .select('must_change_password')
          .eq('user_id', data.user.id)
          .eq('deleted', false)
          .maybeSingle();

        if (orgCheck?.must_change_password || portalCheck?.must_change_password) {
          console.log('[Login] User must change password, redirecting to /set-password');
          router.navigate('/set-password', true);
          return;
        }

        const pendingInvite = sessionStorage.getItem("pending_invite_url");
        if (pendingInvite) {
          sessionStorage.removeItem("pending_invite_url");
          window.location.href = pendingInvite;
          return;
        }

        router.navigate(next, true);

        getUserProfile(data.user.id)
          .then((profile) => {
            if (!profile) return;
            useAuthStore.getState().updateUser({
              name: profile.name || data.user?.email || "",
              role: (profile.role as "user" | "admin") || "user",
              department: profile.department,
              position: profile.position,
            });
          })
          .catch(() => {});
      }
    } catch (error: any) {
      const raw = error?.message || error?.toString?.() || "";
      const isFailedToFetch =
        raw === "Failed to fetch" || String(raw).toLowerCase().includes("failed to fetch");
      const isNetworkLike =
        isFailedToFetch ||
        /network|fetch|connection|cors|refused/i.test(raw);

      if (import.meta.env.DEV) {
        const url = import.meta.env.VITE_SUPABASE_URL || "";
        const masked = url ? `${url.slice(0, 12)}...${url.slice(-8)}` : "NO DEFINIDA";
        console.warn("[Login] Error:", raw, { supabaseUrl: masked, code: error?.code });
      }

      const origin = typeof window !== "undefined" ? window.location.origin : "http://localhost:5173";
      const msg = isNetworkLike
        ? `No se pudo conectar con Supabase. Si tienes internet y el proyecto está activo, revisa: 1) CORS en Supabase (Settings > API > allowed origins: ${origin}), 2) VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env.local (reinicia Vite tras cambiar). 3) Consola del navegador (F12) para el error exacto.`
        : raw || "Error al iniciar sesión";

      setLoginError(msg);
      setError(msg);
    } finally {
      setIsLoading(false);
    }
  };

  /** Prueba si el navegador puede conectar a Supabase (diagnóstico). */
  const handleTestConnection = async () => {
    const url = import.meta.env.VITE_SUPABASE_URL;
    const key = import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
    if (!url || !key || url.includes("placeholder")) {
      setConnectionTest({ status: 'fail', message: 'Faltan VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en .env.local' });
      return;
    }
    setConnectionTest({ status: 'testing' });
    try {
      const res = await fetch(`${url.replace(/\/$/, '')}/rest/v1/`, {
        method: 'HEAD',
        headers: { apikey: key, Accept: 'application/json' },
      });
      setConnectionTest({ status: 'ok', message: `Conexión OK (${res.status}). El fallo puede ser solo en Auth: revisa email/contraseña o configuración de Auth en Supabase.` });
    } catch (e: any) {
      const msg = e?.message || String(e);
      setConnectionTest({ status: 'fail', message: msg || 'Error desconocido' });
    }
  };

  const handleSendOtp = async () => {
    if (!emailOrPhone) {
      setLoginError("Please enter your email address");
      return;
    }

    const email = emailOrPhone.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setLoginError("Please enter a valid email address");
      return;
    }

    setSendingOtp(true);
    setLoginError(null);
    setError(null);

    try {
      // ✅ OTP sin emailRedirectTo (envía código, no magic link)
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: true,
          // NO incluir emailRedirectTo - esto envía OTP numérico
        },
      });

      if (error) throw error;
      setOtpSent(true);
    } catch (error: any) {
      setLoginError(error?.message || "Failed to send OTP code");
    } finally {
      setSendingOtp(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!otpCode || otpCode.length !== 6) {
      setLoginError("Please enter the 6-digit code");
      return;
    }

    setIsLoading(true);
    setLoginError(null);
    setError(null);

    try {
      const email = emailOrPhone.trim().toLowerCase();
      const { data, error } = await supabase.auth.verifyOtp({
        email,
        token: otpCode,
        type: 'email',
      });
      
      if (error) throw error;

      if (data.user && data.session) {
        setAuth(
          {
            id: data.user.id,
            email: data.user.email || "",
            name: data.user.user_metadata?.name || data.user.email || "",
            role: "user",
          },
          data.session.access_token
        );

        // ✅ Check if user must change password (temp password flow)
        const { data: orgCheck } = await supabase
          .from('OrganizationUsers')
          .select('must_change_password')
          .eq('user_id', data.user.id)
          .eq('deleted', false)
          .maybeSingle();

        const { data: portalCheck } = await supabase
          .from('DealerUsers')
          .select('must_change_password')
          .eq('user_id', data.user.id)
          .eq('deleted', false)
          .maybeSingle();
    
        if (orgCheck?.must_change_password || portalCheck?.must_change_password) {
          console.log('[Login] User must change password, redirecting to /set-password');
          router.navigate('/set-password', true);
          return;
        }

        const pendingInvite = sessionStorage.getItem("pending_invite_url");
        if (pendingInvite) {
          sessionStorage.removeItem("pending_invite_url");
          window.location.href = pendingInvite;
      return;
    }

        router.navigate(next, true);

        getUserProfile(data.user.id)
          .then((profile) => {
            if (!profile) return;
            useAuthStore.getState().updateUser({
              name: profile.name || data.user?.email || "",
              role: (profile.role as "user" | "admin") || "user",
              department: profile.department,
              position: profile.position,
            });
          })
          .catch(() => {});
      }
    } catch (error: any) {
      setLoginError(error?.message || "Invalid code. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };


  return (
    <div className="min-h-screen flex">
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          <div className="lg:hidden text-center mb-8">
            <div className="mx-auto mb-4 flex items-center justify-center gap-2">
              <Box size={32} style={{ color: "var(--primary-brand-hex)" }} />
              <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Sign In</h2>
              <p className="text-muted-foreground">Enter your credentials to access your company portal</p>

              {showInviteMismatch && (
                <div className="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">
                  Estás logueado con otra cuenta. Para aceptar esta invitación, cierra sesión o abre el link en una ventana
                  incógnita.
                </div>
              )}

              {loginError && (
                <div className="mt-3 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-700">{loginError}</div>
              )}
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="emailOrPhone" className="block text-sm font-medium text-foreground mb-2">
                  Email
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="emailOrPhone"
                    type="text"
                    value={emailOrPhone}
                    onChange={(e) => setEmailOrPhone(e.target.value)}
                    className="w-full pl-10 pr-3 h-8 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="Enter your email"
                    required
                  />
                </div>
              </div>

              <div>
                <label htmlFor="password" className="block text-sm font-medium text-foreground mb-2">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="password"
                    type={showPassword ? "text" : "password"}
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
              </div>

              <button
                type="submit"
                disabled={isLoading || otpSent}
                className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: "var(--primary-brand-hex)" }}
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

              <div className="mt-3 text-center">
                <button
                  type="button"
                  onClick={handleTestConnection}
                  disabled={connectionTest.status === 'testing'}
                  className="text-xs text-muted-foreground hover:text-foreground underline disabled:opacity-50"
                >
                  {connectionTest.status === 'testing' ? 'Probando...' : 'Probar conexión a Supabase'}
                </button>
                {connectionTest.status === 'ok' && connectionTest.message && (
                  <p className="mt-2 text-xs text-green-700">{connectionTest.message}</p>
                )}
                {connectionTest.status === 'fail' && connectionTest.message && (
                  <p className="mt-2 text-xs text-red-700">{connectionTest.message}</p>
                )}
              </div>
            </form>

            {otpSent ? (
              <form onSubmit={handleVerifyOtp} className="mt-4 space-y-4">
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
                <button
                  type="submit"
                  disabled={isLoading || otpCode.length !== 6}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 rounded text-white transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{ backgroundColor: "var(--primary-brand-hex)" }}
                >
                  {isLoading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Verifying...
                    </>
                  ) : (
                    "Verify Code"
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setOtpSent(false);
                    setOtpCode('');
                  }}
                  className="w-full text-sm text-primary hover:text-primary/80 transition-colors"
                >
                  Use different email
                </button>
              </form>
            ) : (
              <div className="mt-4">
                <button
                  type="button"
                  onClick={handleSendOtp}
                  disabled={sendingOtp || !emailOrPhone}
                  className="w-full flex items-center justify-center gap-2 px-4 h-8 border border-gray-300 rounded text-sm text-foreground hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {sendingOtp ? (
                    <>
                      <div className="w-4 h-4 border-2 border-gray-400 border-t-transparent rounded-full animate-spin" />
                      Sending...
                    </>
                  ) : (
                    <>
                      Send OTP code
                      <Mail className="w-4 h-4" />
                    </>
                  )}
                </button>
              </div>
            )}
          </div>

          <div className="text-center mt-6">
            <p className="text-sm text-muted-foreground">
              Don't have a user account or need reset Password? Contact your administrator.
            </p>
          </div>
        </div>
      </div>

      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: "#1f4456" }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center gap-3">
              <Box size={48} style={{ color: "var(--primary-brand-hex)" }} />
              <span className="text-4xl font-semibold text-white">Adaptio</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
