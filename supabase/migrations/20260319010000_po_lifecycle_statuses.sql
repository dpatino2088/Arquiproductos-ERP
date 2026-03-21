-- Add DRAFT, CANCELLED, ARCHIVED to purchase_order_status enum
-- DRAFT: PO created but not yet approved/sent
-- CANCELLED: PO was cancelled before completion
-- ARCHIVED: PO was completed and archived for record-keeping

ALTER TYPE public.purchase_order_status ADD VALUE IF NOT EXISTS 'DRAFT' BEFORE 'OPEN';
ALTER TYPE public.purchase_order_status ADD VALUE IF NOT EXISTS 'CANCELLED' AFTER 'CLOSED';
ALTER TYPE public.purchase_order_status ADD VALUE IF NOT EXISTS 'ARCHIVED' AFTER 'CANCELLED';

-- Update column default to DRAFT for new POs
ALTER TABLE "public"."PurchaseOrders"
  ALTER COLUMN status SET DEFAULT 'DRAFT'::purchase_order_status;
