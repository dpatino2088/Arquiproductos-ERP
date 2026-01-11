-- ============================================================
-- Migration: Restructure to Companies + CompanyPortalUsers + Directory at Company level
-- ============================================================
-- OBJETIVO:
-- 1) Crear Companies (dealer/empresa que cotiza) relacionada con Organizations
-- 2) Cambiar CustomerPortalUsers -> CompanyPortalUsers con FK a company_id
-- 3) DirectoryCustomers/Contacts a nivel Company (no Organization)
-- 4) Arreglar RLS recursion en OrganizationUsers (42P17)
-- 5) Mantener transición compatible con datos existentes
-- ============================================================

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 0) Helper updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ============================================================
-- Helper functions SECURITY DEFINER para evitar recursión RLS
-- ============================================================

-- Función básica: verificar si usuario es miembro activo de una organization
CREATE OR REPLACE FUNCTION public.is_org_member(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_member IS 'Check if current user is an active member of organization. SECURITY DEFINER to avoid RLS recursion.';

-- Función: verificar si usuario es owner/admin de una organization
CREATE OR REPLACE FUNCTION public.is_org_owner_or_admin(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('owner', 'admin')
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_owner_or_admin IS 'Check if current user is owner/admin in organization. SECURITY DEFINER to avoid RLS recursion.';

-- Función: verificar si usuario es miembro de una company (via organization)
CREATE OR REPLACE FUNCTION public.is_company_member(p_company_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_company_member IS 'Check if current user is member of company via organization. SECURITY DEFINER to avoid RLS recursion.';

-- Función: verificar si usuario es owner/admin de una company (via organization)
CREATE OR REPLACE FUNCTION public.is_company_owner_or_admin(p_company_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('owner', 'admin')
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;

COMMENT ON FUNCTION public.is_company_owner_or_admin IS 'Check if current user is owner/admin of company via organization. SECURITY DEFINER to avoid RLS recursion.';

-- ============================================================
-- 1) Companies (dealer / empresa que cotiza al cliente final)
-- ============================================================
CREATE TABLE IF NOT EXISTS public."Companies" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE RESTRICT,

  company_name text NOT NULL,
  company_email text NULL,
  company_phone text NULL,

  status text NOT NULL DEFAULT 'active', -- simple MVP
  deleted boolean NOT NULL DEFAULT false,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  -- Constraint: al menos uno de organization_id debe existir
  CONSTRAINT companies_org_required CHECK (organization_id IS NOT NULL)
);

-- Trigger updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_companies_updated_at'
  ) THEN
    CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON public."Companies"
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Index
CREATE INDEX IF NOT EXISTS idx_companies_org ON public."Companies"(organization_id);
CREATE INDEX IF NOT EXISTS idx_companies_deleted ON public."Companies"(deleted) WHERE deleted = false;

-- RLS
ALTER TABLE public."Companies" ENABLE ROW LEVEL SECURITY;

-- RLS Policies para Companies (usuarios de la organization pueden ver sus companies)
-- Usar función SECURITY DEFINER para evitar recursión
DROP POLICY IF EXISTS companies_select_own_org ON public."Companies";
CREATE POLICY companies_select_own_org
  ON public."Companies"
  FOR SELECT
  USING (
    public.is_org_member(organization_id)
    AND deleted = false
  );

DROP POLICY IF EXISTS companies_insert_own_org ON public."Companies";
CREATE POLICY companies_insert_own_org
  ON public."Companies"
  FOR INSERT
  WITH CHECK (
    public.is_org_owner_or_admin(organization_id)
  );

DROP POLICY IF EXISTS companies_update_own_org ON public."Companies";
CREATE POLICY companies_update_own_org
  ON public."Companies"
  FOR UPDATE
  USING (
    public.is_org_owner_or_admin(organization_id)
  )
  WITH CHECK (
    public.is_org_owner_or_admin(organization_id)
  );

-- ============================================================
-- 2) CompanyPortalUsers (renombrar desde CustomerPortalUsers si existe)
-- ============================================================
-- Renombrar tabla si existe
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'CustomerPortalUsers'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers'
  ) THEN
    ALTER TABLE public."CustomerPortalUsers" RENAME TO "CompanyPortalUsers";
    
    -- Renombrar columnas explícitas si existen
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_email'
    ) THEN
      -- Ya tiene columnas explícitas, solo necesitamos cambiar FK
      NULL;
    ELSE
      -- Agregar columnas explícitas si no existen
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_email'
      ) THEN
        ALTER TABLE public."CompanyPortalUsers" ADD COLUMN portal_user_email text;
      END IF;
      
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_status'
      ) THEN
        ALTER TABLE public."CompanyPortalUsers" ADD COLUMN portal_user_status text DEFAULT 'draft';
      END IF;
      
      -- Migrar datos de columnas genéricas a explícitas
      UPDATE public."CompanyPortalUsers"
      SET portal_user_email = COALESCE(portal_user_email, email)
      WHERE portal_user_email IS NULL AND email IS NOT NULL;
      
      UPDATE public."CompanyPortalUsers"
      SET portal_user_status = COALESCE(portal_user_status, status::text)
      WHERE portal_user_status IS NULL AND status IS NOT NULL;
    END IF;
  END IF;
