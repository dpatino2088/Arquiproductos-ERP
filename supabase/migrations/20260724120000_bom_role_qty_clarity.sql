-- Clarify BOM hardware roles vs quantity semantics:
-- - edge brackets (fixed 1 kit or 2 pcs)
-- - intermediate brackets (per_joint / N−1)
-- - mounting clips (per_spacing)
--
-- Does NOT change placement_section (shared still means both-end / housing for cuts).

-- 1) Role catalog: allow mounting_clip as a top-level BOM component; clearer labels
UPDATE "CatalogItemRoles"
SET
  role_type = 'both',
  label = 'Mounting Clip (spacing)',
  updated_at = now()
WHERE role_code = 'mounting_clip';

UPDATE "CatalogItemRoles"
SET
  label = 'Edge Bracket (L/R)',
  updated_at = now()
WHERE role_code = 'bracket';

UPDATE "CatalogItemRoles"
SET
  label = 'Intermediate Bracket (N−1)',
  updated_at = now()
WHERE role_code = 'intermediate_bracket';

-- 2) Mis-tagged parents: bracket + per_joint → intermediate_bracket
UPDATE "BOMComponents"
SET
  component_role = 'intermediate_bracket',
  updated_at = now()
WHERE parent_component_id IS NULL
  AND component_role = 'bracket'
  AND qty_type = 'per_joint';

-- 3) Mis-tagged parents: bracket + per_spacing → mounting_clip
UPDATE "BOMComponents"
SET
  component_role = 'mounting_clip',
  updated_at = now()
WHERE parent_component_id IS NULL
  AND component_role = 'bracket'
  AND qty_type = 'per_spacing';
