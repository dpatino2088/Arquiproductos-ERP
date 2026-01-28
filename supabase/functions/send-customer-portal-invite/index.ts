// Supabase Edge Function: send-customer-portal-invite
// Invites company portal users via Supabase Auth SMTP (PKCE)
// - Upserts public."CompanyPortalUsers" (status=invited)
// - Sends invite email with redirect to your frontend /auth/callback?next=/set-password
// - Returns ok + redirect_to (and invite meta for debugging)
//
// REQUIRED SECRETS (Supabase Dashboard → Edge Functions → Secrets):
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - APP_ORIGIN   (e.g. http://localhost:5173  |  https://your-domain.com)
//
// Frontend should call:
// supabase.functions.invoke('send-customer-portal-invite', { body: { company_id, portal_user_email, role, redirect_to }})
//
// NOTE: redirect_to is optional; if not provided, APP_ORIGIN is used.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type PortalRole = "member" | "member_manager";

type Payload = {
  organization_id: string;
  company_id: string;
  portal_user_email: string;
  portal_user_name?: string | null;
  role: PortalRole;
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

  const { organization_id, company_id, portal_user_email, portal_user_name, role, redirect_to } = payload;

  // Validate company_id
  if (!company_id || typeof company_id !== "string") {
    return json({ error: "Missing or invalid company_id" }, 400);
  }
  if (!isUuid(company_id)) {
    return json(
      { error: "Invalid company_id format. Must be a valid UUID." },
      400
    );
  }

  // Validate portal_user_email
  if (!portal_user_email || typeof portal_user_email !== "string") {
    return json({ error: "Missing or invalid portal_user_email" }, 400);
  }
  const normalizedEmail = portal_user_email.trim().toLowerCase();
  if (!isEmail(normalizedEmail)) {
    return json({ error: "Invalid email format" }, 400);
  }

  // Validate role
  const allowedRoles: PortalRole[] = ["member", "member_manager"];
  if (!role || !allowedRoles.includes(role)) {
    return json(
      { error: `Invalid role. Must be one of: ${allowedRoles.join(", ")}` },
      400
    );
  }

  // ✅ Redirect MUST be your frontend callback
  const safeOverride = safeRedirectTo(redirect_to);

  // ✅ CRITICAL: Build clean URL without spaces
  const baseRedirect = safeOverride 
    ? safeOverride.trim() 
    : `${effectiveOrigin.trim()}/auth/callback?next=/set-password`;

  const finalRedirectTo = baseRedirect;

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

    // 1) Upsert/insert CompanyPortalUsers (status=invited, using 'status' column)
    const { data: existingUser, error: existingErr } = await admin
      .from("CompanyPortalUsers")
      .select("id, deleted, user_id")
      .eq("company_id", company_id)
      .eq("portal_user_email", normalizedEmail)
      .maybeSingle();

    if (existingErr) {
      console.error("send-customer-portal-invite: existingUser lookup error:", existingErr);
      return json(
        { error: `Failed checking existing portal user: ${existingErr.message}` },
        500
      );
  }

    const nowIso = new Date().toISOString();

    if (existingUser && !existingUser.deleted) {
      const { error: updateError } = await admin
        .from("CompanyPortalUsers")
    .update({
          portal_user_name: portal_user_name ?? null,
          role,
          status: "invited", // ✅ Use 'status' column, not 'portal_user_status'
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (updateError) {
        console.error("send-customer-portal-invite: update CompanyPortalUsers error:", updateError);
        return json(
          { error: `Failed to update portal user: ${updateError.message}` },
          500
        );
  }
    } else if (existingUser && existingUser.deleted) {
      const { error: reactivateError } = await admin
        .from("CompanyPortalUsers")
        .update({
          portal_user_name: portal_user_name ?? null,
          role,
          status: "invited", // ✅ Use 'status' column
          deleted: false,
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          user_id: null, // reset for fresh accept
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (reactivateError) {
        console.error(
          "send-customer-portal-invite: reactivate CompanyPortalUsers error:",
          reactivateError
        );
        return json(
          {
            error: `Failed to reactivate portal user: ${reactivateError.message}`,
          },
          500
        );
      }
    } else {
      const { error: insertError } = await admin.from("CompanyPortalUsers").insert({
        organization_id: organization_id ?? null,
        company_id,
        portal_user_email: normalizedEmail,
        portal_user_name: portal_user_name ?? null,
        role,
        status: "invited", // ✅ Use 'status' column
        deleted: false,
        invited_at: nowIso,
        invited_by_user_id: invitedByUserId,
        user_id: null, // will link on accept
      });

      if (insertError) {
        console.error("send-customer-portal-invite: insert CompanyPortalUsers error:", insertError);
        return json(
          { error: `Failed to create portal user: ${insertError.message}` },
          500
        );
      }
    }

    // 2) Send Supabase Auth invite email (SMTP) with correct redirect
    const { data: inviteData, error: inviteError } =
      await admin.auth.admin.inviteUserByEmail(normalizedEmail, {
        redirectTo: finalRedirectTo,
        data: {
          company_id,
          role,
        },
      });

    if (inviteError) {
      console.error("send-customer-portal-invite: inviteUserByEmail error:", inviteError);
      return json(
        { error: `Failed to send invitation: ${inviteError.message}` },
        500
      );
  }

    // ✅ Return useful info for debugging
  return json({
    ok: true,
      email: normalizedEmail,
      company_id,
      role,
      redirect_to: finalRedirectTo,
      invite: inviteData ?? null,
    });
  } catch (error: any) {
    console.error("Unexpected error in send-customer-portal-invite:", error);
    return json({ error: error?.message || "Internal server error" }, 500);
  }
});
