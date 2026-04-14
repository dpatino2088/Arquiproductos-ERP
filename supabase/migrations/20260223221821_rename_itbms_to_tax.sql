-- CostSettings.itbms_pct -> tax_pct; Proposals: itbms_amount -> tax_amount, exempt_itbms -> exempt_tax; Quotes: exempt_itbms -> exempt_tax
ALTER TABLE public."CostSettings" RENAME COLUMN itbms_pct TO tax_pct;
ALTER TABLE public."CostSettings" RENAME CONSTRAINT costsettings_itbms_pct_range TO costsettings_tax_pct_range;
COMMENT ON COLUMN public."CostSettings"."tax_pct" IS 'Tax % (0-1, e.g. 0.07 = 7%). Used in Proposals/Quotes totals.';

ALTER TABLE public."Proposals" RENAME COLUMN itbms_amount TO tax_amount;
ALTER TABLE public."Proposals" RENAME COLUMN exempt_itbms TO exempt_tax;
COMMENT ON COLUMN public."Proposals"."tax_amount" IS 'Tax amount. Calculated from taxable_base * tax_pct (from CostSettings).';
COMMENT ON COLUMN public."Proposals"."exempt_tax" IS 'If true, no tax. tax_amount = 0, total = taxable_base + fee.';

ALTER TABLE public."Quotes" RENAME COLUMN exempt_itbms TO exempt_tax;
COMMENT ON COLUMN public."Quotes"."exempt_tax" IS 'If true, no tax. Subtotal = Total.';;
