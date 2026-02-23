import { useEffect, useRef } from "react";
import { supabase } from "../../lib/supabase/client";
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

function parseHashParams() {
  const hash = window.location.hash || "";
  return new URLSearchParams(hash.replace(/^#/, ""));
}

function normalizeEmail(e: string | null) {
  return (e ?? "").toString().trim().toLowerCase();
}

export default function AuthCallbackPage() {
  const didRun = useRef(false);

  useEffect(() => {
    // ✅ Prevent double execution in React StrictMode (dev)
    if (didRun.current) return;
    didRun.current = true;

    let cancelled = false;

    (async () => {
      const url = new URL(window.location.href);
      const next = safeNext(url.searchParams.get("next"));
      const loginUrl = `/login?next=${encodeURIComponent(next)}`;
      const goToLoginOrReset = () => {
        if (next === "/auth/reset-password") router.navigate("/reset-password", true);
        else router.navigate(loginUrl, true);
      };

      try {
        console.log("[AuthCallback] url:", window.location.href);
        console.log("[AuthCallback] search:", window.location.search);
        console.log("[AuthCallback] hash:", window.location.hash);

        // ✅ email (para detectar mismatch)
        const inviteEmail = normalizeEmail(url.searchParams.get("email")); // viene en tu magiclink redirect_to

        // =====================================================
        // 0) Si YA hay sesión, validar mismatch con email del link
        // =====================================================
        {
          const current = await supabase.auth.getSession();
          const currentEmail = normalizeEmail(current.data.session?.user?.email ?? null);

          if (inviteEmail && currentEmail && inviteEmail !== currentEmail) {
            console.warn("[AuthCallback] invite mismatch", { inviteEmail, currentEmail });

            // Guardar el link actual para reabrirlo luego
            sessionStorage.setItem("pending_invite_url", window.location.href);

            // Mandar al login con reason
            if (!cancelled) {
              router.navigate(
                `${loginUrl}&reason=invite_mismatch&email=${encodeURIComponent(inviteEmail)}`,
                true
              );
            }
            return;
          }
        }

        // =====================================================
        // 1) PKCE flow (OAuth / email link con ?code=)
        // =====================================================
        const code = url.searchParams.get("code");
        if (code) {
          console.log("[AuthCallback] PKCE code detected");
          const { error } = await supabase.auth.exchangeCodeForSession(code);

          if (error) {
            console.error("[AuthCallback] exchangeCodeForSession error:", error);
            if (!cancelled) goToLoginOrReset();
            return;
          }
        } else {
          // =====================================================
          // 2) Magiclink / Invite flow (tokens en URL hash)
          // =====================================================
          const hash = window.location.hash;
          const hp = parseHashParams();
          const accessToken = hp.get("access_token");
          const refreshToken = hp.get("refresh_token");
          const type = hp.get("type"); // invite | magiclink | recovery

          console.log("[AuthCallback] hash type:", type);
          console.log("[AuthCallback] has access_token:", !!accessToken);
          console.log("[AuthCallback] full hash:", hash);

          if (accessToken) {
            console.log("[AuthCallback] Setting session from hash tokens...");
            const { data, error } = await supabase.auth.setSession({
              access_token: accessToken,
              refresh_token: refreshToken || "",
            });

            if (error || !data.session) {
              console.error("[AuthCallback] setSession from hash failed:", error);
              if (!cancelled) goToLoginOrReset();
              return;
            }

            console.log("[AuthCallback] ✅ Session set from hash");
            // ✅ Remove hash para que no se reprocesa al refresh
            window.history.replaceState({}, document.title, url.pathname + url.search);

            // ✅ Recovery (reset password): ir directo al formulario de nueva contraseña sin esperar más pasos
            if (type === "recovery") {
              console.log("[AuthCallback] type=recovery -> /auth/reset-password");
              await useAuthStore.getState().syncSession();
              if (!cancelled) router.navigate("/auth/reset-password", true);
              return;
            }
          } else if (hash) {
            // Si hay hash pero no access_token, puede que Supabase aún no lo haya procesado
            // Esperar un poco y verificar si detectSessionInUrl lo procesó
            console.log("[AuthCallback] Hash present but no access_token, waiting for Supabase to process...");
            await new Promise((r) => setTimeout(r, 1000));
          } else {
            console.log("[AuthCallback] No code and no hash tokens, checking existing session");
          }
        }

        // =====================================================
        // 3) Confirmar sesión (con retry - detectSessionInUrl puede procesar el hash automáticamente)
        // =====================================================
        // Esperar un poco para que detectSessionInUrl procese el hash si está presente
        if (window.location.hash) {
          console.log("[AuthCallback] Hash detected, waiting for detectSessionInUrl to process...");
          await new Promise((r) => setTimeout(r, 800));
        }

        let sessionRes = await supabase.auth.getSession();

        // Si no hay sesión, esperar un poco más
        if (!sessionRes.data.session) {
          console.log("[AuthCallback] No session on first check, retrying...");
          await new Promise((r) => setTimeout(r, 500));
          sessionRes = await supabase.auth.getSession();
        }

        // Último intento
        if (!sessionRes.data.session) {
          console.log("[AuthCallback] No session on second check, final retry...");
          await new Promise((r) => setTimeout(r, 500));
          sessionRes = await supabase.auth.getSession();
        }

        if (sessionRes.error) {
          console.error("[AuthCallback] getSession error:", sessionRes.error);
          if (!cancelled) goToLoginOrReset();
          return;
        }

        if (!sessionRes.data.session) {
          console.warn("[AuthCallback] No session after callback");
          if (!cancelled) goToLoginOrReset();
          return;
        }

        console.log("[AuthCallback] ✅ session user:", sessionRes.data.session.user.email);

        // =====================================================
        // 4) Sync app auth store
        // =====================================================
        await useAuthStore.getState().syncSession();
        const store = useAuthStore.getState();

        console.log("[AuthCallback] store after sync:", {
          isAuthenticated: store.isAuthenticated,
          userEmail: store.user?.email,
        });

        if (!store.isAuthenticated) {
          await new Promise((r) => setTimeout(r, 150));
          await useAuthStore.getState().syncSession();
        }

        // =====================================================
        // 4.5) Si había pending_invite_url, reabrirlo ya logueado
        // (esto ayuda cuando antes te mandó a login por mismatch)
        // =====================================================
        const pendingInvite = sessionStorage.getItem("pending_invite_url");
        if (pendingInvite) {
          sessionStorage.removeItem("pending_invite_url");
          console.log("[AuthCallback] reopening pending invite url:", pendingInvite);
          window.location.href = pendingInvite; // full reload
          return;
        }

        // =====================================================
        // 4.7) Forzar /set-password si debe cambiar password
        // (tu flujo temp password)
        // =====================================================
        try {
          const { data: mustChangeData, error: mustChangeErr } =
            await supabase.rpc("get_must_change_password");
          
          if (!mustChangeErr && mustChangeData) {
            const result = Array.isArray(mustChangeData) ? mustChangeData[0] : mustChangeData;
            if (result?.must_change_password === true) {
              console.log("[AuthCallback] must_change_password=true -> /set-password");
              if (!cancelled) router.navigate("/set-password", true);
            return;
          }
          }
        } catch (e) {
          console.warn("[AuthCallback] could not check must_change_password:", e);
          // seguimos normal si falla
        }

        // =====================================================
        // 5) Redirect final
        // =====================================================
        console.log("[AuthCallback] redirect ->", next);
        if (!cancelled) router.navigate(next, true);
      } catch (e) {
        console.error("[AuthCallback] unexpected error:", e);
        if (!cancelled) {
          // Si falló en flujo de recovery, ir a la página para pedir nuevo enlace en vez de login
          if (next === "/auth/reset-password") {
            router.navigate("/reset-password", true);
          } else {
            const fallbackNext = next && next !== "/dashboard" ? next : "/dashboard";
            router.navigate(`/login?next=${encodeURIComponent(fallbackNext)}`, true);
          }
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center bg-white">
      <div className="w-full max-w-md border border-gray-200 rounded-lg p-6 shadow-card">
        <h1 className="text-lg font-semibold mb-2">Autenticando…</h1>
        <p className="text-sm text-muted-foreground">Procesando autenticación…</p>
      </div>
    </div>
  );
}
