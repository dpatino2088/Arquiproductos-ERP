ALTER TABLE public."FabricRules" ADD COLUMN IF NOT EXISTS heatseal_price_per_m numeric DEFAULT 0, ADD COLUMN IF NOT EXISTS bottom_bar_wrap_pct numeric DEFAULT 0;

COMMENT ON COLUMN public."FabricRules".heatseal_price_per_m IS 'Cost per linear meter of heat-seal splice when fabric is rotated and needs welding.';
COMMENT ON COLUMN public."FabricRules".bottom_bar_wrap_pct IS 'Percentage surcharge on fabric cost when the bottom bar is wrapped (forrado). 0.08 = 8%.';;
