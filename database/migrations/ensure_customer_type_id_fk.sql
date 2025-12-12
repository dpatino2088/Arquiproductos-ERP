-- ====================================================
-- Migration: Ensure customer_type_id foreign key in DirectoryCustomers
-- ====================================================
-- This migration ensures the customer_type_id column exists and has
-- a proper foreign key constraint to CustomerTypes table.

-- Add customer_type_id column if it doesn't exist
ALTER TABLE "DirectoryCustomers"
ADD COLUMN IF NOT EXISTS customer_type_id uuid;

-- Add foreign key constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'directorycustomers_customer_type_id_fkey'
    ) THEN
        ALTER TABLE "DirectoryCustomers"
        ADD CONSTRAINT directorycustomers_customer_type_id_fkey
            FOREIGN KEY (customer_type_id)
            REFERENCES "CustomerTypes"(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;
END $$;

-- Create index for customer_type_id
CREATE INDEX IF NOT EXISTS idx_directory_customers_customer_type_id 
ON "DirectoryCustomers"(customer_type_id);

