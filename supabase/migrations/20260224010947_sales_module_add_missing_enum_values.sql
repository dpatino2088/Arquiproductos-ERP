
-- Add missing enum values to existing types
-- Each ADD VALUE is idempotent (IF NOT EXISTS)

ALTER TYPE quote_status ADD VALUE IF NOT EXISTS 'converted';
ALTER TYPE quote_status ADD VALUE IF NOT EXISTS 'expired';

ALTER TYPE proposal_status ADD VALUE IF NOT EXISTS 'expired';

ALTER TYPE sales_order_status ADD VALUE IF NOT EXISTS 'on_hold';
ALTER TYPE sales_order_status ADD VALUE IF NOT EXISTS 'closed';

ALTER TYPE manufacturing_order_status ADD VALUE IF NOT EXISTS 'quality_check';
ALTER TYPE manufacturing_order_status ADD VALUE IF NOT EXISTS 'ready_for_pickup';
ALTER TYPE manufacturing_order_status ADD VALUE IF NOT EXISTS 'delivered';
;
