import React, { useEffect, useState } from "react";
import { supabase } from "../../lib/supabase/client";
import { router } from "../../lib/router";

type OtpType = "invite" | "recovery" | "email" | "email_change";

// Helper function to wait for session (similar to AuthCallback)
async function waitForSession(maxMs = 4000): Promise<any> {
  const first = await supabase.auth.getSession();
  if (first.data.session?.user) return first.data.session;

  return await new Promise<any>((resolve) => {
    const started = Date.now();
    const { data: sub } = supabase.auth.onAuthStateChange((_event: string, session: { user?: { id: string } } | null) => {
      if (session?.user) {
        sub.subscription.unsubscribe();
        resolve(session);
      }
    });

    const t = setInterval(async () => {
      const { data } = await supabase.auth.getSession();
      if (data.session?.user) {
        clearInterval(t);
        sub.subscription.unsubscribe();
        resolve(data.session);
      } else if (Date.now() - started > maxMs) {
        clearInterval(t);
        sub.subscription.unsubscribe();
        resolve(null);
      }
    }, 250);
  });
}

export default function AcceptInvitePage() {
  const [msg, setMsg] = useState<string>("Verificando invitación...");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const url = new URL(window.location.href);
        
        // Log all URL params for debugging
        console.log('[AcceptInvite] URL:', url.href);
        console.log('[AcceptInvite] Query params:', Object.fromEntries(url.searchParams));
        console.log('[AcceptInvite] Hash:', url.hash);
        
        const token_hash = url.searchParams.get("token_hash");
        const type = (url.searchParams.get("type") || "invite") as OtpType;
        const next = url.searchParams.get("next") || "/set-password";

        // ✅ OPCIÓN 1: Esperar a que Supabase procese el token automáticamente (implicit flow)
        // Supabase puede tardar un poco en procesar el token cuando redirige
        setMsg("Esperando procesamiento de Supabase...");
        const session = await waitForSession(4000);
        
        if (session?.user) {
          const userEmail = session.user.email || "unknown";
          console.log(`[AcceptInvite] ✅ Session found! User: ${userEmail}`);
          setMsg("✅ Sesión creada. Redirigiendo...");
          setTimeout(() => router.navigate(next, true), 500);
          return;
        }

        // ✅ OPCIÓN 2: Si NO hay sesión después de esperar, intentar verifyOtp con token_hash
        if (!token_hash) {
          console.error('[AcceptInvite] No token_hash and no session found after waiting');
          setError("Link inválido (missing token). Pide un nuevo link de invitación.");
          setMsg("No se pudo verificar.");
          setTimeout(() => router.navigate("/login", true), 2500);
          return;
        }

        setMsg("Creando sesión con verifyOtp...");

        const { data, error } = await supabase.auth.verifyOtp({
          token_hash,
          type,
        });

        if (error) {
          console.error("[AcceptInvite] verifyOtp error:", error);
          setError(error.message || "No se pudo verificar el link.");
          setMsg("Error verificando link.");
          setTimeout(() => router.navigate("/login", true), 2500);
          return;
        }

        // ✅ Confirmación: verifyOtp OK
        console.log("[AcceptInvite] verifyOtp OK. Data:", data);

        // Refrescar session después de verifyOtp
        const { data: newSessionData, error: newSessionError } = await supabase.auth.getSession();
        
        if (newSessionError) {
          console.error("[AcceptInvite] getSession error:", newSessionError);
        } else {
          const hasSession = !!newSessionData.session;
          const userEmail = newSessionData.session?.user?.email || "unknown";
          console.log(`[AcceptInvite] getSession user: ${userEmail}. Session? ${hasSession}`);
        }

        setMsg("✅ Invitación verificada. Redirigiendo...");
        setTimeout(() => router.navigate(next, true), 300);
      } catch (e: any) {
        console.error('[AcceptInvite] Fatal error:', e);
        setError(e?.message || "Error inesperado verificando invitación.");
        setMsg("Error.");
        setTimeout(() => router.navigate("/login", true), 2500);
      }
    })();
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center bg-white">
      <div className="w-full max-w-md border border-gray-200 rounded-lg p-6 shadow-card">
        <h1 className="text-lg font-semibold mb-2">Aceptando invitación</h1>
        <p className="text-sm text-muted-foreground">{msg}</p>

        {error && (
          <div className="mt-4 p-3 rounded-md text-sm bg-red-50 text-red-700 border border-red-200">
            {error}
          </div>
        )}
      </div>
    </div>
  );
}
