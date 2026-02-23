-- ========================================================
-- DIAGNOSTIC: Why Quotes dealer filter doesn't work for SuperAdmin
-- Run as postgres in Supabase SQL Editor
-- ========================================================

-- 1) Check what current_dealer_id() returns for each org user
-- (This is what RLS uses to filter)
SELECT
  au.email,
  au.user_type,
  au.role_code,
  au.auth_user_id,
  au.dealer_id AS appuser_dealer_id,
  pref.active_dealer_id,
  d.dealer_name AS active_dealer_name
FROM public."AppUsers" au
LEFT JOIN public."AppUserPreferences" pref ON pref.user_id = au.id
LEFT JOIN public."Dealers" d ON d.id = pref.active_dealer_id
WHERE au.user_type = 'org'
  AND au.deleted = false
ORDER BY au.email;

-- 2) Verify auth_user_id matches auth.users.id
SELECT
  au.email AS appuser_email,
  au.auth_user_id,
  u.id AS auth_users_id,
  u.email AS auth_email,
  CASE WHEN au.auth_user_id = u.id THEN 'MATCH' ELSE '** MISMATCH **' END AS status
FROM public."AppUsers" au
LEFT JOIN auth.users u ON u.id = au.auth_user_id
WHERE au.user_type = 'org'
  AND au.deleted = false
ORDER BY au.email;

-- 3) Check OrganizationUsers.user_id vs auth.users.id
SELECT
  ou.user_email,
  ou.user_id AS org_users_user_id,
  u.id AS auth_users_id,
  u.email AS auth_email,
  CASE WHEN ou.user_id = u.id THEN 'MATCH' ELSE '** MISMATCH **' END AS status
FROM public."OrganizationUsers" ou
LEFT JOIN auth.users u ON LOWER(u.email) = LOWER(ou.user_email)
WHERE ou.deleted = false
ORDER BY ou.user_email;

-- 4) AppUserPreferences: who has set an active dealer?
SELECT
  au.email,
  pref.active_dealer_id,
  d.dealer_name
FROM public."AppUserPreferences" pref
JOIN public."AppUsers" au ON au.id = pref.user_id
LEFT JOIN public."Dealers" d ON d.id = pref.active_dealer_id
ORDER BY au.email;

-- 5) All Quotes: dealer distribution
SELECT
  q.dealer_id,
  d.dealer_name,
  COUNT(*) AS total_quotes
FROM public."Quotes" q
LEFT JOIN public."Dealers" d ON d.id = q.dealer_id
WHERE q.deleted IS NOT TRUE
GROUP BY q.dealer_id, d.dealer_name
ORDER BY d.dealer_name;

-- 6) RLS policies on Quotes (schema check)
SELECT policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'Quotes'
ORDER BY policyname;
