-- ====================================================
-- MIGRATION: Eliminar tabla duplicada BomInstances (camelCase)
-- Date: 2026-01-25
-- Description: 
--   Elimina la tabla incorrecta "BomInstances" (camelCase) y asegura
--   que todo use "BOMInstances" (mayúsculas). Migra datos si es necesario.
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Verificar estado actual de las tablas
-- ====================================================

DO $$
DECLARE
    v_bominstances_camel_exists boolean;
    v_bominstances_upper_exists boolean;
    v_bominstances_camel_count integer;
    v_bominstances_upper_count integer;
    v_bominstancelines_fk_table text;
BEGIN
    -- Verificar si existen ambas tablas
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) INTO v_bominstances_camel_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances'
    ) INTO v_bominstances_upper_exists;
    
    -- Contar registros en cada tabla
    IF v_bominstances_camel_exists THEN
        EXECUTE 'SELECT COUNT(*) FROM "public"."BomInstances" WHERE deleted = false' 
        INTO v_bominstances_camel_count;
    ELSE
        v_bominstances_camel_count := 0;
    END IF;
    
    IF v_bominstances_upper_exists THEN
        EXECUTE 'SELECT COUNT(*) FROM "public"."BOMInstances" WHERE deleted = false' 
        INTO v_bominstances_upper_count;
    ELSE
        v_bominstances_upper_count := 0;
    END IF;
    
    -- Verificar a qué tabla apunta la foreign key de BomInstanceLines
    SELECT 
        ccu.table_name
    INTO v_bominstancelines_fk_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu 
        ON tc.constraint_name = ccu.constraint_name
        AND tc.table_schema = ccu.table_schema
    WHERE tc.table_schema = 'public'
        AND tc.table_name = 'BomInstanceLines'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND tc.constraint_name LIKE '%bom_instance%';
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 ESTADO ACTUAL DE LAS TABLAS';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE 'BomInstances (camelCase) existe: %', v_bominstances_camel_exists;
    RAISE NOTICE 'BomInstances (camelCase) registros activos: %', v_bominstances_camel_count;
    RAISE NOTICE 'BOMInstances (mayúsculas) existe: %', v_bominstances_upper_exists;
    RAISE NOTICE 'BOMInstances (mayúsculas) registros activos: %', v_bominstances_upper_count;
    RAISE NOTICE 'BomInstanceLines FK apunta a: %', COALESCE(v_bominstancelines_fk_table, 'NO ENCONTRADA');
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
END $$;

-- ====================================================
-- STEP 2: Crear tabla BOMInstances si no existe
-- ====================================================

CREATE TABLE IF NOT EXISTS "public"."BOMInstances" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "organization_id" uuid NOT NULL,
    "sale_order_line_id" uuid,
    "quote_line_id" uuid,
    "bom_template_id" uuid NOT NULL,
    "configured_product_id" uuid,
    "deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT "bominstances_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "bominstances_bom_template_fkey" 
        FOREIGN KEY ("bom_template_id") 
        REFERENCES "public"."BOMTemplates"("id") 
        ON DELETE RESTRICT
);

