CREATE TABLE IF NOT EXISTS public."CatalogItemEngineeringAttrs" (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    catalog_item_id uuid NOT NULL REFERENCES public."CatalogItems"(id) ON DELETE CASCADE,
    organization_id uuid NOT NULL,
    takeup_mm       numeric(12,4),
    offset_mm       numeric(12,4),
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT catalog_item_eng_attrs_unique UNIQUE (catalog_item_id)
);

ALTER TABLE public."CatalogItemEngineeringAttrs" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "eng_attrs_select_org" ON public."CatalogItemEngineeringAttrs";
CREATE POLICY "eng_attrs_select_org" ON public."CatalogItemEngineeringAttrs"
    FOR SELECT
    USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "eng_attrs_insert_org" ON public."CatalogItemEngineeringAttrs";
CREATE POLICY "eng_attrs_insert_org" ON public."CatalogItemEngineeringAttrs"
    FOR INSERT
    WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "eng_attrs_update_org" ON public."CatalogItemEngineeringAttrs";
CREATE POLICY "eng_attrs_update_org" ON public."CatalogItemEngineeringAttrs"
    FOR UPDATE
    USING (public.is_org_user_member_strict(organization_id))
    WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "eng_attrs_delete_org" ON public."CatalogItemEngineeringAttrs";
CREATE POLICY "eng_attrs_delete_org" ON public."CatalogItemEngineeringAttrs"
    FOR DELETE
    USING (public.is_org_user_member_strict(organization_id));

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'engineering_delta_source'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN engineering_delta_source text NOT NULL DEFAULT 'fixed';

        ALTER TABLE public."BOMComponents"
            ADD CONSTRAINT bomcomp_eng_delta_source_check
            CHECK (engineering_delta_source IN ('fixed', 'derived'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'engineering_attr_key'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN engineering_attr_key text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'engineering_scope'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN engineering_scope text NOT NULL DEFAULT 'total';

        ALTER TABLE public."BOMComponents"
            ADD CONSTRAINT bomcomp_eng_scope_check
            CHECK (engineering_scope IN ('total', 'per_side'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'engineering_source_role'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN engineering_source_role text;
    END IF;
END $$;

SELECT 1;;
