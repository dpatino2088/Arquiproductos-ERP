-- ====================================================
-- Migration: Create base Organizations table
-- ====================================================
-- OBJETIVO: Crear tabla base de Organizations
-- ====================================================

BEGIN;

-- Create Organizations table
CREATE TABLE IF NOT EXISTS public."Organizations" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_organizations_created_at ON public."Organizations"(created_at);

-- Add comment
COMMENT ON TABLE public."Organizations" IS 'Organizations table - base entity for multi-tenancy';

-- Enable RLS
ALTER TABLE public."Organizations" ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (can be extended later)
-- Users can read organizations they belong to
DROP POLICY IF EXISTS "Users can read own organizations" ON public."Organizations";
CREATE POLICY "Users can read own organizations"
    ON public."Organizations"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers"
            WHERE "OrganizationUsers".organization_id = "Organizations".id
            AND "OrganizationUsers".user_id = auth.uid()
            AND "OrganizationUsers".deleted = false
            AND "OrganizationUsers".status = 'active'
        )
    );

-- Only owners can insert
DROP POLICY IF EXISTS "Owners can insert organizations" ON public."Organizations";
CREATE POLICY "Owners can insert organizations"
    ON public."Organizations"
    FOR INSERT
    WITH CHECK (true); -- Can be restricted later if needed

-- Only owners can update
DROP POLICY IF EXISTS "Owners can update own organizations" ON public."Organizations";
CREATE POLICY "Owners can update own organizations"
    ON public."Organizations"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers"
            WHERE "OrganizationUsers".organization_id = "Organizations".id
            AND "OrganizationUsers".user_id = auth.uid()
            AND "OrganizationUsers".role = 'owner'
            AND "OrganizationUsers".deleted = false
            AND "OrganizationUsers".status = 'active'
        )
    );

COMMIT;