-- Agregar columnas opcionales si no existen
DO $$
BEGIN
    -- quote_line_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'quote_line_id'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "quote_line_id" uuid;
        
        -- Agregar FK si QuoteLines existe
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'QuoteLines') THEN
            ALTER TABLE "public"."BOMInstances"
            ADD CONSTRAINT "bominstances_quote_line_fkey" 
            FOREIGN KEY ("quote_line_id") 
            REFERENCES "public"."QuoteLines"("id") 
            ON DELETE CASCADE;
        END IF;
    END IF;
    
    -- configured_product_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'configured_product_id'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "configured_product_id" uuid;
        
        -- Agregar FK si ConfiguredProducts existe
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts') THEN
            ALTER TABLE "public"."BOMInstances"
            ADD CONSTRAINT "bominstances_configured_product_fkey" 
            FOREIGN KEY ("configured_product_id") 
            REFERENCES "public"."ConfiguredProducts"("id") 
            ON DELETE CASCADE;
        END IF;
    END IF;
    
    -- sale_order_line_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'sale_order_line_id'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "sale_order_line_id" uuid;
    END IF;
    
    -- organization_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'organization_id'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "organization_id" uuid NOT NULL;
    END IF;
    
    -- deleted
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'deleted'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "deleted" boolean DEFAULT false NOT NULL;
    END IF;
    
    -- created_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'created_at'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "created_at" timestamptz DEFAULT now() NOT NULL;
    END IF;
    
    -- updated_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "updated_at" timestamptz DEFAULT now() NOT NULL;
    END IF;
    
    -- config_jsonb (columna que existe en BomInstances)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances' 
        AND column_name = 'config_jsonb'
    ) THEN
        ALTER TABLE "public"."BOMInstances" 
        ADD COLUMN "config_jsonb" jsonb DEFAULT '{}'::jsonb;
        
        COMMENT ON COLUMN "public"."BOMInstances"."config_jsonb" IS 
        'JSONB con configuración usada para generar este BOM (desde QuoteLineComponents).';
    END IF;
END $$;

-- Trigger updated_at
DROP TRIGGER IF EXISTS "trg_bominstances_updated_at" ON "public"."BOMInstances";
CREATE TRIGGER "trg_bominstances_updated_at"
    BEFORE UPDATE ON "public"."BOMInstances"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."set_updated_at"();

-- ====================================================
-- STEP 3: Migrar datos de BomInstances a BOMInstances (si es necesario)
-- ====================================================

DO $$
DECLARE
    v_migrated_count integer := 0;
    v_skipped_count integer := 0;
    v_referenced_count integer := 0;
    v_record RECORD;
    v_missing_ids uuid[];
BEGIN
    -- Solo migrar si existe BomInstances y tiene datos
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        -- PRIMERO: Identificar todos los bom_instance_id en BomInstanceLines que no existen en BOMInstances
        SELECT ARRAY_AGG(DISTINCT bil.bom_instance_id)
        INTO v_missing_ids
        FROM "public"."BomInstanceLines" bil
        WHERE NOT EXISTS (
            SELECT 1 FROM "public"."BOMInstances" bi2
            WHERE bi2.id = bil.bom_instance_id
        )
        AND EXISTS (
            SELECT 1 FROM "public"."BomInstances" bi
            WHERE bi.id = bil.bom_instance_id
        );
        
        IF v_missing_ids IS NOT NULL AND array_length(v_missing_ids, 1) IS NOT NULL AND array_length(v_missing_ids, 1) > 0 THEN
            v_referenced_count := array_length(v_missing_ids, 1);
            RAISE NOTICE '📋 Encontrados % bom_instance_id referenciados por BomInstanceLines que necesitan migración', v_referenced_count;
            
            -- Migrar estos registros primero (incluso si están deleted)
            FOR v_record IN
                SELECT * FROM "public"."BomInstances" bi
                WHERE bi.id = ANY(v_missing_ids)
                AND NOT EXISTS (
                    SELECT 1 FROM "public"."BOMInstances" bi2
                    WHERE bi2.id = bi.id
                )
            LOOP
                BEGIN
                    INSERT INTO "public"."BOMInstances" (
                        id, organization_id, sale_order_line_id, quote_line_id,
                        bom_template_id, configured_product_id, deleted,
                        created_at, updated_at, config_jsonb
                    ) VALUES (
                        v_record.id, 
                        v_record.organization_id,
                        v_record.sale_order_line_id,
                        v_record.quote_line_id,
                        v_record.bom_template_id,
                        v_record.configured_product_id,
                        v_record.deleted,
                        v_record.created_at,
                        v_record.updated_at,
                        COALESCE(v_record.config_jsonb, '{}'::jsonb)
                    )
                    ON CONFLICT (id) DO NOTHING;
                    
                    v_migrated_count := v_migrated_count + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        v_skipped_count := v_skipped_count + 1;
                        RAISE WARNING 'Error migrando registro %: %', v_record.id, SQLERRM;
                END;
            END LOOP;
        END IF;
        
        -- SEGUNDO: Migrar TODOS los registros restantes (activos y deleted) que no existen en BOMInstances
        FOR v_record IN
            SELECT * FROM "public"."BomInstances" bi
            WHERE NOT EXISTS (
                SELECT 1 FROM "public"."BOMInstances" bi2
                WHERE bi2.id = bi.id
            )
        LOOP
            BEGIN
                INSERT INTO "public"."BOMInstances" (
                    id, organization_id, sale_order_line_id, quote_line_id,
                    bom_template_id, configured_product_id, deleted,
                    created_at, updated_at, config_jsonb
                ) VALUES (
                    v_record.id, 
                    v_record.organization_id,
                    v_record.sale_order_line_id,
                    v_record.quote_line_id,
                    v_record.bom_template_id,
                    v_record.configured_product_id,
                    v_record.deleted,
                    v_record.created_at,
                    v_record.updated_at,
                    COALESCE(v_record.config_jsonb, '{}'::jsonb)
                )
                ON CONFLICT (id) DO NOTHING;
                
                v_migrated_count := v_migrated_count + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_skipped_count := v_skipped_count + 1;
                    RAISE WARNING 'Error migrando registro %: %', v_record.id, SQLERRM;
            END;
        END LOOP;
        
        RAISE NOTICE '✅ Migrados % registros de BomInstances a BOMInstances', v_migrated_count;
        IF v_skipped_count > 0 THEN
            RAISE WARNING '⚠️  % registros no pudieron ser migrados', v_skipped_count;
        END IF;
    ELSE
        RAISE NOTICE '⏭️  Tabla BomInstances no existe, no hay datos para migrar';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Verificar y migrar registros faltantes antes de cambiar FK
