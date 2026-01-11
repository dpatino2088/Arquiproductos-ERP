-- ====================================================
-- Migration: Create base OrganizationUsers table
-- ====================================================
-- OBJETIVO: Crear tabla OrganizationUsers con estructura canónica
-- ====================================================

BEGIN;

-- Create OrganizationUsers table
CREATE TABLE IF NOT EXISTS public."OrganizationUsers" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL, -- Nullable hasta aceptar invite
    user_email text NOT NULL, -- Lowercased
    user_name text, -- Nullable
    role text NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'disabled')),
    invited_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    invited_at timestamptz,
    accepted_at timestamptz,
    deleted boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create unique index: (organization_id, lower(user_email)) WHERE deleted = false
CREATE UNIQUE INDEX IF NOT EXISTS organizationusers_org_email_unique
    ON public."OrganizationUsers" (organization_id, lower(user_email))
    WHERE deleted = false;

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_organization_users_organization_id ON public."OrganizationUsers"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_user_id ON public."OrganizationUsers"(user_id) WHERE user_id IS NOT NULL AND deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_user_email ON public."OrganizationUsers"(lower(user_email)) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_status ON public."OrganizationUsers"(status) WHERE deleted = false;

-- Add comments
COMMENT ON TABLE public."OrganizationUsers" IS 'Organization users - internal users with roles (owner, admin, member, viewer)';
COMMENT ON COLUMN public."OrganizationUsers".user_email IS 'User email (lowercased). Unique per organization when not deleted.';
COMMENT ON COLUMN public."OrganizationUsers".user_id IS 'FK to auth.users. Nullable until user accepts invite.';
COMMENT ON COLUMN public."OrganizationUsers".status IS 'Status: invited (pending), active (accepted), disabled (inactive)';
COMMENT ON INDEX organizationusers_org_email_unique IS 'Ensures unique email addresses per organization for active (non-deleted) records. Case-insensitive comparison.';

-- Enable RLS
ALTER TABLE public."OrganizationUsers" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can read OrganizationUsers for organizations they belong to
DROP POLICY IF EXISTS "Users can read own organization users" ON public."OrganizationUsers";
CREATE POLICY "Users can read own organization users"
    ON public."OrganizationUsers"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrganizationUsers".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Only owners and admins can insert
DROP POLICY IF EXISTS "Owners and admins can insert organization users" ON public."OrganizationUsers";
CREATE POLICY "Owners and admins can insert organization users"
    ON public."OrganizationUsers"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrganizationUsers".organization_id
            AND ou.user_id = auth.uid()
            AND ou.role IN ('owner', 'admin')
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Only owners and admins can update
DROP POLICY IF EXISTS "Owners and admins can update organization users" ON public."OrganizationUsers";
CREATE POLICY "Owners and admins can update organization users"
    ON public."OrganizationUsers"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrganizationUsers".organization_id
            AND ou.user_id = auth.uid()
            AND ou.role IN ('owner', 'admin')
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Only owners and admins can delete (soft delete)
DROP POLICY IF EXISTS "Owners and admins can delete organization users" ON public."OrganizationUsers";
CREATE POLICY "Owners and admins can delete organization users"
    ON public."OrganizationUsers"
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.organization_id = "OrganizationUsers".organization_id
            AND ou.user_id = auth.uid()
            AND ou.role IN ('owner', 'admin')
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_organization_users_updated_at ON public."OrganizationUsers";
CREATE TRIGGER update_organization_users_updated_at
    BEFORE UPDATE ON public."OrganizationUsers"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

COMMIT;
