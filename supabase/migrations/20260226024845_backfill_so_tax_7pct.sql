
UPDATE "SalesOrders" 
SET tax_amount = ROUND(subtotal * 0.07, 2), 
    total_amount = subtotal + ROUND(subtotal * 0.07, 2),
    updated_at = now()
WHERE deleted = false 
  AND subtotal > 0 
  AND (tax_amount = 0 OR tax_amount IS NULL)
  AND quote_id IN (SELECT id FROM "Quotes" WHERE COALESCE(exempt_tax, false) = false);
;
