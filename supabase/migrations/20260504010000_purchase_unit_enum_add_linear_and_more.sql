-- Add missing purchase unit options: m, ft, yd (linear) and bundle, carton (unit).
-- Allows "Purchase Unit" to reflect how you buy from supplier (meters, feet, yards, etc.).

ALTER TYPE public.purchase_unit_enum ADD VALUE IF NOT EXISTS 'm';
ALTER TYPE public.purchase_unit_enum ADD VALUE IF NOT EXISTS 'ft';
ALTER TYPE public.purchase_unit_enum ADD VALUE IF NOT EXISTS 'yd';
ALTER TYPE public.purchase_unit_enum ADD VALUE IF NOT EXISTS 'bundle';
ALTER TYPE public.purchase_unit_enum ADD VALUE IF NOT EXISTS 'carton';
