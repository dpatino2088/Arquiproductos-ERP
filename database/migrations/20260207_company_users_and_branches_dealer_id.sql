-- ============================================================
-- Migration: company_users y branches — company_id → dealer_id
-- ============================================================
-- Ejecutar DESPUÉS de 20260207_rename_company_to_dealer.sql
-- Objetivo: Unificar nomenclatura dealer en tablas restantes.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) company_users: company_id → dealer_id
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'company_users' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public.company_users RENAME COLUMN company_id TO dealer_id;
    ALTER TABLE public.company_users
      DROP CONSTRAINT IF EXISTS company_users_company_id_fkey;
    ALTER TABLE public.company_users
      DROP CONSTRAINT IF EXISTS "company_users_company_id_fkey";
    ALTER TABLE public.company_users
      ADD CONSTRAINT company_users_dealer_id_fkey
      FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;
    RAISE NOTICE 'company_users: company_id renamed to dealer_id, FK updated.';
  ELSE
    RAISE NOTICE 'company_users: no company_id column (already migrated or table differs), skipping.';
  END IF;
END $$;

-- ============================================================
-- 2) branches: company_id → dealer_id (si la tabla existe)
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'branches')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'branches' AND column_name = 'company_id')
  THEN
    ALTER TABLE public.branches RENAME COLUMN company_id TO dealer_id;
    ALTER TABLE public.branches
      DROP CONSTRAINT IF EXISTS branches_company_id_fkey;
    ALTER TABLE public.branches
      DROP CONSTRAINT IF EXISTS "branches_company_id_fkey";
    ALTER TABLE public.branches
      ADD CONSTRAINT branches_dealer_id_fkey
      FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;
    RAISE NOTICE 'branches: company_id renamed to dealer_id, FK updated.';
  ELSE
    RAISE NOTICE 'branches: table or company_id column missing, skipping.';
  END IF;
END $$;

COMMIT;
