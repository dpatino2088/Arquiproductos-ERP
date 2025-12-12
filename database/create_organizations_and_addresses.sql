-- ====================================================
-- TASK 1: Create Organizations table
-- ====================================================
CREATE TABLE IF NOT EXISTS "Organizations" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    slug text UNIQUE,
    tax_id text,
    country text,
    time_zone text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- Indexes for Organizations
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON "Organizations"(slug);
CREATE INDEX IF NOT EXISTS idx_organizations_deleted_archived ON "Organizations"(deleted, archived);

-- ====================================================
-- TASK 2: Create Addresses table (shared)
-- ====================================================
CREATE TABLE IF NOT EXISTS "Addresses" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    street_address_line_1 text,
    street_address_line_2 text,
    city text,
    state text,
    zip_code text,
    country text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- Indexes for Addresses
CREATE INDEX IF NOT EXISTS idx_addresses_organization_id ON "Addresses"(organization_id);