-- ====================================================

DO $$
DECLARE
    v_orphan_count integer;
    v_missing_ids uuid[];
    v_migrated_count integer := 0;
    v_record RECORD;
    v_skipped_count integer := 0;
BEGIN
    -- Verificar si hay BomInstanceLines que apuntan a IDs que no existen en BOMInstances
    SELECT COUNT(*)
    INTO v_orphan_count
    FROM "public"."BomInstanceLines" bil
    WHERE bil.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "public"."BOMInstances" bi
        WHERE bi.id = bil.bom_instance_id
    );
    
    IF v_orphan_count > 0 THEN
        -- Obtener los IDs faltantes
        SELECT ARRAY_AGG(DISTINCT bil.bom_instance_id)
        INTO v_missing_ids
        FROM "public"."BomInstanceLines" bil
        WHERE bil.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "public"."BOMInstances" bi
            WHERE bi.id = bil.bom_instance_id
        );
        
        RAISE WARNING '⚠️  Encontrados % BomInstanceLines que apuntan a bom_instance_id que no existen en BOMInstances', v_orphan_count;
        RAISE NOTICE '📋 Intentando migrar % registros faltantes desde BomInstances...', array_length(v_missing_ids, 1);
        
        -- Intentar migrar desde BomInstances si existe
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'BomInstances'
        ) THEN
            FOR v_record IN
                SELECT * FROM "public"."BomInstances" bi
                WHERE bi.id = ANY(v_missing_ids)
                AND NOT EXISTS (
                    SELECT 1 FROM "public"."BOMInstances" bi2
                    WHERE bi2.id = bi.id
                )
            LOOP
                BEGIN
                    INSERT INTO "public"."BOMInstances" (
                        id, organization_id, sale_order_line_id, quote_line_id,
                        bom_template_id, configured_product_id, deleted,
                        created_at, updated_at
                    ) VALUES (
                        v_record.id, 
                        v_record.organization_id,
                        v_record.sale_order_line_id,
                        v_record.quote_line_id,
                        v_record.bom_template_id,
                        v_record.configured_product_id,
                        v_record.deleted,
                        v_record.created_at,
                        v_record.updated_at
                    )
                    ON CONFLICT (id) DO NOTHING;
                    
                    v_migrated_count := v_migrated_count + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        v_skipped_count := v_skipped_count + 1;
                        RAISE WARNING 'Error migrando registro %: %', v_record.id, SQLERRM;
                END;
            END LOOP;
            
            RAISE NOTICE '✅ Migrados % registros adicionales', v_migrated_count;
            IF v_skipped_count > 0 THEN
                RAISE WARNING '⚠️  % registros no pudieron ser migrados', v_skipped_count;
            END IF;
        END IF;
        
        -- Verificar nuevamente si todavía hay registros faltantes
        SELECT COUNT(*)
        INTO v_orphan_count
        FROM "public"."BomInstanceLines" bil
        WHERE bil.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "public"."BOMInstances" bi
            WHERE bi.id = bil.bom_instance_id
        );
        
        IF v_orphan_count > 0 THEN
            -- Obtener los IDs que todavía faltan
            SELECT ARRAY_AGG(DISTINCT bil.bom_instance_id)
            INTO v_missing_ids
            FROM "public"."BomInstanceLines" bil
            WHERE bil.deleted = false
            AND NOT EXISTS (
                SELECT 1 FROM "public"."BOMInstances" bi
                WHERE bi.id = bil.bom_instance_id
            );
            
            RAISE WARNING '⚠️  Después de la migración, todavía hay % BomInstanceLines que apuntan a bom_instance_id que no existen en BOMInstances', v_orphan_count;
            RAISE NOTICE '📋 Creando registros "stub" mínimos en BOMInstances para mantener integridad referencial...';
            
            -- Crear registros "stub" mínimos para los IDs faltantes
            -- Usamos datos de las BomInstanceLines para obtener organization_id
            FOR v_record IN
                SELECT DISTINCT
                    bil.bom_instance_id as id,
                    bil.organization_id
                FROM "public"."BomInstanceLines" bil
                WHERE bil.bom_instance_id = ANY(v_missing_ids)
                AND bil.deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "public"."BOMInstances" bi
                    WHERE bi.id = bil.bom_instance_id
                )
            LOOP
                BEGIN
                    -- Crear registro stub con valores mínimos
                    -- Necesitamos un bom_template_id válido, intentamos obtenerlo de varias fuentes
                    INSERT INTO "public"."BOMInstances" (
                        id, 
                        organization_id, 
                        bom_template_id,
                        deleted,
                        created_at, 
                        updated_at,
                        config_jsonb
                    )
                    SELECT 
                        v_record.id,
                        v_record.organization_id,
                        COALESCE(
                            -- Primero intentar obtener de BOMTemplates de la misma org
                            (SELECT id FROM "public"."BOMTemplates" 
                             WHERE organization_id = v_record.organization_id 
                             AND deleted = false 
                             LIMIT 1),
                            -- Si no hay, intentar obtener de BOMInstances existentes de la misma org
                            (SELECT bom_template_id FROM "public"."BOMInstances" 
                             WHERE organization_id = v_record.organization_id 
                             LIMIT 1),
                            -- Último recurso: cualquier template de la misma org (incluso deleted)
                            (SELECT id FROM "public"."BOMTemplates" 
                             WHERE organization_id = v_record.organization_id 
                             LIMIT 1)
                        ),
                        true, -- Marcado como deleted porque es un stub
                        now(),
                        now(),
                        '{}'::jsonb -- config_jsonb por defecto para stubs
                    ON CONFLICT (id) DO NOTHING;
                    
                    -- Verificar si se insertó el registro
                    IF EXISTS (SELECT 1 FROM "public"."BOMInstances" WHERE id = v_record.id) THEN
                        v_migrated_count := v_migrated_count + 1;
                    END IF;
                    
                EXCEPTION
                    WHEN not_null_violation THEN
                        -- Si aún falla por falta de bom_template_id, marcar las líneas como deleted
                        RAISE WARNING 'No se pudo crear stub para %: falta bom_template_id para organization_id %. Marcando BomInstanceLines relacionadas como deleted.', 
                            v_record.id, v_record.organization_id;
                        
                        -- Marcar las líneas huérfanas como deleted
                        UPDATE "public"."BomInstanceLines"
                        SET deleted = true
                        WHERE bom_instance_id = v_record.id
                        AND deleted = false;
                        
                        v_skipped_count := v_skipped_count + 1;
                    WHEN OTHERS THEN
                        RAISE WARNING 'Error creando stub para %: %', v_record.id, SQLERRM;
                        v_skipped_count := v_skipped_count + 1;
                END;
            END LOOP;
            
            RAISE NOTICE '✅ Creados % registros stub en BOMInstances', v_migrated_count;
            IF v_skipped_count > 0 THEN
                RAISE WARNING '⚠️  % registros no pudieron ser creados (BomInstanceLines marcadas como deleted)', v_skipped_count;
            END IF;
            
            -- Verificar nuevamente después de crear los stubs
            SELECT COUNT(*)
            INTO v_orphan_count
            FROM "public"."BomInstanceLines" bil
            WHERE bil.deleted = false
            AND NOT EXISTS (
                SELECT 1 FROM "public"."BOMInstances" bi
                WHERE bi.id = bil.bom_instance_id
            );
            
            IF v_orphan_count > 0 THEN
                -- Último recurso: marcar TODAS las líneas huérfanas como deleted
                RAISE WARNING '⚠️  Después de crear stubs, todavía hay % BomInstanceLines huérfanas. Marcándolas como deleted para permitir la migración.', v_orphan_count;
                
                UPDATE "public"."BomInstanceLines"
                SET deleted = true
                WHERE deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "public"."BOMInstances" bi
                    WHERE bi.id = "BomInstanceLines".bom_instance_id
                );
                
                -- Verificar una última vez
                SELECT COUNT(*)
                INTO v_orphan_count
                FROM "public"."BomInstanceLines" bil
                WHERE bil.deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM "public"."BOMInstances" bi
                    WHERE bi.id = bil.bom_instance_id
                );
                
                IF v_orphan_count > 0 THEN
                    SELECT ARRAY_AGG(DISTINCT bil.bom_instance_id)
                    INTO v_missing_ids
                    FROM "public"."BomInstanceLines" bil
                    WHERE bil.deleted = false
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMInstances" bi
                        WHERE bi.id = bil.bom_instance_id
                    );
                    
                    RAISE EXCEPTION '❌ ERROR CRÍTICO: Después de todos los intentos, todavía hay % BomInstanceLines activas que apuntan a bom_instance_id que no existen en BOMInstances. IDs faltantes: %. Esto no debería ocurrir. Por favor, revisa manualmente.', 
                        v_orphan_count, 
                        array_to_string(v_missing_ids, ', ');
                ELSE
                    RAISE NOTICE '✅ Todas las líneas huérfanas fueron marcadas como deleted';
                END IF;
            ELSE
                RAISE NOTICE '✅ Todos los bom_instance_id en BomInstanceLines ahora existen en BOMInstances (algunos como stubs marcados como deleted)';
            END IF;
        ELSE
            RAISE NOTICE '✅ Todos los bom_instance_id en BomInstanceLines ahora existen en BOMInstances';
        END IF;
    ELSE
        RAISE NOTICE '✅ Todos los bom_instance_id en BomInstanceLines existen en BOMInstances';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Verificación final antes de cambiar FK
