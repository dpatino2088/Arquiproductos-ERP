-- Add Bank Name and short Description to Payments for SO Apply Payment and Financials consistency.
ALTER TABLE public."Payments" ADD COLUMN IF NOT EXISTS bank_name text;
ALTER TABLE public."Payments" ADD COLUMN IF NOT EXISTS description text;
