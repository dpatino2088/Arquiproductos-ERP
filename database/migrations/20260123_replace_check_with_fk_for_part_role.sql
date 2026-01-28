-- ====================================================
-- MIGRATION: Reemplazar CHECK constraint con FOREIGN KEY para part_role
-- Date: 2026-01-23
-- Description: 
--   Arquitectura correcta: Usar CatalogItemRoles como fuente única de verdad
--   para roles de componentes. Elimina CHECK constraint hardcodeado y usa
--   FOREIGN KEY constraint dinámico.
-- ====================================================
-- 
-- DECISIÓN ARQUITECTÓNICA ESTRUCTURAL:
-- ❌ NO: CHECK constraints con listas hardcodeadas de roles
-- ✅ SÍ: FOREIGN KEY contra tabla canónica CatalogItemRoles
--
-- Ventajas:
-- - Escalable: agregar roles sin migraciones
-- - Consistente: fuente única de verdad
-- - Dinámico: validación automática
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Crear tabla CatalogItemRoles si no existe y agregar columnas faltantes
-- ====================================================

-- Crear tabla si no existe (solo con role_code como PK)
CREATE TABLE IF NOT EXISTS "public"."CatalogItemRoles" (
    "role_code" text NOT NULL,
    CONSTRAINT "catalogitemroles_pkey" PRIMARY KEY ("role_code")
);

-- Agregar columnas adicionales si no existen
DO $$
BEGIN
    -- label (si la tabla ya tiene esta columna, necesitamos manejarla)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'label'
    ) THEN
        -- Si no existe, crear label como opcional (puede ser que no la necesitemos)
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "label" text;
    END IF;
    
    -- role_name
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'role_name'
    ) THEN
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "role_name" text NOT NULL DEFAULT '';
        
        -- Generar role_name desde role_code para registros existentes
        UPDATE "public"."CatalogItemRoles"
        SET role_name = initcap(replace(role_code, '_', ' '));
    ELSE
        -- Si la columna ya existe, actualizar solo los que no tienen role_name válido
        UPDATE "public"."CatalogItemRoles"
        SET role_name = initcap(replace(role_code, '_', ' '))
        WHERE role_name IS NULL OR role_name = '';
    END IF;
    
    -- Si label existe y es NOT NULL, actualizar los registros que no tienen label
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'label'
        AND is_nullable = 'NO'
    ) THEN
        -- Generar label desde role_code para registros existentes que no tienen label
        UPDATE "public"."CatalogItemRoles"
        SET label = COALESCE(label, initcap(replace(role_code, '_', ' ')))
        WHERE label IS NULL;
    END IF;
    
    -- role_description
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'role_description'
    ) THEN
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "role_description" text;
    END IF;
    
    -- is_active
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "is_active" boolean DEFAULT true NOT NULL;
    END IF;
    
    -- created_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "created_at" timestamptz DEFAULT now() NOT NULL;
    END IF;
    
    -- updated_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItemRoles' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE "public"."CatalogItemRoles"
        ADD COLUMN "updated_at" timestamptz DEFAULT now() NOT NULL;
    END IF;
END $$;

-- Comentarios
COMMENT ON TABLE "public"."CatalogItemRoles" IS 
'Tabla canónica de roles de componentes. Fuente única de verdad para item_role y part_role en todo el sistema.';

COMMENT ON COLUMN "public"."CatalogItemRoles"."role_code" IS 
'Código único del role (snake_case). Debe coincidir exactamente con valores usados en CatalogItems.item_role, BOMTemplateSlots.item_role, y BomInstanceLines.part_role.';

COMMENT ON COLUMN "public"."CatalogItemRoles"."role_name" IS 
'Nombre legible del role (ej: "Motor", "Headbox", "Bottom Bar")';

COMMENT ON COLUMN "public"."CatalogItemRoles"."role_description" IS 
'Descripción opcional del role';

