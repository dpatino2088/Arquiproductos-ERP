-- Wave 2.3 and Wave 2.8 are fabric wave styles, not separate product lines.
-- They belong under the ripple_fold product line (same track hardware).
UPDATE "public"."FabricRules"
SET product_line = 'ripple_fold'
WHERE style_code IN ('wave_2.3', 'wave_2.8')
  AND product_line = 'wave';

NOTIFY pgrst, 'reload schema';
