-- ====================================================
-- Migration: Fix Bracket and Cassette Logic
-- ====================================================
-- Updates BOM Components to ensure brackets are ONLY included when cassette = false/NONE
-- Cassette components are ONLY included when cassette = true
-- This ensures they never stack (mutually exclusive)
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
BEGIN
  -- Get organization ID (assuming single org for now - adjust if needed)
  SELECT id INTO v_org_id FROM "Organizations" WHERE deleted = false LIMIT 1;
  
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No organization found';
  END IF;

  RAISE NOTICE '🔧 Fixing Bracket and Cassette Logic...';
  RAISE NOTICE 'Organization ID: %', v_org_id;
  RAISE NOTICE '';

  -- Update brackets to have block_condition: {"cassette": false}
  -- This ensures brackets are ONLY included when cassette = false/NONE
  UPDATE "BOMComponents"
  SET 
    block_condition = '{"cassette": false}'::jsonb,
    updated_at = NOW()
  WHERE 
    organization_id = v_org_id
    AND block_type = 'brackets'
    AND (block_condition IS NULL OR block_condition->>'cassette' IS NULL)
    AND deleted = false;

  RAISE NOTICE '  ✅ Updated brackets to require cassette = false';
  RAISE NOTICE '     (Brackets will only be included when cassette is NONE)';

  -- Verify cassette components already have block_condition: {"cassette": true}
  -- (They should already have this, but let's verify and fix if needed)
  UPDATE "BOMComponents"
  SET 
    block_condition = '{"cassette": true}'::jsonb,
    updated_at = NOW()
  WHERE 
    organization_id = v_org_id
    AND block_type = 'cassette'
    AND (block_condition IS NULL OR (block_condition->>'cassette')::boolean != true)
    AND deleted = false;

  RAISE NOTICE '  ✅ Verified cassette components require cassette = true';
  RAISE NOTICE '     (Cassette components will only be included when cassette is selected)';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Bracket and Cassette Logic Fixed!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Summary:';
  RAISE NOTICE '   - Standard brackets: ONLY when cassette = false/NONE';
  RAISE NOTICE '   - Cassette components: ONLY when cassette = true/selected';
  RAISE NOTICE '   - These are now mutually exclusive (never stack)';
  RAISE NOTICE '';

END $$;









