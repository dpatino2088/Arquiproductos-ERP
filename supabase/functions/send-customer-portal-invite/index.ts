// Supabase Edge Function: send-customer-portal-invite
// Invites dealer portal users via Supabase Auth (inviteUserByEmail).
// - Upserts public."DealerUsers" (status=invited)
// - Sends invite email via Auth with redirect to /auth/callback?next=/set-password
//
// Use dealer_id (Dealer ID). company_id is accepted as alias for backward compatibility.
// Frontend: { dealer_id, organization_id, portal_user_email, role?, portal_user_name?, redirect_to? }
//
// REQUIRED SECRETS: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, APP_ORIGIN

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type PortalRole = "member" | "member_manager";

type Payload = {
  organization_id?: string | null;
  dealer_id?: string | null;
  company_id?: string | null; // alias for dealer_id
  portal_user_email?: string | null;
  portal_user_name?: string | null;
  role?: PortalRole | null;
  redirect_to?: string | null;
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

  const { organization_id, dealer_id, company_id, portal_user_email, portal_user_name, role, redirect_to } = payload;

  // dealer_id is the correct param (Dealer ID). company_id accepted as alias.
  const dealerIdRaw = dealer_id ?? company_id;
  if (!dealerIdRaw || typeof dealerIdRaw !== "string") {
    return json({ error: "Missing dealer_id (or company_id)" }, 400);
  }
  if (!isUuid(dealerIdRaw)) {
    return json({ error: "Invalid dealer_id format. Must be a valid UUID." }, 400);
  }
  const dealerId = dealerIdRaw;

  // Email: support portal_user_email or email
  const rawEmail = portal_user_email ?? (payload as any).email;
  if (!rawEmail || typeof rawEmail !== "string") {
    return json({ error: "Missing portal_user_email or email" }, 400);
  }
  const normalizedEmail = rawEmail.trim().toLowerCase();
  if (!isEmail(normalizedEmail)) {
    return json({ error: "Invalid email format" }, 400);
  }

  const allowedRoles: PortalRole[] = ["member", "member_manager"];
  const portalRole: PortalRole = role && allowedRoles.includes(role) ? role : "member";

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

    // 1) Upsert DealerUsers (status=invited); table uses dealer_id (Dealer ID)
    const { data: existingUser, error: existingErr } = await admin
      .from("DealerUsers")
      .select("id, deleted, user_id")
      .eq("dealer_id", dealerId)
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
        .from("DealerUsers")
        .update({
          portal_user_name: portal_user_name ?? null,
          role: portalRole,
          status: "invited",
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (updateError) {
        console.error("send-customer-portal-invite: update DealerUsers error:", updateError);
        return json(
          { error: `Failed to update portal user: ${updateError.message}` },
          500
        );
      }
    } else if (existingUser && existingUser.deleted) {
      const { error: reactivateError } = await admin
        .from("DealerUsers")
        .update({
          portal_user_name: portal_user_name ?? null,
          role: portalRole,
          status: "invited",
          deleted: false,
          invited_at: nowIso,
          invited_by_user_id: invitedByUserId,
          user_id: null,
          updated_at: nowIso,
        })
        .eq("id", existingUser.id);

      if (reactivateError) {
        console.error("send-customer-portal-invite: reactivate DealerUsers error:", reactivateError);
        return json(
          { error: `Failed to reactivate portal user: ${reactivateError.message}` },
          500
        );
      }
    } else {
      const { error: insertError } = await admin.from("DealerUsers").insert({
        organization_id: organization_id ?? null,
        dealer_id: dealerId,
        portal_user_email: normalizedEmail,
        portal_user_name: portal_user_name ?? null,
        role: portalRole,
        status: "invited",
        deleted: false,
        invited_at: nowIso,
        invited_by_user_id: invitedByUserId,
        user_id: null,
      });

      if (insertError) {
        console.error("send-customer-portal-invite: insert DealerUsers error:", insertError);
        return json(
          { error: `Failed to create portal user: ${insertError.message}` },
          500
        );
      }
    }

    // 2) Send invite email via Supabase Auth (SMTP / inviteUserByEmail)
    const { data: inviteData, error: inviteError } =
      await admin.auth.admin.inviteUserByEmail(normalizedEmail, {
        redirectTo: finalRedirectTo,
        data: {
          dealer_id: dealerId,
          role: portalRole,
        },
      });

    if (inviteError) {
      console.error("send-customer-portal-invite: inviteUserByEmail error:", inviteError);
      return json(
        { error: `Failed to send invitation: ${inviteError.message}` },
        500
      );
    }

    return json({
      ok: true,
      email: normalizedEmail,
      dealer_id: dealerId,
      role: portalRole,
      redirect_to: finalRedirectTo,
      invite: inviteData ?? null,
    });
  } catch (error: any) {
    console.error("Unexpected error in send-customer-portal-invite:", error);
    return json({ error: error?.message || "Internal server error" }, 500);
  }
});
