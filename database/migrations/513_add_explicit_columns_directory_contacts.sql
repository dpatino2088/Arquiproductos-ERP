-- ============================================================
-- Migration: Add explicit columns to DirectoryContacts
-- ============================================================
-- Agregar todas las columnas explícitas requeridas para DirectoryContacts
-- con migración de datos desde columnas genéricas si existen

-- Crear enum contact_type si no existe (fuera del bloque DO principal)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contact_type') THEN
    CREATE TYPE public.contact_type AS ENUM (
      'architect',
      'interior_designer',
      'engineer',
      'project_manager',
      'end_customer'
    );
  END IF;
END $$;

-- Agregar columnas explícitas
DO $$
BEGIN
  -- 1) contact_title
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_title'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_title text;
    
    -- Migrar desde 'title' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'title'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_title = title
      WHERE contact_title IS NULL AND title IS NOT NULL;
    END IF;
  END IF;

  -- 2) contact_id_number
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_id_number'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_id_number text;
    
    -- Migrar desde 'id_number' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'id_number'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_id_number = id_number
      WHERE contact_id_number IS NULL AND id_number IS NOT NULL;
    END IF;
  END IF;

  -- 3) contact_type (enum)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_type'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_type public.contact_type;
    
    -- Migrar desde 'type' si existe (puede ser text o enum)
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'type'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_type = type::text::public.contact_type
      WHERE contact_type IS NULL AND type IS NOT NULL
      AND type::text IN ('architect', 'interior_designer', 'engineer', 'project_manager', 'end_customer');
    END IF;
  END IF;

  -- 4) contact_primary_phone
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_primary_phone'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_primary_phone text;
    
    -- Migrar desde 'primary_phone' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'primary_phone'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_primary_phone = primary_phone
      WHERE contact_primary_phone IS NULL AND primary_phone IS NOT NULL;
    END IF;
  END IF;

  -- 5) contact_cell_phone
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_cell_phone'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_cell_phone text;
    
    -- Migrar desde 'cell_phone' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'cell_phone'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_cell_phone = cell_phone
      WHERE contact_cell_phone IS NULL AND cell_phone IS NOT NULL;
    END IF;
  END IF;

  -- 6) contact_alt_phone
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_alt_phone'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_alt_phone text;
    
    -- Migrar desde 'alt_phone' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'alt_phone'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_alt_phone = alt_phone
      WHERE contact_alt_phone IS NULL AND alt_phone IS NOT NULL;
    END IF;
  END IF;

  -- 7) contact_street_address
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_street_address'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_street_address text;
    
    -- Migrar desde 'street_address' o 'street_address_line_1' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'street_address'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_street_address = street_address
      WHERE contact_street_address IS NULL AND street_address IS NOT NULL;
    ELSIF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'street_address_line_1'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_street_address = street_address_line_1
      WHERE contact_street_address IS NULL AND street_address_line_1 IS NOT NULL;
    END IF;
  END IF;

  -- 8) contact_street_address_2
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_street_address_2'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_street_address_2 text;
    
    -- Migrar desde 'street_address_2' o 'street_address_line_2' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'street_address_2'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_street_address_2 = street_address_2
      WHERE contact_street_address_2 IS NULL AND street_address_2 IS NOT NULL;
    ELSIF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'street_address_line_2'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_street_address_2 = street_address_line_2
      WHERE contact_street_address_2 IS NULL AND street_address_line_2 IS NOT NULL;
    END IF;
  END IF;

  -- 9) contact_city
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_city'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_city text;
    
    -- Migrar desde 'city' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'city'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_city = city
      WHERE contact_city IS NULL AND city IS NOT NULL;
    END IF;
  END IF;

  -- 10) contact_state
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_state'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_state text;
    
    -- Migrar desde 'state' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'state'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_state = state
      WHERE contact_state IS NULL AND state IS NOT NULL;
    END IF;
  END IF;

  -- 11) contact_zip_code
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_zip_code'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_zip_code text;
    
    -- Migrar desde 'zip_code' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'zip_code'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_zip_code = zip_code
      WHERE contact_zip_code IS NULL AND zip_code IS NOT NULL;
    END IF;
  END IF;

  -- 12) contact_country
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'contact_country'
  ) THEN
    ALTER TABLE public."DirectoryContacts" ADD COLUMN contact_country text;
    
    -- Migrar desde 'country' si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' AND column_name = 'country'
    ) THEN
      UPDATE public."DirectoryContacts"
      SET contact_country = country
      WHERE contact_country IS NULL AND country IS NOT NULL;
    END IF;
  END IF;

END $$;

-- Log success
DO $$
BEGIN
  RAISE NOTICE 'Migration 513: Explicit columns added to DirectoryContacts';
END $$;
