-- Freeze customer/contact snapshot when proposal is sent/accepted.
-- Draft proposals remain live via customer_id/contact_id joins.

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS customer_snapshot_name text,
  ADD COLUMN IF NOT EXISTS customer_snapshot_address text,
  ADD COLUMN IF NOT EXISTS customer_snapshot_email text,
  ADD COLUMN IF NOT EXISTS customer_snapshot_phone text,
  ADD COLUMN IF NOT EXISTS contact_snapshot_name text,
  ADD COLUMN IF NOT EXISTS contact_snapshot_email text;

-- Backfill existing sent/accepted proposals that do not have snapshot values.
UPDATE public."Proposals" p
SET
  customer_snapshot_name = COALESCE(p.customer_snapshot_name, dc.customer_name),
  customer_snapshot_address = COALESCE(
    p.customer_snapshot_address,
    NULLIF(
      concat_ws(
        ', ',
        NULLIF(dc.street_address_line_1, ''),
        NULLIF(dc.street_address_line_2, ''),
        NULLIF(concat_ws(', ', NULLIF(dc.city, ''), NULLIF(dc.state, ''), NULLIF(dc.zip_code, '')), ''),
        NULLIF(dc.country, '')
      ),
      ''
    )
  ),
  customer_snapshot_email = COALESCE(p.customer_snapshot_email, dc.customer_email),
  customer_snapshot_phone = COALESCE(p.customer_snapshot_phone, dc.customer_phone, dc.alt_phone),
  contact_snapshot_name = COALESCE(p.contact_snapshot_name, ct.contact_name),
  contact_snapshot_email = COALESCE(p.contact_snapshot_email, ct.contact_email)
FROM public."Quotes" q
LEFT JOIN public."DirectoryCustomers" dc
  ON dc.id = COALESCE(p.customer_id, q.customer_id)
 AND dc.organization_id = p.organization_id
LEFT JOIN public."DirectoryContacts" ct
  ON ct.id = COALESCE(p.contact_id, q.contact_id)
 AND ct.organization_id = p.organization_id
WHERE p.quote_id = q.id
  AND COALESCE(q.deleted, false) = false
  AND p.status::text IN ('sent', 'accepted')
  AND (
    p.customer_snapshot_name IS NULL
    OR p.customer_snapshot_address IS NULL
    OR p.customer_snapshot_email IS NULL
    OR p.customer_snapshot_phone IS NULL
    OR p.contact_snapshot_name IS NULL
    OR p.contact_snapshot_email IS NULL
  );
