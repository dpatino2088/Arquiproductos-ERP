-- ====================================================
-- TASK 1: Create Catalog Tables
-- ====================================================

-- 1) CustomerTypes
CREATE TABLE IF NOT EXISTS "CustomerTypes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_customer_types_organization_id ON "CustomerTypes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_customer_types_organization_deleted ON "CustomerTypes"(organization_id, deleted);

-- 2) VendorTypes
CREATE TABLE IF NOT EXISTS "VendorTypes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_vendor_types_organization_id ON "VendorTypes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_vendor_types_organization_deleted ON "VendorTypes"(organization_id, deleted);

-- 3) ContactTitles
CREATE TABLE IF NOT EXISTS "ContactTitles" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    title text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_contact_titles_organization_id ON "ContactTitles"(organization_id);
CREATE INDEX IF NOT EXISTS idx_contact_titles_organization_deleted ON "ContactTitles"(organization_id, deleted);

-- 4) ContractorRoles
CREATE TABLE IF NOT EXISTS "ContractorRoles" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    role_name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_contractor_roles_organization_id ON "ContractorRoles"(organization_id);
CREATE INDEX IF NOT EXISTS idx_contractor_roles_organization_deleted ON "ContractorRoles"(organization_id, deleted);

-- 5) SiteTypes
CREATE TABLE IF NOT EXISTS "SiteTypes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON UPDATE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_site_types_organization_id ON "SiteTypes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_site_types_organization_deleted ON "SiteTypes"(organization_id, deleted);

-- ====================================================
-- TASK 2: Update DirectoryCustomers
-- ====================================================

-- Add new column customer_type_id
ALTER TABLE "DirectoryCustomers" 
ADD COLUMN IF NOT EXISTS customer_type_id uuid REFERENCES "CustomerTypes"(id) ON UPDATE CASCADE;

-- Create index for the new foreign key
CREATE INDEX IF NOT EXISTS idx_directory_customers_customer_type_id ON "DirectoryCustomers"(customer_type_id);

-- Note: You may want to migrate existing data from customer_type TEXT to customer_type_id before dropping the old column
-- For now, we'll keep both columns during migration period
-- ALTER TABLE "DirectoryCustomers" DROP COLUMN IF EXISTS customer_type;

-- ====================================================
-- TASK 3: Update DirectoryContacts
-- ====================================================

-- Add new column title_id
ALTER TABLE "DirectoryContacts" 
ADD COLUMN IF NOT EXISTS title_id uuid REFERENCES "ContactTitles"(id) ON UPDATE CASCADE;

-- Create index for the new foreign key
CREATE INDEX IF NOT EXISTS idx_directory_contacts_title_id ON "DirectoryContacts"(title_id);

-- Note: You may want to migrate existing data from title TEXT to title_id before dropping the old column
-- For now, we'll keep both columns during migration period
-- ALTER TABLE "DirectoryContacts" DROP COLUMN IF EXISTS title;

