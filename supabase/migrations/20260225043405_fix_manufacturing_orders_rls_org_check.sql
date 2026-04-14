
-- ManufacturingOrders RLS: la condición ou.organization_id = ou.organization_id
-- es siempre true. Debe comparar con la fila: "ManufacturingOrders".organization_id.

DROP POLICY IF EXISTS "mo_select" ON public."ManufacturingOrders";
CREATE POLICY "mo_select" ON public."ManufacturingOrders"
  FOR SELECT
  TO public
  USING (
    (deleted = false)
    AND (EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.user_id = auth.uid()
        AND ou.organization_id = "ManufacturingOrders".organization_id
        AND ou.deleted = false
        AND ou.status = 'active'
    ))
  );

DROP POLICY IF EXISTS "mo_write" ON public."ManufacturingOrders";
CREATE POLICY "mo_write" ON public."ManufacturingOrders"
  FOR ALL
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.user_id = auth.uid()
        AND ou.organization_id = "ManufacturingOrders".organization_id
        AND ou.deleted = false
        AND ou.status = 'active'
        AND ou.role IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.user_id = auth.uid()
        AND ou.organization_id = "ManufacturingOrders".organization_id
        AND ou.deleted = false
        AND ou.status = 'active'
        AND ou.role IN ('owner', 'admin')
    )
  );
;
