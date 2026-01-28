// Supabase Edge Function: send-org-invite
// Invites organization users via Supabase Auth SMTP (PKCE)
// - Upserts public."OrganizationUsers" (status=invited)
// - Sends invite email with redirect to your frontend /auth/callback?next=/set-password&email=...
// - Returns ok + redirect_to (and invite meta for debugging)
//
// REQUIRED SECRETS (Supabase Dashboard → Edge Functions → Secrets):
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - APP_ORIGIN   (e.g. http://localhost:5173  |  https://your-domain.com)
//
// Frontend should call:
// supabase.functions.invoke('send-org-invite', { body: { organization_id, user_email, role, redirect_to }})
//
// NOTE: redirect_to is optional; if not provided, APP_ORIGIN is used.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type OrgRole = "owner" | "admin" | "member" | "viewer" | "superadmin" | "operator" | "procurement" | "finance";

type Payload = {
  organization_id: string;
  user_email: string;
  user_name?: string | null;
  role: OrgRole;
  redirect_to?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    },
  });
}

function isUuid(v: string) {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(v);
}

function isEmail(v: string) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(v);
}

function safeRedirectTo(raw: string | undefined | null) {
  if (!raw) return null;
  const v = raw.trim();
  if (!v) return null;

  try {
    const u = new URL(v);
    if (u.protocol !== "http:" && u.protocol !== "https:") return null;
    return u.toString();
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  // ✅ Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Use POST" }, 405);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  // ✅ CRITICAL: trim() to remove any spaces
  const APP_ORIGIN = (Deno.env.get("APP_ORIGIN") ?? "").trim();

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json(
      { error: "Missing env vars SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
      500
    );
  }

  // Default frontend origin if not set (local dev fallback)
  // ✅ Ensure no spaces in the final URL
  const effectiveOrigin = (APP_ORIGIN || "http://localhost:5173").trim();

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { organization_id, user_email, role, redirect_to } = payload;

  // Validate organization_id
  if (!organization_id || typeof organization_id !== "string") {
    return json({ error: "Missing or invalid organization_id" }, 400);
  }
  if (!isUuid(organization_id)) {
    return json(
      { error: "Invalid organization_id format. Must be a valid UUID." },
      400
    );
  }

  // Validate user_email
  if (!user_email || typeof user_email !== "string") {
    return json({ error: "Missing or invalid user_email" }, 400);
  }
  const normalizedEmail = user_email.trim().toLowerCase();
  if (!isEmail(normalizedEmail)) {
    return json({ error: "Invalid email format" }, 400);
  }

  // Validate role - allow all OrgRole types
  const allowedRoles: OrgRole[] = ["owner", "admin", "member", "viewer", "superadmin", "operator", "procurement", "finance"];
  if (!role || !allowedRoles.includes(role)) {
    return json(
      { error: `Invalid role. Must be one of: ${allowedRoles.join(", ")}` },
      400
    );
  }

  // ✅ Redirect MUST be your frontend callback AND include email= for mismatch detection in AuthCallback
  const safeOverride = safeRedirectTo(redirect_to);

  // ✅ CRITICAL: Build clean URL without spaces
  // Use /auth/callback which already handles invite flow correctly
  const baseRedirect = safeOverride 
    ? safeOverride.trim() 
    : `${effectiveOrigin.trim()}/auth/callback?next=/set-password`;

  const finalRedirectTo = baseRedirect.includes("email=")
    ? baseRedirect
    : `${baseRedirect}${baseRedirect.includes("?") ? "&" : "?"}email=${encodeURIComponent(normalizedEmail)}`;

  try {
    // Attempt to resolve inviter from Authorization header (optional)
    const authHeader = req.headers.get("Authorization");
    let invitedByUserId: string | null = null;
    
    if (authHeader?.toLowerCase().startsWith("bearer ")) {
      const token = authHeader.slice(7).trim();
      if (token) {
      try {
          const { data, error } = await admin.auth.getUser(token);
          if (!error) invitedByUserId = data.user?.id ?? null;
      } catch {
          // ignore
        }
      }
    }

    // 1) Upsert/insert OrganizationUsers (status=invited)
    const { data: existingUser, error: existingErr } = await admin
      .from("OrganizationUsers")
      .select("id, deleted, user_id")
      .eq("organization_id", organization_id)
      .eq("user_email", normalizedEmail)
      .maybeSingle();

    if (existingErr) {
      console.error("send-org-invite: existingUser lookup error:", existingErr);
      return json(
        { error: `Failed checking existing org user: ${existingErr.message}` },
        500
      );
    }

    const nowIso = new Date().toISOString();

    if (existingUser && !existingUser.deleted) {
      const { error: updateError } = await admin
        .from("OrganizationUsers")
        .update({
          user_name: payload.user_name ?? null,
          role,
          status: "invited",
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (updateError) {
        console.error("send-org-invite: update OrganizationUsers error:", updateError);
        return json(
          { error: `Failed to update organization user: ${updateError.message}` },
          500
        );
      }
    } else if (existingUser && existingUser.deleted) {
      const { error: reactivateError } = await admin
        .from("OrganizationUsers")
        .update({
          user_name: payload.user_name ?? null,
          role,
          status: "invited",
          deleted: false,
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          user_id: null, // reset for fresh accept
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (reactivateError) {
        console.error(
          "send-org-invite: reactivate OrganizationUsers error:",
          reactivateError
        );
        return json(
          {
            error: `Failed to reactivate organization user: ${reactivateError.message}`,
          },
          500
        );
      }
    } else {
      const { error: insertError } = await admin.from("OrganizationUsers").insert({
        organization_id,
        user_email: normalizedEmail,
        user_name: payload.user_name ?? null,
        role,
        status: "invited",
        deleted: false,
        invited_at: nowIso,
        invited_by_user_id: invitedByUserId,
        user_id: null, // will link on accept
      });

      if (insertError) {
        console.error("send-org-invite: insert OrganizationUsers error:", insertError);
        return json(
          { error: `Failed to create organization user: ${insertError.message}` },
          500
        );
      }
    }

    // 2) Send Supabase Auth invite email (SMTP) with correct redirect
    // Note: inviteUserByEmail doesn't support PKCE, but it works for invites
    // The callback will handle the session establishment
    const { data: inviteData, error: inviteError } =
      await admin.auth.admin.inviteUserByEmail(normalizedEmail, {
        redirectTo: finalRedirectTo,
        data: {
          organization_id,
          role,
        },
      });

    if (inviteError) {
      console.error("send-org-invite: inviteUserByEmail error:", inviteError);
      return json(
        { error: `Failed to send invitation: ${inviteError.message}` },
        500
      );
    }

    // ✅ Return useful info for debugging
    return json({
      ok: true,
      email: normalizedEmail,
      organization_id,
      role,
      redirect_to: finalRedirectTo,
      invite: inviteData ?? null,
    });
  } catch (error: any) {
    console.error("Unexpected error in send-org-invite:", error);
    return json({ error: error?.message || "Internal server error" }, 500);
  }
});
