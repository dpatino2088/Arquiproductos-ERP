/**
 * Edge Function: Delete user from Auth (auth.users).
 * Call after soft-deleting from OrganizationUsers/DealerUsers/AppUsers
 * so the email can be re-invited.
 *
 * Body: { auth_user_id: string }
 * Requires: JWT (authenticated user)
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Use POST" }, 405);

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")?.trim();
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return json({ ok: false, error: "Server configuration error" }, 500);
    }

    const body = (await req.json()) as { auth_user_id?: string };
    const authUserId = typeof body?.auth_user_id === "string" ? body.auth_user_id.trim() : null;
    if (!authUserId) {
      return json({ ok: false, error: "Missing auth_user_id" }, 400);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { error } = await admin.auth.admin.deleteUser(authUserId);
    if (error) {
      console.error("[delete-auth-user]", error);
      return json({ ok: false, error: error.message }, 400);
    }

    return json({ ok: true });
  } catch (e) {
    console.error("[delete-auth-user]", e);
    return json({ ok: false, error: (e as Error)?.message ?? "Unknown error" }, 500);
  }
});
