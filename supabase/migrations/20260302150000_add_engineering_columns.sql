-- Add missing engineering columns to BOMComponents
-- cut_delta_scope: per_side or per_item (how the delta is applied)
-- affects_role: which role this component affects (for cut operations)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'cut_delta_scope'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN cut_delta_scope text;

        ALTER TABLE public."BOMComponents"
            ADD CONSTRAINT bomcomponents_cut_delta_scope_check
            CHECK (cut_delta_scope IS NULL OR cut_delta_scope IN ('per_side', 'per_item'));

        RAISE NOTICE 'Added cut_delta_scope to BOMComponents';
    ELSE
        RAISE NOTICE 'cut_delta_scope already exists in BOMComponents';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'BOMComponents'
          AND column_name  = 'affects_role'
    ) THEN
        ALTER TABLE public."BOMComponents"
            ADD COLUMN affects_role text;

        RAISE NOTICE 'Added affects_role to BOMComponents';
    ELSE
        RAISE NOTICE 'affects_role already exists in BOMComponents';
    END IF;
END $$;

-- Drop restrictive CHECK on depends_on_role since roles are now DB-driven
-- (managed via CatalogItemRoles table, not hardcoded)
ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS bomcomponents_depends_on_role_check;

SELECT 1;
