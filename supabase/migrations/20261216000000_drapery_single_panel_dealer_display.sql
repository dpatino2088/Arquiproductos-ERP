-- Drapery: dealer-facing dimension is ALWAYS a single total panel (width × height).
--
-- Context / bug being fixed:
--   The product configurator used to DERIVE drapery "panels" from opening_direction
--   (center → two ½-width panels). That is wrong: opening_direction only sets where the
--   curtain parts; it does NOT create panels. The only real split is the TRACK split, which
--   is an internal manufacturing detail (transparent to the dealer):
--     - width  > 4000mm → mandatory split into ceil(width/4000) pieces (joints)
--     - width <= 4000mm → optional split into 2 pieces when force_track_join is on
--     - otherwise       → single piece (full width)
--
--   Because of the old logic, drapery rows were stored with panel_count = 2 and
--   panels = [½, ½], which leaked the split into dealer-facing views (Quote Lines list,
--   QuoteDetail, Proposal PDF) showing e.g. "1275 x 2950, 1275" instead of "2550 x 2950".
--
-- This migration backfills existing drapery rows so that:
--   * panels / measurements.panels = single panel of the full (total) width
--   * panel_count = 1, is_interconnected = false
--   * the track split is preserved as internal metadata under measurements.track
--     (pieces / joints / piece_widths / force_track_join) for Work Order / manufacturing.
--
-- The configurator (src/pages/sales/ProductConfigurator.tsx) was updated to produce the
-- same shape on every save, so this is a one-time corrective backfill. It is idempotent:
-- it only touches drapery rows whose panel_count (or panels length) is still > 1.

-- ConfiguredProducts
WITH c AS (
  SELECT cp.id,
         round(COALESCE(
           (cp.config_snapshot->'measurements'->>'width_total_mm')::numeric,
           cp.width_mm,
           (cp.config_snapshot->>'width_mm')::numeric
         ))::int AS total,
         COALESCE((cp.config_snapshot->>'force_track_join')::boolean, false) AS fj
  FROM public."ConfiguredProducts" cp
  WHERE cp.deleted = false
    AND lower(COALESCE(cp.config_snapshot->>'productType', cp.config_snapshot->>'product_type','')) LIKE '%drapery%'
    AND COALESCE(
          (cp.config_snapshot->'measurements'->>'panel_count')::int,
          jsonb_array_length(COALESCE(cp.config_snapshot->'panels','[]'::jsonb))
        ) > 1
),
c2 AS (
  SELECT id, total, fj,
         CASE WHEN total > 4000 THEN ceil(total/4000.0)::int WHEN fj THEN 2 ELSE 1 END AS pieces
  FROM c WHERE total > 0
),
c3 AS (
  SELECT id, total, fj, pieces,
         to_jsonb(array_fill(round(total/pieces)::int, ARRAY[pieces])) AS pw
  FROM c2
)
UPDATE public."ConfiguredProducts" cp
SET config_snapshot = jsonb_set(
  jsonb_set(
    cp.config_snapshot,
    '{panels}',
    jsonb_build_array(jsonb_build_object('index', 1, 'width_mm', c3.total))
  ),
  '{measurements}',
  COALESCE(cp.config_snapshot->'measurements','{}'::jsonb) || jsonb_build_object(
    'panel_count', 1,
    'width_total_mm', c3.total,
    'panels', jsonb_build_array(jsonb_build_object('index', 1, 'width_mm', c3.total)),
    'is_interconnected', false,
    'track', jsonb_build_object(
      'pieces', c3.pieces,
      'joints', c3.pieces - 1,
      'piece_widths', c3.pw,
      'force_track_join', c3.fj
    )
  )
)
FROM c3
WHERE cp.id = c3.id;

-- QuoteLines
WITH c AS (
  SELECT ql.id,
         round(COALESCE(
           (ql.config_snapshot->'measurements'->>'width_total_mm')::numeric,
           ql.width_m * 1000,
           (ql.config_snapshot->>'width_mm')::numeric
         ))::int AS total,
         COALESCE((ql.config_snapshot->>'force_track_join')::boolean, false) AS fj
  FROM public."QuoteLines" ql
  WHERE lower(COALESCE(ql.product_type,'')) LIKE '%drapery%'
    AND COALESCE(
          (ql.config_snapshot->'measurements'->>'panel_count')::int,
          jsonb_array_length(COALESCE(ql.config_snapshot->'panels','[]'::jsonb))
        ) > 1
),
c2 AS (
  SELECT id, total, fj,
         CASE WHEN total > 4000 THEN ceil(total/4000.0)::int WHEN fj THEN 2 ELSE 1 END AS pieces
  FROM c WHERE total > 0
),
c3 AS (
  SELECT id, total, fj, pieces,
         to_jsonb(array_fill(round(total/pieces)::int, ARRAY[pieces])) AS pw
  FROM c2
)
UPDATE public."QuoteLines" ql
SET config_snapshot = jsonb_set(
  jsonb_set(
    COALESCE(ql.config_snapshot, '{}'::jsonb),
    '{panels}',
    jsonb_build_array(jsonb_build_object('index', 1, 'width_mm', c3.total))
  ),
  '{measurements}',
  COALESCE(ql.config_snapshot->'measurements','{}'::jsonb) || jsonb_build_object(
    'panel_count', 1,
    'width_total_mm', c3.total,
    'panels', jsonb_build_array(jsonb_build_object('index', 1, 'width_mm', c3.total)),
    'is_interconnected', false,
    'track', jsonb_build_object(
      'pieces', c3.pieces,
      'joints', c3.pieces - 1,
      'piece_widths', c3.pw,
      'force_track_join', c3.fj
    )
  )
)
FROM c3
WHERE ql.id = c3.id;
