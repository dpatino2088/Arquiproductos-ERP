-- ====================================================
-- Migration: Create Users and OrganizationUsers tables
-- ====================================================
-- This migration creates the Users and OrganizationUsers tables
-- to link Supabase Auth users with Organizations and roles.

-- ====================================================
-- Create Users table
-- ====================================================
CREATE TABLE IF NOT EXISTS "Users" (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    avatar_url text,
    default_locale text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- Create index for Users
CREATE INDEX IF NOT EXISTS idx_users_deleted ON "Users"(deleted) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_users_archived ON "Users"(archived) WHERE archived = false;

-- ====================================================
-- Create OrganizationUsers table
-- ====================================================
CREATE TABLE IF NOT EXISTS "OrganizationUsers" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES "Users"(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    
    -- Ensure a user can only have one role per organization
    UNIQUE (organization_id, user_id)
);

-- Create indexes for OrganizationUsers
CREATE INDEX IF NOT EXISTS idx_organization_users_organization_id ON "OrganizationUsers"(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_users_user_id ON "OrganizationUsers"(user_id);
CREATE INDEX IF NOT EXISTS idx_organization_users_role ON "OrganizationUsers"(role);
CREATE INDEX IF NOT EXISTS idx_organization_users_status ON "OrganizationUsers"(status);
CREATE INDEX IF NOT EXISTS idx_organization_users_deleted ON "OrganizationUsers"(deleted) WHERE deleted = false;

-- ====================================================
-- Enable Row Level Security (RLS)
-- ====================================================

-- Enable RLS on Users
ALTER TABLE "Users" ENABLE ROW LEVEL SECURITY;

-- Enable RLS on OrganizationUsers
ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- RLS Policies for Users
-- ====================================================
-- Users can read their own profile
CREATE POLICY "Users can read own profile"
    ON "Users"
    FOR SELECT
    USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON "Users"
    FOR UPDATE
    USING (auth.uid() = id);

-- ====================================================
-- RLS Policies for OrganizationUsers
-- ====================================================
-- Users can read OrganizationUsers for organizations they belong to
CREATE POLICY "Users can read own organization memberships"
    ON "OrganizationUsers"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM "OrganizationUsers" ou
            WHERE ou.user_id = auth.uid()
            AND ou.organization_id = "OrganizationUsers".organization_id
            AND ou.deleted = false
        )
    );

-- Only owners and admins can insert new OrganizationUsers
CREATE POLICY "Owners and admins can add members"
    ON "OrganizationUsers"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM "OrganizationUsers" ou
            WHERE ou.user_id = auth.uid()
            AND ou.organization_id = "OrganizationUsers".organization_id
            AND ou.role IN ('owner', 'admin')
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- Only owners and admins can update OrganizationUsers
CREATE POLICY "Owners and admins can update members"
    ON "OrganizationUsers"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM "OrganizationUsers" ou
            WHERE ou.user_id = auth.uid()
            AND ou.organization_id = "OrganizationUsers".organization_id
            AND ou.role IN ('owner', 'admin')
            AND ou.deleted = false
            AND ou.status = 'active'
        )
    );

-- ====================================================
-- Function to automatically create Users row when auth user is created
-- ====================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public."Users" (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create Users row when auth user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ====================================================
-- Function to update updated_at timestamp
-- ====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Users updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON "Users";
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON "Users"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger for OrganizationUsers updated_at
DROP TRIGGER IF EXISTS update_organization_users_updated_at ON "OrganizationUsers";
CREATE TRIGGER update_organization_users_updated_at
    BEFORE UPDATE ON "OrganizationUsers"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