-- Garantizar unicidad de role_code
CREATE UNIQUE INDEX IF NOT EXISTS "catalogitemroles_role_code_uniq"
ON "public"."CatalogItemRoles"("role_code");

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_catalogitemroles_updated_at" ON "public"."CatalogItemRoles";
CREATE TRIGGER "trg_catalogitemroles_updated_at"
    BEFORE UPDATE ON "public"."CatalogItemRoles"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 2: Poblar CatalogItemRoles con roles existentes
-- ====================================================

-- Recopilar todos los roles únicos que existen en el sistema
DO $$
DECLARE
    v_role_code text;
    v_role_name text;
    v_all_roles text[];
BEGIN
    -- Inicializar array vacío si v_all_roles es NULL
    IF v_all_roles IS NULL THEN
        v_all_roles := ARRAY[]::text[];
    END IF;
    
    -- Obtener roles únicos de CatalogItems
    SELECT COALESCE(ARRAY_AGG(DISTINCT item_role ORDER BY item_role) FILTER (WHERE item_role IS NOT NULL), ARRAY[]::text[])
    INTO v_all_roles
    FROM "public"."CatalogItems"
    WHERE item_role IS NOT NULL;
    
    -- Agregar roles únicos de BOMTemplateSlots
    IF EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" WHERE item_role IS NOT NULL) THEN
        SELECT ARRAY(
            SELECT DISTINCT unnest(v_all_roles) 
            UNION 
            SELECT DISTINCT item_role 
            FROM "public"."BOMTemplateSlots" 
            WHERE item_role IS NOT NULL
        )
        INTO v_all_roles;
    END IF;
    
    -- Agregar roles únicos de BomInstanceLines
    IF EXISTS (SELECT 1 FROM "public"."BomInstanceLines" WHERE part_role IS NOT NULL) THEN
        SELECT ARRAY(
            SELECT DISTINCT unnest(v_all_roles) 
            UNION 
            SELECT DISTINCT part_role 
            FROM "public"."BomInstanceLines" 
            WHERE part_role IS NOT NULL
        )
        INTO v_all_roles;
    END IF;
    
    -- Agregar roles conocidos que pueden no estar en los datos aún
    v_all_roles := v_all_roles || ARRAY[
        'motor', 'headbox', 'bottom_bar', 'side_channel', 'bottom_channel', 'drive',
        'tube', 'fabric', 'cassette', 'fascia', 'mount_profile',
        'top_rail_profile', 'bottom_bar_profile', 'bottom_rail_profile',
        'side_channel_profile', 'track', 'drive_manual', 'drive_motorized',
        'drive_adapter', 'idler', 'bracket', 'sub_bracket', 'end_cap',
        'screw_cap', 'chain', 'chain_clip', 'belt', 'handle', 'hardware',
        'fastener', 'consumable', 'filler', 'carrier', 'hook', 'tape', 'window_film'
    ];
    
    -- Eliminar duplicados y NULL - usar una subconsulta correcta
    SELECT ARRAY(
        SELECT DISTINCT elem 
        FROM unnest(v_all_roles) AS elem 
        WHERE elem IS NOT NULL 
        ORDER BY elem
    )
    INTO v_all_roles;
    
    -- Insertar roles en CatalogItemRoles si no existen
    FOREACH v_role_code IN ARRAY v_all_roles
    LOOP
        -- Generar nombre legible desde código (ej: 'bottom_bar' -> 'Bottom Bar')
        v_role_name := initcap(replace(v_role_code, '_', ' '));
        
        -- Verificar si la columna label existe y es NOT NULL
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'CatalogItemRoles' 
            AND column_name = 'label'
            AND is_nullable = 'NO'
        ) THEN
            -- Insertar con label si es NOT NULL
            INSERT INTO "public"."CatalogItemRoles" (role_code, role_name, label, is_active)
            VALUES (v_role_code, v_role_name, v_role_name, true)
            ON CONFLICT (role_code) DO UPDATE 
            SET role_name = EXCLUDED.role_name,
                label = COALESCE(EXCLUDED.label, EXCLUDED.role_name);
        ELSE
            -- Insertar sin label si no existe o es nullable
            INSERT INTO "public"."CatalogItemRoles" (role_code, role_name, is_active)
            VALUES (v_role_code, v_role_name, true)
            ON CONFLICT (role_code) DO UPDATE 
            SET role_name = EXCLUDED.role_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ CatalogItemRoles poblada con % roles', array_length(v_all_roles, 1);
