
-- Re-numeración org-wide de Quotes (eliminar duplicados entre dealers)
-- Quotes no tiene unique constraint en quote_no, así que podemos actualizar directamente

-- Paso 1: Renombrar temporalmente para evitar colisiones durante la re-numeración
UPDATE "Quotes"
SET quote_no = 'QT-TMP-' || id::text
WHERE deleted = false;

-- Paso 2: Asignar números secuenciales por organización (no por dealer)
WITH q_rank AS (
  SELECT id,
    'QT-' || LPAD(
      (99 + ROW_NUMBER() OVER (
        PARTITION BY organization_id
        ORDER BY created_at, id
      ))::text,
      5, '0'
    ) AS new_quote_no
  FROM "Quotes"
  WHERE deleted = false AND quote_no LIKE 'QT-TMP-%'
)
UPDATE "Quotes" q
SET quote_no = q_rank.new_quote_no
FROM q_rank
WHERE q.id = q_rank.id;

-- Añadir unique constraint en (organization_id, quote_no) para evitar futuros duplicados
-- (primero eliminar si ya existe)
ALTER TABLE "Quotes"
  DROP CONSTRAINT IF EXISTS quotes_org_quote_no_unique;

ALTER TABLE "Quotes"
  ADD CONSTRAINT quotes_org_quote_no_unique
  UNIQUE (organization_id, quote_no);
;
