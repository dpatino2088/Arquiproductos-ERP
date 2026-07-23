-- Add a 'delivery' value to inventory_movement_type so supply items shipped to
-- the customer can be recorded as an outbound (negative) inventory movement.
-- NOTE: this must be its own migration/transaction; the new enum label cannot be
-- used in the same transaction where it is created.
ALTER TYPE public.inventory_movement_type ADD VALUE IF NOT EXISTS 'delivery';
