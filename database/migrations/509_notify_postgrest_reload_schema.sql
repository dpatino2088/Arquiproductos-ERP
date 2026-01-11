-- ====================================================
-- Migration: Notify PostgREST to reload schema
-- ====================================================
-- OBJETIVO: Forzar recarga del schema en PostgREST
-- ====================================================

BEGIN;

NOTIFY pgrst, 'reload schema';

COMMIT;
