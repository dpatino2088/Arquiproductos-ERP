-- Migration: Create OrganizationUsers table
-- This table links users to organizations with their roles

CREATE TABLE IF NOT EXISTS "OrganizationUsers" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  invited_by uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted boolean NOT NULL DEFAULT false,
  
  -- Ensure a user can only have one active role per organization
  CONSTRAINT organization_users_unique_active UNIQUE (organization_id, user_id, deleted)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_organization_users_organization_id ON "OrganizationUsers"(organization_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_user_id ON "OrganizationUsers"(user_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_organization_users_role ON "OrganizationUsers"(role) WHERE deleted = false;

-- Add comment
COMMENT ON TABLE "OrganizationUsers" IS 'Links users to organizations with their roles (owner, admin, member, viewer)';

