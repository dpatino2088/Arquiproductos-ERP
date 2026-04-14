CREATE UNIQUE INDEX IF NOT EXISTS mol_mo_sol_unique ON public."ManufacturingOrderLines" (manufacturing_order_id, sales_order_line_id);

NOTIFY pgrst, 'reload schema';;
