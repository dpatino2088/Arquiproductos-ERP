# ⚠️ DEPRECATED - DO NOT USE

**Status:** DEPRECATED  
**Date:** 2026-01-12  
**Reason:** This function is deprecated and should NOT be used.

---

## Why Deprecated?

This function uses `generateLink` which:
1. Does NOT send emails automatically (requires Resend)
2. Uses a different flow than the standard Supabase Auth invite
3. Causes confusion with `type=magiclink` vs `type=invite`
4. Cannot be debugged easily

---

## Use Instead

### For Organization Users (internal)
```typescript
await supabase.functions.invoke('send-org-invite', {
  body: {
    organization_id: string,
    user_email: string,
    role: 'superadmin' | 'admin' | 'operator' | 'viewer' | 'member' | 'procurement' | 'finance'
  }
});
```

### For Company Portal Users (external customers)
```typescript
await supabase.functions.invoke('send-customer-portal-invite', {
  body: {
    company_id: string,
    portal_user_email: string,
    role: 'member' | 'member_manager'
  }
});
```

---

## Migration Path

If you see this function being called anywhere:

1. Replace with `send-org-invite` or `send-customer-portal-invite`
2. Update the payload structure (see above)
3. Test the invite flow end-to-end

---

## What Happens if You Keep Using This?

- ❌ Magic link emails instead of invite emails
- ❌ Wrong redirect URLs
- ❌ Session issues in `/set-password`
- ❌ Debugging nightmares

---

**DO NOT USE THIS FUNCTION. IT WILL BE DELETED IN THE FUTURE.**
