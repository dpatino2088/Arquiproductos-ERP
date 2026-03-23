-- Expand QuoteLineComponents.component_role check to include options + fabric
-- Required for BOM template selection and fabric storage
BEGIN;

ALTER TABLE public."QuoteLineComponents"
  DROP CONSTRAINT IF EXISTS "quotelinecomponents_component_role_check";

ALTER TABLE public."QuoteLineComponents"
  ADD CONSTRAINT "quotelinecomponents_component_role_check" CHECK (
    component_role = ANY (ARRAY[
      -- BOM roles
      'tube','track','bottom_bar','bottom_channel','hem_weight','side_channel','side_channels',
      'top_rail','headbox','bracket','idler','drive','motor','adapter','chain','chain_stop',
      'chain_tensioner','wand','end_cap','filler','tape','consumable','fastener','accessory',
      'carrier','belt','belt_connector',
      -- Config options
      'hardware_color','drive_type','system_size','cassette','bottom_rail_type','tube_type',
      -- Fabric selection
      'fabric'
    ])
  );

COMMIT;
