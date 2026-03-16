-- Add delta_mode to BOMComponents for engineering cascade
-- Values: 'subtract' (reduces cut dimension), 'add' (assembly info), 'info' (display only)
ALTER TABLE public."BOMComponents"
  ADD COLUMN IF NOT EXISTS delta_mode text NOT NULL DEFAULT 'subtract';

COMMENT ON COLUMN public."BOMComponents".delta_mode IS
  'How this component''s delta affects the target: subtract (reduces cut), add (assembly total), info (display only)';
