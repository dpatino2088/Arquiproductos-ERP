-- ====================================================
-- Create directory_contact_type ENUM
-- ====================================================
DO $$ BEGIN
    CREATE TYPE directory_contact_type AS ENUM ('individual', 'company');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ====================================================
-- Create DirectoryContacts table
-- ====================================================
CREATE TABLE IF NOT EXISTS "DirectoryContacts" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    
    -- Contact type
    contact_type directory_contact_type NOT NULL DEFAULT 'individual',
    
    -- Personal/Company information
    title text,
    first_name text,
    middle_name text,
    last_name text,
    company_name text,
    id_number text,
    
    -- Contact information
    primary_phone text,
    cell_phone text,
    alt_phone text,
    email text,
    
    -- Address references
    location_address_id uuid REFERENCES "Addresses"(id) ON UPDATE CASCADE,
    billing_address_id uuid REFERENCES "Addresses"(id) ON UPDATE CASCADE,
    
    -- External sync fields
    remote_id text,
    mirror_remote_id text,
    when_upserted_at timestamptz,
    
    -- Metadata
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

-- Indexes for DirectoryContacts
CREATE INDEX IF NOT EXISTS idx_directory_contacts_organization_id ON "DirectoryContacts"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_contacts_organization_remote_id ON "DirectoryContacts"(organization_id, remote_id);
CREATE INDEX IF NOT EXISTS idx_directory_contacts_location_address_id ON "DirectoryContacts"(location_address_id);
CREATE INDEX IF NOT EXISTS idx_directory_contacts_billing_address_id ON "DirectoryContacts"(billing_address_id);

