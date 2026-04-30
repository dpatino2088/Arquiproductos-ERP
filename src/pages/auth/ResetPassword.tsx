import React, { useState, useEffect } from 'react';
import { ArrowLeft, Mail, CheckCircle, AlertCircle } from 'lucide-react';
import AdaptioMark from '../../components/AdaptioMark';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';

export default function ResetPassword() {
  const [email, setEmail] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  // Prefill email from URL when coming from Login (e.g. /reset-password?email=...)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const emailParam = params.get('email');
    if (emailParam?.trim()) {
      setEmail(emailParam.trim());
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) {
      setError('Ingresa tu correo electrónico');
      return;
    }
    const normalized = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalized)) {
      setError('Correo electrónico no válido');
      return;
    }

    setSending(true);
    setError('');

    try {
      const origin = typeof window !== 'undefined' ? window.location.origin : '';
      const redirectTo = `${origin.replace(/\/$/, '')}/auth/callback?next=/auth/reset-password`;
      const { error: err } = await supabase.auth.resetPasswordForEmail(normalized, {
        redirectTo,
      });

      if (err) throw err;
      setSent(true);
    } catch (err: any) {
      setError(err?.message || 'No se pudo enviar el enlace. Intenta de nuevo.');
    } finally {
      setSending(false);
    }
  };

  const handleBackToLogin = () => {
    router.navigate('/login', true);
  };

  if (sent) {
    return (
      <div className="min-h-screen flex">
        <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
          <div className="w-full max-w-md">
            <div className="lg:hidden text-center mb-8">
              <div className="mx-auto mb-4 flex items-center justify-center gap-2">
                <AdaptioMark size={32} color="var(--primary-brand-hex)" />
                <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
              </div>
            </div>

            <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
              <div className="mb-6 text-center">
                <div className="w-12 h-12 mx-auto mb-4 rounded-full bg-green-100 flex items-center justify-center">
                  <CheckCircle className="w-6 h-6 text-green-600" />
                </div>
                <h2 className="text-xl font-semibold text-foreground mb-2">Revisa tu correo</h2>
                <p className="text-muted-foreground text-sm">
                  Enviamos un enlace para restablecer tu contraseña a <strong>{email}</strong>.
                  Revisa la bandeja de entrada y la carpeta de spam.
                </p>
              </div>

              <button
                type="button"
                onClick={handleBackToLogin}
                className="w-full flex items-center justify-center gap-2 px-4 h-10 rounded text-white text-sm transition-colors"
                style={{ backgroundColor: '#404a63' }}
              >
                <ArrowLeft className="w-4 h-4" />
                Volver al inicio de sesión
              </button>
            </div>
          </div>
        </div>

        <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#404a63' }}>
          <div className="max-w-md text-center text-white">
            <div className="mb-8">
              <div className="w-20 h-20 bg-green-500/20 backdrop-blur-sm rounded-2xl mx-auto mb-6 flex items-center justify-center">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
              <h1 className="text-2xl font-bold mb-4">Enlace enviado</h1>
              <p className="text-white/80">
                Haz clic en el enlace del correo para elegir una nueva contraseña.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex">
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          <div className="lg:hidden text-center mb-8">
            <div className="mx-auto mb-4 flex items-center justify-center gap-2">
              <AdaptioMark size={32} color="var(--primary-brand-hex)" />
              <span className="text-2xl font-semibold text-gray-900">Adaptio</span>
            </div>
          </div>

          <div className="bg-white border border-gray-200 rounded-lg py-6 px-6 shadow-card">
            <div className="mb-6">
              <h2 className="text-2xl font-semibold text-foreground mb-2">Restablecer contraseña</h2>
              <p className="text-muted-foreground text-sm">
                Ingresa tu correo y te enviaremos un enlace para crear una nueva contraseña.
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-foreground mb-2">
                  Correo electrónico
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                  <input
                    id="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full pl-10 pr-3 h-10 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-primary/20 focus:border-primary/50"
                    placeholder="tu@correo.com"
                    required
                    autoComplete="email"
                  />
                </div>
              </div>

              {error && (
                <div className="flex items-center gap-2 text-sm text-red-600">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={sending || !email.trim()}
                className="w-full flex items-center justify-center gap-2 px-4 h-10 rounded text-white text-sm transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: '#404a63' }}
              >
                {sending ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    Enviando...
                  </>
                ) : (
                  'Enviar enlace de restablecimiento'
                )}
              </button>
            </form>

            <div className="mt-6 pt-4 border-t border-gray-200">
              <button
                type="button"
                onClick={handleBackToLogin}
                className="w-full flex items-center justify-center gap-2 px-4 h-10 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300 transition-colors"
              >
                <ArrowLeft className="w-4 h-4" />
                Volver al inicio de sesión
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12" style={{ backgroundColor: '#404a63' }}>
        <div className="max-w-md text-center text-white">
          <div className="mb-8">
            <div className="mx-auto mb-6 flex items-center justify-center gap-3">
              <AdaptioMark size={48} color="var(--primary-brand-hex)" />
              <span className="text-4xl font-semibold text-white">Adaptio</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