END $$;

-- Crear tabla si no existe (ya con company_id)
CREATE TABLE IF NOT EXISTS public."CompanyPortalUsers" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  company_id uuid NOT NULL REFERENCES public."Companies"(id) ON DELETE RESTRICT,
  user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,

  portal_user_email text NOT NULL,
  portal_user_status text NOT NULL DEFAULT 'draft',
  invited_by_user_id uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  invited_at timestamptz NULL,
  accepted_at timestamptz NULL,

  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Agregar company_id si no existe (transición desde customer_id)
DO $$
BEGIN
  -- Si existe customer_id pero no company_id, necesitamos migrar
  -- Pero sin customer_id->company_id directo, primero creamos una company por defecto si es necesario
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'customer_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'company_id'
  ) THEN
    -- Agregar company_id como nullable primero
    ALTER TABLE public."CompanyPortalUsers" ADD COLUMN company_id uuid REFERENCES public."Companies"(id);
    
    -- Crear una company por defecto para datos existentes (requiere organization_id)
    -- Esto se debe hacer manualmente o con un script separado si hay datos
    -- Por ahora solo agregamos la columna
  END IF;
  
  -- Agregar columnas explícitas si no existen
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_email'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" ADD COLUMN portal_user_email text;
    -- Copiar desde email si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'email'
    ) THEN
      UPDATE public."CompanyPortalUsers"
      SET portal_user_email = email
      WHERE portal_user_email IS NULL;
    END IF;
    ALTER TABLE public."CompanyPortalUsers" ALTER COLUMN portal_user_email SET NOT NULL;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'portal_user_status'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" ADD COLUMN portal_user_status text DEFAULT 'draft';
    -- Copiar desde status si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'CompanyPortalUsers' AND column_name = 'status'
    ) THEN
      UPDATE public."CompanyPortalUsers"
      SET portal_user_status = COALESCE(status::text, 'draft')
      WHERE portal_user_status IS NULL;
    END IF;
    ALTER TABLE public."CompanyPortalUsers" ALTER COLUMN portal_user_status SET NOT NULL;
  END IF;
END $$;

-- Trigger updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_companyportalusers_updated_at'
  ) THEN
    CREATE TRIGGER trg_companyportalusers_updated_at
    BEFORE UPDATE ON public."CompanyPortalUsers"
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Unique: 1 portal user email por company (no deleted)
CREATE UNIQUE INDEX IF NOT EXISTS companyportal_company_email_uniq
ON public."CompanyPortalUsers"(company_id, lower(portal_user_email))
WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_companyportalusers_company ON public."CompanyPortalUsers"(company_id);

-- RLS
ALTER TABLE public."CompanyPortalUsers" ENABLE ROW LEVEL SECURITY;

-- RLS Policies para CompanyPortalUsers (usar función SECURITY DEFINER)
DROP POLICY IF EXISTS companyportalusers_select_own_org ON public."CompanyPortalUsers";
CREATE POLICY companyportalusers_select_own_org
  ON public."CompanyPortalUsers"
  FOR SELECT
  USING (
    public.is_company_member(company_id)
    AND deleted = false
  );

DROP POLICY IF EXISTS companyportalusers_insert_own_org ON public."CompanyPortalUsers";
CREATE POLICY companyportalusers_insert_own_org
  ON public."CompanyPortalUsers"
  FOR INSERT
  WITH CHECK (
    public.is_company_owner_or_admin(company_id)
  );

DROP POLICY IF EXISTS companyportalusers_update_own_org ON public."CompanyPortalUsers";
CREATE POLICY companyportalusers_update_own_org
  ON public."CompanyPortalUsers"
  FOR UPDATE
  USING (
    public.is_company_owner_or_admin(company_id)
  );

