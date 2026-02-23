import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function randomPassword(length = 14) {
  const chars =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => chars[b % chars.length]).join("");
}

/**
 * Origin dinámico:
 * - En local: el browser manda Origin: http://localhost:5173
 * - En prod: mandará Origin: https://arquiproductos-erp.vercel.app
 * - Fallback: APP_ORIGIN o localhost
 */
function getAppOrigin(req: Request) {
  const origin = req.headers.get("origin");
  if (origin) return origin;

  const fallback = (Deno.env.get("APP_ORIGIN") ?? "http://localhost:5173").trim();
  return fallback;
}

type Body =
  | {
      kind: "org";
      organization_id: string;
      role: string;
      name?: string | null;
      email?: string;
      user_email?: string;
      debug_return_password?: boolean;
    }
  | {
      kind: "portal";
      organization_id: string;
      company_id?: string;
      dealer_id?: string;
      role: "dealer_member" | "dealer_manager" | "member" | "member_manager" | string;
      name?: string | null;
      email?: string;
      portal_user_email?: string;
      user_email?: string;
      status?: "invited" | "active" | "disabled";
      debug_return_password?: boolean;
    };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Use POST" }, 405);

  try {
    const body = (await req.json()) as Body;

    // --- secrets ---
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")?.trim();
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
    const RESEND_KEY = Deno.env.get("RESEND_API_KEY")?.trim();
    // ✅ Usar RESEND_FROM (como send-invite) o FROM_EMAIL como fallback
    const FROM_EMAIL = Deno.env.get("RESEND_FROM")?.trim() || Deno.env.get("FROM_EMAIL")?.trim();
    const ALLOW_RETURN_TEMP_PASSWORD = Deno.env.get("ALLOW_RETURN_TEMP_PASSWORD") === "true";

    if (!SUPABASE_URL) throw new Error("Missing secret: SUPABASE_URL");
    if (!SERVICE_ROLE) throw new Error("Missing secret: SUPABASE_SERVICE_ROLE_KEY");
    // ✅ RESEND_KEY y FROM_EMAIL son opcionales (email puede fallar, pero devolvemos temp_password)
    if (!RESEND_KEY) console.warn("[create-temp-user] Missing secret: RESEND_API_KEY. Email sending will fail.");
    if (!FROM_EMAIL) console.warn("[create-temp-user] Missing secret: RESEND_FROM or FROM_EMAIL. Email sending will fail.");

    const appOrigin = getAppOrigin(req);
    const loginUrl = `${appOrigin}/login`;

    // --- get email from any supported key ---
    const rawEmail =
      (body as any).email ??
      (body as any).user_email ??
      (body as any).portal_user_email;

    if (!rawEmail || typeof rawEmail !== "string") {
      return json(
        {
          ok: false,
          error:
            "Missing email. Provide one of: email | user_email | portal_user_email",
        },
        400,
      );
    }

    if (!body.kind || (body.kind !== "org" && body.kind !== "portal")) {
      return json({ ok: false, error: "Missing/invalid kind: org | portal" }, 400);
    }

    if (body.kind === "org" && !(body as any).organization_id) {
      return json({ ok: false, error: "Missing organization_id" }, 400);
    }

    const portalDealerId = (body as any).dealer_id ?? (body as any).company_id;
    if (body.kind === "portal" && !portalDealerId) {
      return json({ ok: false, error: "Missing dealer_id" }, 400);
    }

    const email = normalizeEmail(rawEmail);
    const tempPassword = randomPassword();
    const now = new Date().toISOString();

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
      auth: { persistSession: false },
    });

    // 1) Create auth user (or update if exists)
    // If the user already exists, createUser can fail. We'll try to find by email and then update password.
    let userId: string | null = null;

    const created = await admin.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
    });

    if (created.error) {
      // If already exists, try lookup + reset password
      const list = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
      if (list.error) throw list.error;

      const existing = list.data?.users?.find((u) => (u.email ?? "").toLowerCase() === email);
      if (!existing) throw created.error;

      userId = existing.id;

      const upd = await admin.auth.admin.updateUserById(userId, {
        password: tempPassword,
        email_confirm: true,
      });
      if (upd.error) throw upd.error;
    } else {
      userId = created.data.user?.id ?? null;
    }

    if (!userId) throw new Error("Could not resolve user id after create/update");

    // 2) Membership upsert (return id so frontend can open Permissions tab without extra fetch/RLS)
    let organizationUserId: string | null = null;
    if (body.kind === "org") {
      const { data: orgUserRow, error } = await admin
        .from("OrganizationUsers")
        .upsert(
          {
            organization_id: (body as any).organization_id,
            user_id: userId,
            user_email: email,
            user_name: (body as any).name ?? null,
            role: (body as any).role,
            status: "active",
            must_change_password: true,
            temp_password_set_at: now,
            deleted: false,
            updated_at: now,
          },
          { onConflict: "organization_id,user_email" },
        )
        .select("id")
        .single();

      if (error) throw new Error(`OrganizationUsers upsert failed: ${error.message}`);
      organizationUserId = orgUserRow?.id ?? null;

      // AppUsers: source of truth for org roles (useCurrentOrgRole, useAccessContext)
      const orgId = (body as any).organization_id;
      const orgRole = String((body as any).role ?? "operator").toLowerCase();
      const { data: existingApp } = await admin
        .from("AppUsers")
        .select("id")
        .eq("organization_id", orgId)
        .eq("user_type", "org")
        .eq("email", email)
        .eq("deleted", false)
        .maybeSingle();

      const appUserRow = {
        organization_id: orgId,
        user_type: "org",
        dealer_id: null,
        auth_user_id: userId,
        email,
        display_name: (body as any).name ?? null,
        role_code: orgRole,
        status: "active",
        must_change_password: true,
        temp_password_set_at: now,
        updated_at: now,
        deleted: false,
      };

      if (existingApp?.id) {
        const { error: auErr } = await admin
          .from("AppUsers")
          .update({
            auth_user_id: userId,
            display_name: appUserRow.display_name,
            role_code: appUserRow.role_code,
            status: appUserRow.status,
            must_change_password: true,
            temp_password_set_at: now,
            updated_at: now,
          })
          .eq("id", existingApp.id);
        if (auErr) throw new Error(`AppUsers update failed: ${auErr.message}`);
      } else {
        const { error: auErr } = await admin.from("AppUsers").insert({
          ...appUserRow,
          invited_by_app_user_id: null,
        });
        if (auErr) throw new Error(`AppUsers insert failed: ${auErr.message}`);
      }
    }

    if (body.kind === "portal") {
      const portalStatus = (body as any).status && ["invited", "active", "disabled"].includes((body as any).status)
        ? (body as any).status
        : "invited";
      const rawRole = (body as any).role;
      const dbRole = (rawRole === "dealer_manager" || rawRole === "member_manager" || rawRole === "manager") ? "dealer_manager" : "dealer_member";

      // Manual upsert: DB has unique index on (dealer_id, lower(portal_user_email)), not (dealer_id, portal_user_email)
      const { data: existingDu } = await admin
        .from("DealerUsers")
        .select("id")
        .eq("dealer_id", portalDealerId)
        .ilike("portal_user_email", email)
        .eq("deleted", false)
        .maybeSingle();

      const duRow = {
        organization_id: (body as any).organization_id,
        dealer_id: portalDealerId,
        user_id: userId,
        portal_user_email: email,
        portal_user_name: (body as any).name ?? null,
        role: dbRole,
        status: portalStatus,
        must_change_password: true,
        temp_password_set_at: now,
        deleted: false,
        updated_at: now,
      };

      if (existingDu?.id) {
        const { error: duError } = await admin
          .from("DealerUsers")
          .update(duRow)
          .eq("id", existingDu.id);
        if (duError) throw new Error(`DealerUsers update failed: ${duError.message}`);
      } else {
        const { error: duError } = await admin.from("DealerUsers").insert(duRow);
        if (duError) throw new Error(`DealerUsers insert failed: ${duError.message}`);
      }

      // AppUsers is source of truth for dealer portal users (Settings / Dealer Profile).
      const orgId = (body as any).organization_id;
      const { data: existing } = await admin
        .from("AppUsers")
        .select("id")
        .eq("organization_id", orgId)
        .eq("user_type", "dealer")
        .eq("dealer_id", portalDealerId)
        .eq("email", email)
        .eq("deleted", false)
        .maybeSingle();

      if (existing?.id) {
        await admin
          .from("AppUsers")
          .update({
            auth_user_id: userId,
            display_name: (body as any).name ?? null,
            role_code: dbRole,
            status: portalStatus,
            updated_at: now,
            must_change_password: true,
            temp_password_set_at: now,
          })
          .eq("id", existing.id);
      } else {
        const { error: auError } = await admin.from("AppUsers").insert({
          organization_id: orgId,
          user_type: "dealer",
          dealer_id: portalDealerId,
          auth_user_id: userId,
          email,
          display_name: (body as any).name ?? null,
          role_code: dbRole,
          status: portalStatus,
          invited_by_app_user_id: null,
          deleted: false,
          updated_at: now,
          must_change_password: true,
          temp_password_set_at: now,
        });
        if (auError) throw new Error(`AppUsers insert failed: ${auError.message}`);
      }
    }

    // 3) Send email via Resend (only if secrets are configured)
    let emailSent = false;
    let emailError: string | null = null;

    if (RESEND_KEY && FROM_EMAIL) {
      try {
        console.log("[create-temp-user] 📧 Preparing to send email...");
        console.log("[create-temp-user] To:", email);
        console.log("[create-temp-user] From:", FROM_EMAIL);
        console.log("[create-temp-user] Login URL:", loginUrl);
        console.log("[create-temp-user] RESEND_KEY length:", RESEND_KEY.length);
        
        const emailRes = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${RESEND_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: FROM_EMAIL,
            to: [email],
            subject: "Acceso a Adaptio (Password temporal)",
            html: `
              <div style="font-family:Arial,sans-serif;line-height:1.5;max-width:600px;margin:0 auto;padding:20px;">
                <h2 style="color:#333;">Tu usuario fue creado</h2>
                <p>Hola,</p>
                <p>Tu usuario ha sido creado en Adaptio. Aquí están tus credenciales temporales:</p>
                <div style="background:#f5f5f5;padding:15px;border-radius:5px;margin:20px 0;">
                  <p style="margin:5px 0;"><b>Email:</b> ${email}</p>
                  <p style="margin:5px 0;"><b>Password temporal:</b> <code style="background:#fff;padding:2px 6px;border-radius:3px;">${tempPassword}</code></p>
                </div>
                <p><a href="${loginUrl}" style="display:inline-block;background:#FF6B35;color:#fff;padding:10px 20px;text-decoration:none;border-radius:5px;margin:10px 0;">Iniciar Sesión</a></p>
                <p style="color:#666;font-size:12px;margin-top:20px;">Al iniciar sesión te pediremos cambiar la contraseña por seguridad.</p>
              </div>
            `,
          }),
        });

        if (emailRes.ok) {
          const emailData = await emailRes.json();
          emailSent = true;
          console.log("[create-temp-user] ✅ Email sent successfully. Resend ID:", emailData.id);
        } else {
          // ✅ Try to parse as JSON first (like send-invite does)
          let errorText: string;
          try {
            const errorJson = await emailRes.json();
            errorText = errorJson.message || JSON.stringify(errorJson);
          } catch {
            errorText = await emailRes.text();
          }
          emailError = `Resend error (${emailRes.status}): ${errorText}`;
          console.error("[create-temp-user] ❌ Email failed:", emailError);
          console.error("[create-temp-user] Response status:", emailRes.status);
        }
      } catch (e: any) {
        emailError = `Exception: ${e?.message ?? String(e)}`;
        console.error("[create-temp-user] Email exception:", emailError);
      }
    } else {
      console.warn("[create-temp-user] Skipping email send: RESEND_KEY or FROM_EMAIL not configured.");
      console.warn("[create-temp-user] RESEND_KEY present:", !!RESEND_KEY);
      console.warn("[create-temp-user] FROM_EMAIL present:", !!FROM_EMAIL);
    }

    // ✅ Return success with temp password (when requested or email failed)
    const debugReturnPassword = (body as any).debug_return_password === true;
    const shouldReturnPassword = debugReturnPassword || ALLOW_RETURN_TEMP_PASSWORD || !emailSent;
    
    return json({ 
      ok: true, 
      user_id: userId,
      organization_user_id: organizationUserId ?? undefined,
      email_sent: emailSent,
      // Return temp password if debug_return_password=true, ALLOW_RETURN_TEMP_PASSWORD=true, or email failed
      ...(shouldReturnPassword ? { temp_password: tempPassword } : {}),
      ...(emailError ? { email_error: emailError } : {}),
    });
  } catch (e: any) {
    console.error("[create-temp-user] error:", e);
    return json({ ok: false, error: e?.message ?? String(e) }, 500);
  }
});