END $$;

-- ====================================================
-- STEP 3: Validar que no hay data inválida antes de crear FK
-- ====================================================

DO $$
DECLARE
    v_invalid_roles text[];
BEGIN
    -- Verificar roles en BomInstanceLines que no existen en CatalogItemRoles
    SELECT ARRAY_AGG(DISTINCT bil.part_role)
    INTO v_invalid_roles
    FROM "public"."BomInstanceLines" bil
    WHERE bil.part_role IS NOT NULL
      AND bil.deleted = false
      AND NOT EXISTS (
          SELECT 1 FROM "public"."CatalogItemRoles" cir
          WHERE cir.role_code = bil.part_role
          AND cir.is_active = true
      );
    
    IF v_invalid_roles IS NOT NULL AND array_length(v_invalid_roles, 1) > 0 THEN
        RAISE WARNING '⚠️ Encontrados % roles inválidos en BomInstanceLines: %', array_length(v_invalid_roles, 1), v_invalid_roles;
        RAISE WARNING '⚠️ Estos roles serán agregados automáticamente a CatalogItemRoles';
        
        -- Agregar roles faltantes automáticamente
        -- Verificar si label existe y es NOT NULL
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'CatalogItemRoles' 
            AND column_name = 'label'
            AND is_nullable = 'NO'
        ) THEN
            INSERT INTO "public"."CatalogItemRoles" (role_code, role_name, label, is_active)
            SELECT 
                unnest(v_invalid_roles) as role_code,
                initcap(replace(unnest(v_invalid_roles), '_', ' ')) as role_name,
                initcap(replace(unnest(v_invalid_roles), '_', ' ')) as label,
                true as is_active
            ON CONFLICT (role_code) DO NOTHING;
        ELSE
            INSERT INTO "public"."CatalogItemRoles" (role_code, role_name, is_active)
            SELECT 
                unnest(v_invalid_roles) as role_code,
                initcap(replace(unnest(v_invalid_roles), '_', ' ')) as role_name,
                true as is_active
            ON CONFLICT (role_code) DO NOTHING;
        END IF;
        
        RAISE NOTICE '✅ Roles inválidos agregados a CatalogItemRoles';
    ELSE
        RAISE NOTICE '✅ Todos los roles en BomInstanceLines existen en CatalogItemRoles';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Eliminar CHECK constraint obsoleto
-- ====================================================

DO $$
BEGIN
    -- Eliminar el CHECK constraint antiguo
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bominstancelines_part_role_check'
        AND conrelid = 'public."BomInstanceLines"'::regclass
    ) THEN
        ALTER TABLE "public"."BomInstanceLines"
        DROP CONSTRAINT bominstancelines_part_role_check;
        
        RAISE NOTICE '✅ CHECK constraint bominstancelines_part_role_check eliminado';
    ELSE
        RAISE NOTICE '⚠️ CHECK constraint bominstancelines_part_role_check no existe (puede haber sido eliminado previamente)';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Crear FOREIGN KEY constraint
-- ====================================================