-- ============================================================
-- 3) DirectoryCustomers a nivel Company (con fallback a organization_id para transición)
-- ============================================================
-- Agregar company_id si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN company_id uuid REFERENCES public."Companies"(id) ON DELETE RESTRICT;
    CREATE INDEX IF NOT EXISTS idx_dircustomers_company ON public."DirectoryCustomers"(company_id);
  END IF;
END $$;

-- Agregar columnas explícitas si no existen (con fallback a genéricas)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'customer_name'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN customer_name text;
    -- Migrar desde name si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'name'
    ) THEN
      UPDATE public."DirectoryCustomers"
      SET customer_name = name
      WHERE customer_name IS NULL;
    END IF;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'customer_email'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN customer_email text;
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'email'
    ) THEN
      UPDATE public."DirectoryCustomers"
      SET customer_email = email
      WHERE customer_email IS NULL;
    END IF;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'customer_phone'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" ADD COLUMN customer_phone text;
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers' AND column_name = 'phone'
    ) THEN
      UPDATE public."DirectoryCustomers"
      SET customer_phone = phone
      WHERE customer_phone IS NULL;
    END IF;
  END IF;
END $$;

-- Trigger updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_directorycustomers_updated_at'
  ) THEN
    CREATE TRIGGER trg_directorycustomers_updated_at
    BEFORE UPDATE ON public."DirectoryCustomers"
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dircustomers_company ON public."DirectoryCustomers"(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_dircustomers_org ON public."DirectoryCustomers"(organization_id) WHERE organization_id IS NOT NULL;

-- RLS (seleccionar por company_id o organization_id como fallback) usando funciones SECURITY DEFINER
ALTER TABLE public."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dircustomers_select_own_org_or_company ON public."DirectoryCustomers";
CREATE POLICY dircustomers_select_own_org_or_company
  ON public."DirectoryCustomers"
  FOR SELECT
  USING (
    (
      (company_id IS NOT NULL AND public.is_company_member(company_id))
      OR
      (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    )
    AND deleted = false
  );

-- ============================================================
-- 4) DirectoryContacts a nivel Company
-- ============================================================
-- Agregar company_id si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN company_id uuid REFERENCES public."Companies"(id) ON DELETE RESTRICT;
    CREATE INDEX IF NOT EXISTS idx_dircontacts_company ON public."DirectoryContacts"(company_id);
  END IF;
END $$;

-- Agregar columnas explícitas si no existen
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_name'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_name text;
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'name'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_name = name
      WHERE contact_name IS NULL;
    END IF;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_email'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_email text;
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'email'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_email = email
      WHERE contact_email IS NULL;
    END IF;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_phone'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_phone text;
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'phone'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_phone = phone
      WHERE contact_phone IS NULL;
    END IF;
  END IF;
END $$;

-- Trigger updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_directorycontacts_updated_at'
  ) THEN
    CREATE TRIGGER trg_directorycontacts_updated_at
    BEFORE UPDATE ON public."DirectoryContacts"
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dircontacts_company ON public."DirectoryContacts"(company_id) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_dircontacts_org ON public."DirectoryContacts"(organization_id) WHERE organization_id IS NOT NULL;

-- RLS usando funciones SECURITY DEFINER
ALTER TABLE public."DirectoryContacts" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dircontacts_select_own_org_or_company ON public."DirectoryContacts";
CREATE POLICY dircontacts_select_own_org_or_company
  ON public."DirectoryContacts"
  FOR SELECT
  USING (
    (
      (company_id IS NOT NULL AND public.is_company_member(company_id))
      OR
      (organization_id IS NOT NULL AND public.is_org_member(organization_id))
    )
    AND deleted = false
  );

-- ============================================================
-- 5) FIX CRÍTICO: RLS recursion (42P17) en OrganizationUsers
-- ============================================================
-- Las funciones helper ya fueron creadas arriba (is_org_member, is_org_owner_or_admin)
-- Drop todas las policies existentes en OrganizationUsers (las recreamos sin recursión)
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'OrganizationUsers'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public."OrganizationUsers"', pol.policyname);
  END LOOP;
END $$;

-- Crear policies NO recursivas usando función SECURITY DEFINER
CREATE POLICY orgusers_select_own
  ON public."OrganizationUsers"
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND deleted = false
  );

CREATE POLICY orgusers_update_own
  ON public."OrganizationUsers"
  FOR UPDATE
  USING (
    user_id = auth.uid()
    AND deleted = false
  )
  WITH CHECK (
    user_id = auth.uid()
    AND deleted = false
  );

-- Para INSERT/DELETE, usaremos RPCs SECURITY DEFINER (ya creados en migración 511)
-- Si no existen, los crearemos en una migración posterior

COMMIT;