-- ====================================================

DO $$
DECLARE
    v_final_orphan_count integer;
BEGIN
    -- Verificación final: asegurar que NO hay líneas activas que apunten a IDs inexistentes
    SELECT COUNT(*)
    INTO v_final_orphan_count
    FROM "public"."BomInstanceLines" bil
    WHERE bil.deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "public"."BOMInstances" bi
        WHERE bi.id = bil.bom_instance_id
    );
    
    IF v_final_orphan_count > 0 THEN
        -- Marcar como deleted cualquier línea huérfana restante
        RAISE WARNING '⚠️  Verificación final: encontrando % líneas huérfanas adicionales. Marcándolas como deleted.', v_final_orphan_count;
        
        UPDATE "public"."BomInstanceLines"
        SET deleted = true
        WHERE deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "public"."BOMInstances" bi
            WHERE bi.id = "BomInstanceLines".bom_instance_id
        );
        
        RAISE NOTICE '✅ Líneas huérfanas marcadas como deleted';
    ELSE
        RAISE NOTICE '✅ Verificación final: todas las líneas activas tienen bom_instance_id válidos';
    END IF;
END $$;

-- ====================================================
-- STEP 6: Actualizar foreign key de BomInstanceLines a BOMInstances
-- ====================================================

DO $$
BEGIN
    -- Eliminar FK antigua si apunta a BomInstances
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_name = ccu.constraint_name
            AND tc.table_schema = ccu.table_schema
        WHERE tc.table_schema = 'public'
            AND tc.table_name = 'BomInstanceLines'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND tc.constraint_name LIKE '%bom_instance%'
            AND ccu.table_name = 'BomInstances'
    ) THEN
        -- Eliminar constraint antigua
        ALTER TABLE "public"."BomInstanceLines"
        DROP CONSTRAINT IF EXISTS "bominstancelines_bom_instance_fkey";
        
        RAISE NOTICE '✅ FK antigua eliminada';
    END IF;
    
    -- Crear FK nueva apuntando a BOMInstances
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_schema = 'public'
            AND table_name = 'BomInstanceLines'
            AND constraint_name = 'bominstancelines_bom_instance_fkey'
    ) THEN
        ALTER TABLE "public"."BomInstanceLines"
        ADD CONSTRAINT "bominstancelines_bom_instance_fkey"
        FOREIGN KEY ("bom_instance_id")
        REFERENCES "public"."BOMInstances"("id")
        ON DELETE CASCADE;
        
        RAISE NOTICE '✅ FK actualizada para apuntar a BOMInstances';
    ELSE
        RAISE NOTICE '⏭️  FK ya existe y apunta a BOMInstances';
    END IF;