DO $$
BEGIN
    -- Verificar que el constraint no existe ya
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bominstancelines_part_role_fkey'
        AND conrelid = 'public."BomInstanceLines"'::regclass
    ) THEN
        -- Crear FOREIGN KEY constraint
        ALTER TABLE "public"."BomInstanceLines"
        ADD CONSTRAINT bominstancelines_part_role_fkey
        FOREIGN KEY (part_role)
        REFERENCES "public"."CatalogItemRoles"(role_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;
        
        RAISE NOTICE '✅ FOREIGN KEY constraint bominstancelines_part_role_fkey creado';
    ELSE
        RAISE NOTICE '⚠️ FOREIGN KEY constraint bominstancelines_part_role_fkey ya existe';
    END IF;
END $$;

-- ====================================================
-- STEP 6: Actualizar comentarios
-- ====================================================

COMMENT ON COLUMN "public"."BomInstanceLines"."part_role" IS 
'Role del componente (ej: motor, headbox, bottom_bar, tube, etc.). DEBE coincidir exactamente con CatalogItemRoles.role_code. DO NOT usar CHECK constraints para roles - usar FOREIGN KEY contra CatalogItemRoles.';

-- ====================================================
-- STEP 7: Verificación final
-- ====================================================

DO $$
DECLARE
    v_check_constraint_exists boolean;
    v_fk_constraint_exists boolean;
    v_invalid_count integer;
BEGIN
    -- Verificar que el CHECK constraint fue eliminado
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bominstancelines_part_role_check'
        AND conrelid = 'public."BomInstanceLines"'::regclass
    ) INTO v_check_constraint_exists;
    
    -- Verificar que el FK constraint existe
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bominstancelines_part_role_fkey'
        AND conrelid = 'public."BomInstanceLines"'::regclass
    ) INTO v_fk_constraint_exists;
    
    -- Contar roles inválidos
    SELECT COUNT(DISTINCT bil.part_role)
    INTO v_invalid_count
    FROM "public"."BomInstanceLines" bil
    WHERE bil.part_role IS NOT NULL
      AND bil.deleted = false
      AND NOT EXISTS (
          SELECT 1 FROM "public"."CatalogItemRoles" cir
          WHERE cir.role_code = bil.part_role
          AND cir.is_active = true
      );
    
    -- Reporte final
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 VERIFICACIÓN FINAL DE MIGRACIÓN';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE 'CHECK constraint eliminado: %', CASE WHEN NOT v_check_constraint_exists THEN '✅ SÍ' ELSE '❌ NO' END;
    RAISE NOTICE 'FK constraint creado: %', CASE WHEN v_fk_constraint_exists THEN '✅ SÍ' ELSE '❌ NO' END;
    RAISE NOTICE 'Roles inválidos en BomInstanceLines: %', v_invalid_count;
    RAISE NOTICE 'Total roles en CatalogItemRoles: %', (SELECT COUNT(*) FROM "public"."CatalogItemRoles");
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    
    IF v_check_constraint_exists THEN
        RAISE WARNING '⚠️ ATENCIÓN: El CHECK constraint todavía existe. La migración puede haber fallado.';
    END IF;
    
    IF NOT v_fk_constraint_exists THEN
        RAISE EXCEPTION '❌ ERROR: El FK constraint NO fue creado. La migración falló.';
    END IF;
    
    IF v_invalid_count > 0 THEN
        RAISE WARNING '⚠️ ATENCIÓN: Hay % roles inválidos en BomInstanceLines que no existen en CatalogItemRoles.', v_invalid_count;
    END IF;
END $$;

COMMIT;

-- ====================================================
-- NOTAS POST-MIGRACIÓN:
-- ====================================================
-- 1. ✅ La tabla CatalogItemRoles es ahora la fuente única de verdad para roles
-- 2. ✅ BomInstanceLines.part_role ahora valida contra CatalogItemRoles.role_code vía FK
-- 3. ✅ Para agregar nuevos roles, simplemente inserta en CatalogItemRoles
-- 4. ✅ NO crear más CHECK constraints para roles - usar FK contra CatalogItemRoles
-- 5. ✅ El código SQL debe usar roles directamente sin transformaciones
-- ====================================================
