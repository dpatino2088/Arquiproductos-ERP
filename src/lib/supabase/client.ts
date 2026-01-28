// src/lib/supabase/client.ts
import { createClient } from "@supabase/supabase-js";
import { logger } from "../logger";
import { devLog } from "../dev-logger";
import { useSupabaseStatus } from "../services/supabase-status";

const getSupabaseConfig = () => {
  const url = import.meta.env.VITE_SUPABASE_URL || "";
  const key =
    import.meta.env.VITE_SUPABASE_ANON_KEY ||
    import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
    "";

  devLog("🔧 Supabase config loaded:", {
    url: url || "MISSING",
    hasKey: !!key,
    keyLength: key?.length || 0,
    keyStart: key?.substring(0, 20) || "N/A",
  });

  return { url, key };
};

const { url: supabaseUrl, key: supabaseAnonKey } = getSupabaseConfig();

// ✅ Telemetry/agent-log blocker (CSP safe)
if (typeof window !== "undefined") {
  const originalFetch = window.fetch;

  // Avoid double-wrapping fetch (HMR)
  // @ts-ignore
  if (!(window as any).__adaptio_fetch_wrapped__) {
    // @ts-ignore
    (window as any).__adaptio_fetch_wrapped__ = true;

  window.fetch = async (...args) => {
      const reqUrl = args[0]?.toString() || "";

      // Block cursor/agent ingest / telemetry
      // ✅ NO rechazar (rechazar puede tumbar el UI si alguien hace await fetch sin try/catch)
      // Devolvemos 204 para "simular" éxito silencioso.
      if (
        reqUrl.includes("127.0.0.1:7242") ||
        reqUrl.includes("/ingest/") ||
        reqUrl.includes(":7242")
      ) {
        return new Response(null, { status: 204 });
      }

      // ✅ CRITICAL: DO NOT INTERCEPT EDGE FUNCTION CALLS
      // Edge Functions use URLs like: https://[project].supabase.co/functions/v1/[function-name]
      if (reqUrl.includes("/functions/v1/")) {
        return originalFetch(...args);
      }

      const isSupabaseRequest =
        (supabaseUrl && reqUrl.includes(supabaseUrl)) ||
        reqUrl.includes("/auth/") ||
        reqUrl.includes("/rest/v1/");

      if (!isSupabaseRequest) return originalFetch(...args);

      const start = Date.now();
    try {
      const res = await originalFetch(...args);

        // Track only server errors (500+)
      if (res.status >= 500) {
        logger.error("Supabase server error", undefined, {
            url: reqUrl,
          status: res.status,
          statusText: res.statusText,
            duration: Date.now() - start,
        });

          // Update status store (best effort)
        try {
            const st = useSupabaseStatus.getState();
            st?.recordError?.({
            message: `Server error ${res.status}`,
            status: res.status,
          });
          } catch {}
      }

      return res;
    } catch (err: any) {
        logger.error(
          "Supabase request failed",
          err instanceof Error ? err : undefined,
          { url: reqUrl, duration: Date.now() - start }
        );

      try {
          const st = useSupabaseStatus.getState();
          st?.recordError?.(err);
        } catch {}

      throw err;
    }
  };
}
}

// ✅ ONE Supabase client singleton (fixes "Multiple GoTrueClient instances detected")
const createSupabaseSingleton = () =>
  createClient(
    supabaseUrl || "https://placeholder.supabase.co",
    supabaseAnonKey || "placeholder-key",
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        // ✅ IMPORTANT: Enable detectSessionInUrl for magic links to work automatically
        // AuthCallback will still handle explicit flows (code, token_hash) but this helps with hash-based flows
        detectSessionInUrl: true,
      },
      global: {
        headers: { "X-Client-Info": "adaptio-erp" },
      },
    }
  );

// @ts-ignore
const g = globalThis as any;
export const supabase =
  g.__adaptio_supabase__ ?? (g.__adaptio_supabase__ = createSupabaseSingleton());

export const getCurrentUser = async () => {
  try {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    return data.user ?? null;
  } catch (e) {
    logger.error("Error getting current user", e instanceof Error ? e : undefined);
    return null;
  }
};

export const getUserProfile = async (userId: string | null | undefined) => {
  // ✅ Guard: si no hay userId, NO busques profile
  if (!userId) return null;

  try {
    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .single();

    if (error) {
      // ✅ NO revientes la app por profile missing (es común que no exista)
      if (error.code === "PGRST116") return null;
      throw error;
    }

    return data ?? null;
  } catch (e) {
    // ✅ Log warning pero retorna null (no bloquees la app)
    // ✅ Solo primitivos en errorDetails para evitar "[circular]" al serializar
    const err = e as { message?: string; code?: string; name?: string; stack?: string; details?: unknown };
    const errorDetails =
      e instanceof Error
        ? { message: e.message, name: e.name, ...(import.meta.env.DEV && e.stack ? { stack: e.stack } : {}) }
        : typeof e === "object" && e !== null
        ? {
            message: (err.message && String(err.message)) || String(e),
            code: err.code != null ? String(err.code) : undefined,
            details: err.details != null ? (typeof err.details === "object" ? "[object]" : String(err.details).slice(0, 120)) : undefined,
          }
        : { message: String(e) };

    logger.warn("Error getting user profile", errorDetails);
    return null;
  }
};