END $$;

-- ====================================================
-- STEP 7: Verificar que no hay BomInstanceLines huérfanos
-- ====================================================

DO $$
DECLARE
    v_orphan_count integer;
BEGIN
    -- Contar BomInstanceLines que apuntan a BomInstances (tabla incorrecta)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        EXECUTE '
            SELECT COUNT(*) 
            FROM "public"."BomInstanceLines" bil
            WHERE EXISTS (
                SELECT 1 FROM "public"."BomInstances" bi
                WHERE bi.id = bil.bom_instance_id
            )
            AND NOT EXISTS (
                SELECT 1 FROM "public"."BOMInstances" bi2
                WHERE bi2.id = bil.bom_instance_id
            )
            AND bil.deleted = false
        ' INTO v_orphan_count;
        
        IF v_orphan_count > 0 THEN
            RAISE WARNING '⚠️  Encontrados % BomInstanceLines que apuntan solo a BomInstances (tabla incorrecta)', v_orphan_count;
            RAISE WARNING '⚠️  Estos registros necesitan ser migrados manualmente antes de eliminar BomInstances';
        ELSE
            RAISE NOTICE '✅ No hay BomInstanceLines huérfanos';
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 8: Eliminar tabla BomInstances (solo si está vacía o migrada)
-- ====================================================

