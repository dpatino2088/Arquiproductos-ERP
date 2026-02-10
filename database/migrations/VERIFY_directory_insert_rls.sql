-- ============================================================
-- VERIFY: políticas INSERT y funciones para Directory RLS portal
-- Ejecutar en Supabase SQL Editor tras aplicar
-- 20260210_directory_rls_portal_definitive.sql
-- ============================================================

-- 1) Políticas INSERT actuales en DirectoryContacts
SELECT
  polname AS policy_name,
  CASE polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT' WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' ELSE polcmd::text END AS command,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expression
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass
  AND polcmd = 'a'
ORDER BY polname;

-- 2) Políticas INSERT actuales en DirectoryCustomers
SELECT
  polname AS policy_name,
  CASE polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT' WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' ELSE polcmd::text END AS command,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expression
FROM pg_policy
WHERE polrelid = 'public."DirectoryCustomers"'::regclass
  AND polcmd = 'a'
ORDER BY polname;

-- 3) Definición de is_org_user_member
SELECT pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname = 'is_org_user_member';

-- 4) Definición de current_dealer_id
SELECT pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname = 'current_dealer_id';
