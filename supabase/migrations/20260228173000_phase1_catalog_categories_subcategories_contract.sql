-- Phase 1: Canonical Categories/Subcategories contract
-- Goal: enforce a strict 2-level taxonomy in CatalogCategories and ensure
-- CatalogItems.category_id always points to a subcategory (leaf).

-- 1) Contract columns for CatalogCategories
ALTER TABLE "public"."CatalogCategories"
  ADD COLUMN IF NOT EXISTS "code" text,
  ADD COLUMN IF NOT EXISTS "is_group" boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "deleted" boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "archived" boolean NOT NULL DEFAULT false;

-- 2) Helpful indexes and uniqueness
CREATE INDEX IF NOT EXISTS "idx_catalogcategories_org_parent_sort"
  ON "public"."CatalogCategories" ("organization_id", "parent_id", "sort_order", "name")
  WHERE "deleted" = false;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_catalogcategories_org_parent_name_active"
  ON "public"."CatalogCategories" ("organization_id", "parent_id", lower("name"))
  WHERE "deleted" = false;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_catalogcategories_org_code_active"
  ON "public"."CatalogCategories" ("organization_id", lower("code"))
  WHERE "deleted" = false AND "code" IS NOT NULL;

-- 3) Hierarchy validator (exactly two levels)
CREATE OR REPLACE FUNCTION "public"."trg_catalogcategories_validate_hierarchy"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parent_org uuid;
  v_parent_parent_id uuid;
  v_parent_is_group boolean;
BEGIN
  IF NEW.parent_id = NEW.id THEN
    RAISE EXCEPTION 'CatalogCategories.parent_id cannot reference itself';
  END IF;

  IF NEW.parent_id IS NULL THEN
    NEW.is_group := true;
    RETURN NEW;
  END IF;

  -- Child rows must never be groups
  NEW.is_group := false;

  SELECT c.organization_id, c.parent_id, c.is_group
    INTO v_parent_org, v_parent_parent_id, v_parent_is_group
  FROM "public"."CatalogCategories" c
  WHERE c.id = NEW.parent_id
    AND c.deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Parent category % does not exist or is deleted', NEW.parent_id;
  END IF;

  IF v_parent_org <> NEW.organization_id THEN
    RAISE EXCEPTION 'Parent category must belong to same organization';
  END IF;

  IF v_parent_parent_id IS NOT NULL THEN
    RAISE EXCEPTION 'CatalogCategories supports max depth of 2 levels';
  END IF;

  IF COALESCE(v_parent_is_group, false) = false THEN
    RAISE EXCEPTION 'Parent category must be a group (is_group=true)';
  END IF;

  RETURN NEW;
END;
$$;

-- 4) Data cleanup and normalization
-- Keep trigger disabled during cleanup to avoid blocking remediation updates.
DROP TRIGGER IF EXISTS "catalogcategories_validate_hierarchy" ON "public"."CatalogCategories";
DO $$
BEGIN
  -- Self-parent safety
  UPDATE "public"."CatalogCategories"
  SET parent_id = NULL
  WHERE parent_id = id;

  -- Remove cross-org parent refs
  UPDATE "public"."CatalogCategories" child
  SET parent_id = NULL
  WHERE child.parent_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM "public"."CatalogCategories" parent
      WHERE parent.id = child.parent_id
        AND parent.organization_id <> child.organization_id
    );

  -- Normalize depth > 2 by lifting to root parent
  UPDATE "public"."CatalogCategories" child
  SET parent_id = parent.parent_id
  FROM "public"."CatalogCategories" parent
  WHERE child.parent_id = parent.id
    AND parent.parent_id IS NOT NULL;

  -- Root rows are groups; child rows are subcategories
  UPDATE "public"."CatalogCategories"
  SET is_group = CASE WHEN parent_id IS NULL THEN true ELSE false END;
END $$;

-- Enable hierarchy validator after normalization
CREATE TRIGGER "catalogcategories_validate_hierarchy"
BEFORE INSERT OR UPDATE OF "parent_id", "organization_id", "is_group", "deleted"
ON "public"."CatalogCategories"
FOR EACH ROW
EXECUTE FUNCTION "public"."trg_catalogcategories_validate_hierarchy"();

-- 5) Ensure CatalogItems.category_id points to subcategory only
CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_validate_leaf_category"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_org uuid;
  v_parent_id uuid;
  v_is_group boolean;
  v_deleted boolean;
BEGIN
  IF NEW.category_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT c.organization_id, c.parent_id, c.is_group, c.deleted
    INTO v_org, v_parent_id, v_is_group, v_deleted
  FROM "public"."CatalogCategories" c
  WHERE c.id = NEW.category_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid category_id: category does not exist';
  END IF;

  IF v_org <> NEW.organization_id THEN
    RAISE EXCEPTION 'category_id must belong to same organization';
  END IF;

  IF COALESCE(v_deleted, false) THEN
    RAISE EXCEPTION 'category_id cannot reference deleted category';
  END IF;

  IF COALESCE(v_is_group, false) OR v_parent_id IS NULL THEN
    RAISE EXCEPTION 'category_id must reference a subcategory (leaf), not a parent category';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "catalogitems_validate_leaf_category" ON "public"."CatalogItems";
CREATE TRIGGER "catalogitems_validate_leaf_category"
BEFORE INSERT OR UPDATE OF "category_id", "organization_id"
ON "public"."CatalogItems"
FOR EACH ROW
EXECUTE FUNCTION "public"."trg_catalogitems_validate_leaf_category"();

-- 6) Auto-fix items that still point to parent categories
-- For each parent category used by items, assign a "General" subcategory.
WITH parent_refs AS (
  SELECT DISTINCT ci.organization_id, ci.category_id AS parent_id
  FROM "public"."CatalogItems" ci
  JOIN "public"."CatalogCategories" cc ON cc.id = ci.category_id
  WHERE ci.category_id IS NOT NULL
    AND COALESCE(cc.deleted, false) = false
    AND (COALESCE(cc.is_group, false) = true OR cc.parent_id IS NULL)
),
created_general AS (
  INSERT INTO "public"."CatalogCategories" (
    organization_id, name, code, sort_order, parent_id, is_group, deleted, archived
  )
  SELECT
    pr.organization_id,
    'General',
    NULL,
    9999,
    pr.parent_id,
    false,
    false,
    false
  FROM parent_refs pr
  WHERE NOT EXISTS (
    SELECT 1
    FROM "public"."CatalogCategories" child
    WHERE child.organization_id = pr.organization_id
      AND child.parent_id = pr.parent_id
      AND lower(child.name) = 'general'
      AND COALESCE(child.deleted, false) = false
  )
  RETURNING id
)
UPDATE "public"."CatalogItems" ci
SET category_id = child.id
FROM "public"."CatalogCategories" parent
JOIN LATERAL (
  SELECT c.id
  FROM "public"."CatalogCategories" c
  WHERE c.organization_id = parent.organization_id
    AND c.parent_id = parent.id
    AND COALESCE(c.deleted, false) = false
  ORDER BY
    CASE WHEN lower(c.name) = 'general' THEN 0 ELSE 1 END,
    c.sort_order,
    c.name
  LIMIT 1
) child ON true
WHERE ci.category_id = parent.id
  AND COALESCE(parent.deleted, false) = false
  AND (COALESCE(parent.is_group, false) = true OR parent.parent_id IS NULL);

