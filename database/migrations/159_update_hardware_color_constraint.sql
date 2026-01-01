-- ====================================================
-- Migration: Update HardwareColorMapping Color Constraint
-- ====================================================
-- This migration updates the check constraint to allow additional colors
-- found in the CSV: grey, anthracite, off_white, etc.
-- ====================================================

-- Drop existing constraint
ALTER TABLE public."HardwareColorMapping" 
DROP CONSTRAINT IF EXISTS check_hardware_color_mapping_color_valid;

-- Add new constraint with expanded color list
ALTER TABLE public."HardwareColorMapping" 
ADD CONSTRAINT check_hardware_color_mapping_color_valid 
CHECK (
  hardware_color IN (
    'white',
    'black',
    'silver',
    'bronze',
    'grey',
    'gray',  -- Alternative spelling
    'anthracite',
    'off_white',
    'off-white',  -- Alternative spelling
    'chrome',
    'stainless_steel',
    'natural_aluminium',
    'old_brass',
    'black_nickel'
  )
);

-- Add comment
COMMENT ON CONSTRAINT check_hardware_color_mapping_color_valid ON public."HardwareColorMapping" IS 
  'Validates hardware color values. Includes standard colors (white, black, silver, bronze) and additional colors found in catalog items (grey, anthracite, off_white, chrome, etc.).';









