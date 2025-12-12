-- ====================================================
-- CREATE TABLE DirectoryVendors
-- ====================================================
CREATE TABLE IF NOT EXISTS "DirectoryVendors" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Vendor type reference
    vendor_type_id uuid REFERENCES "VendorTypes"(id) ON UPDATE CASCADE,
    
    -- Vendor information
    vendor_name text,
    ein text,
    website text,
    email text,
    work_phone text,
    fax text,
    
    -- Location address
    street_address_line_1 text,
    street_address_line_2 text,
    city text,
    state text,
    zip_code text,
    country text,
    
    -- Billing address
    billing_street_address_line_1 text,
    billing_street_address_line_2 text,
    billing_city text,
    billing_state text,
    billing_zip_code text,
    billing_country text,
    
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

-- Indexes for DirectoryVendors
CREATE INDEX IF NOT EXISTS idx_directory_vendors_organization_id ON "DirectoryVendors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_organization_remote_id ON "DirectoryVendors"(organization_id, remote_id);
CREATE INDEX IF NOT EXISTS idx_directory_vendors_vendor_type_id ON "DirectoryVendors"(vendor_type_id);

-- ====================================================
-- CREATE TABLE DirectoryContractors
-- ====================================================
CREATE TABLE IF NOT EXISTS "DirectoryContractors" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Contractor role reference
    contractor_role_id uuid REFERENCES "ContractorRoles"(id) ON UPDATE CASCADE,
    
    -- Contractor information
    contractor_company_name text,
    contact_name text,
    position text,
    
    -- Location address
    street_address_line_1 text,
    street_address_line_2 text,
    city text,
    state text,
    zip_code text,
    country text,
    
    -- Dates and identification
    date_of_hire date,
    date_of_birth date,
    ein text,
    company_number text,
    
    -- Contact information
    primary_email text,
    secondary_email text,
    phone text,
    extension text,
    cell_phone text,
    fax text,
    preferred_notification_method text,
    
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

-- Indexes for DirectoryContractors
CREATE INDEX IF NOT EXISTS idx_directory_contractors_organization_id ON "DirectoryContractors"(organization_id);
CREATE INDEX IF NOT EXISTS idx_directory_contractors_organization_remote_id ON "DirectoryContractors"(organization_id, remote_id);
CREATE INDEX IF NOT EXISTS idx_directory_contractors_contractor_role_id ON "DirectoryContractors"(contractor_role_id);