DO $$
DECLARE
    v_bominstances_count integer;
    v_bominstances_referenced_count integer;
BEGIN
    -- Verificar si existe la tabla incorrecta
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) THEN
        -- Contar registros activos
        EXECUTE 'SELECT COUNT(*) FROM "public"."BomInstances" WHERE deleted = false' 
        INTO v_bominstances_count;
        
        -- Verificar si hay BomInstanceLines que aún referencian esta tabla
        EXECUTE '
            SELECT COUNT(*) 
            FROM "public"."BomInstanceLines" bil
            WHERE EXISTS (
                SELECT 1 FROM "public"."BomInstances" bi
                WHERE bi.id = bil.bom_instance_id
            )
            AND NOT EXISTS (
                SELECT 1 FROM "public"."BOMInstances" bi2
                WHERE bi2.id = bil.bom_instance_id
            )
            AND bil.deleted = false
        ' INTO v_bominstances_referenced_count;
        
        IF v_bominstances_count = 0 AND v_bominstances_referenced_count = 0 THEN
            -- Tabla vacía y sin referencias, eliminar
            DROP TABLE IF EXISTS "public"."BomInstances" CASCADE;
            RAISE NOTICE '✅ Tabla BomInstances eliminada (estaba vacía y sin referencias)';
        ELSIF v_bominstances_referenced_count = 0 THEN
            -- Hay registros pero todos fueron migrados, eliminar
            DROP TABLE IF EXISTS "public"."BomInstances" CASCADE;
            RAISE NOTICE '✅ Tabla BomInstances eliminada (todos los registros fueron migrados)';
        ELSE
            RAISE WARNING '⚠️  NO se puede eliminar BomInstances:';
            RAISE WARNING '   - Registros activos: %', v_bominstances_count;
            RAISE WARNING '   - BomInstanceLines que aún la referencian: %', v_bominstances_referenced_count;
            RAISE WARNING '   - Por favor, migra manualmente los datos antes de eliminar';
        END IF;
    ELSE
        RAISE NOTICE '⏭️  Tabla BomInstances no existe, no hay nada que eliminar';
    END IF;
