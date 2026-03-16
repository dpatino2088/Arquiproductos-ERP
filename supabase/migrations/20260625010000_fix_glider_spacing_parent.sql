-- Fix parent glider qty_spacing_mm to match their condition_value (system_size).
-- CC1028-W is the 48mm glider → spacing must be 48.
-- CC1030-W is the 60mm glider → spacing must be 60.
-- Children were already correct; only 4 parents had swapped values.

UPDATE public."BOMComponents"
SET qty_spacing_mm = 48, updated_at = NOW()
WHERE id = '7d8008f6-ece7-4daa-a6cc-4c062aee2383';

UPDATE public."BOMComponents"
SET qty_spacing_mm = 60, updated_at = NOW()
WHERE id IN (
  '6f60ac9a-11ef-40bd-b231-91a0634afbbe',
  '6e1d27cb-e268-4599-ab59-c54ed6304809',
  '0ad911c7-90da-43d3-9dec-37e7e6c44125'
);
