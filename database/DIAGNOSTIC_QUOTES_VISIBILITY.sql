-- ============================================================================
-- DIAGNÓSTICO: No se ven cotizaciones de Arquiluz
-- Ejecutar en Supabase SQL Editor con tu organization_id
-- ============================================================================

-- 1) ¿Existen cotizaciones para la organización? (reemplaza ORG_ID)
-- SELECT id, quote_no, organization_id, dealer_id, status, deleted, created_at 
-- FROM public."Quotes" 
-- WHERE organization_id = 'ORG_ID'::uuid 
--   AND (deleted IS FALSE OR deleted IS NULL)
-- ORDER BY created_at DESC;

-- 2) Obtener org_id de Arquiluz por nombre:
SELECT id, name FROM public."Organizations" WHERE LOWER(name) LIKE '%arquiluz%' AND (deleted IS FALSE OR deleted IS NULL);

-- 3) Con el id anterior, contar quotes:
-- SELECT COUNT(*) as total_quotes 
-- FROM public."Quotes" 
-- WHERE organization_id = '(pegar_id_aqui)'::uuid 
--   AND (deleted IS FALSE OR deleted IS NULL);

-- 4) Si eres usuario PORTAL (DealerUser): ¿tienes dealer_id en DealerUsers?
-- Reemplaza USER_EMAIL con tu email:
-- SELECT du.id, du.organization_id, du.dealer_id, du.portal_user_email, du.user_id, du.status
-- FROM public."DealerUsers" du
-- WHERE (du.portal_user_email ILIKE 'USER_EMAIL' OR du.user_id = auth.uid())
--   AND du.deleted IS FALSE;

-- 5) Si eres usuario INTERNAL (OrganizationUser): ¿estás en OrganizationUsers?
-- SELECT ou.id, ou.organization_id, ou.user_id, ou.role, ou.status
-- FROM public."OrganizationUsers" ou
-- WHERE ou.user_id = auth.uid() AND ou.deleted IS FALSE;

-- 6) Verificar current_dealer_id (para portal):
-- SELECT public.current_dealer_id('(pegar_org_id)'::uuid) as my_dealer_id;