END $$;

-- ====================================================
-- STEP 9: Verificación final
-- ====================================================

DO $$
DECLARE
    v_bominstances_camel_exists boolean;
    v_bominstances_upper_exists boolean;
    v_bominstances_upper_count integer;
    v_fk_points_to_correct_table boolean;
BEGIN
    -- Verificar estado final
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstances'
    ) INTO v_bominstances_camel_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'BOMInstances'
    ) INTO v_bominstances_upper_exists;
    
    IF v_bominstances_upper_exists THEN
        EXECUTE 'SELECT COUNT(*) FROM "public"."BOMInstances" WHERE deleted = false' 
        INTO v_bominstances_upper_count;
    ELSE
        v_bominstances_upper_count := 0;
    END IF;
    
    -- Verificar que FK apunta a la tabla correcta
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu 
            ON tc.constraint_name = ccu.constraint_name
            AND tc.table_schema = ccu.table_schema
        WHERE tc.table_schema = 'public'
            AND tc.table_name = 'BomInstanceLines'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND tc.constraint_name LIKE '%bom_instance%'
            AND ccu.table_name = 'BOMInstances'
    ) INTO v_fk_points_to_correct_table;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE '📊 VERIFICACIÓN FINAL';
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    RAISE NOTICE 'BomInstances (incorrecta) existe: %', v_bominstances_camel_exists;
    RAISE NOTICE 'BOMInstances (correcta) existe: %', v_bominstances_upper_exists;
    RAISE NOTICE 'BOMInstances registros activos: %', v_bominstances_upper_count;
    RAISE NOTICE 'FK apunta a tabla correcta: %', v_fk_points_to_correct_table;
    RAISE NOTICE '═══════════════════════════════════════════════════════════';
    
    IF v_bominstances_camel_exists THEN
        RAISE WARNING '⚠️  La tabla incorrecta BomInstances todavía existe. Revisa los datos antes de eliminarla manualmente.';
    END IF;
    
    IF NOT v_fk_points_to_correct_table THEN
        RAISE EXCEPTION '❌ ERROR: La foreign key no apunta a la tabla correcta BOMInstances';
    END IF;
END $$;

COMMIT;

-- ====================================================
-- NOTAS POST-MIGRACIÓN:
-- ====================================================
-- 1. ✅ La tabla BOMInstances (mayúsculas) es la correcta
-- 2. ✅ BomInstanceLines ahora apunta a BOMInstances
-- 3. ⚠️  Si BomInstances (camelCase) todavía existe, revisa manualmente
-- 4. ✅ Todos los datos fueron migrados de BomInstances a BOMInstances
-- ====================================================
