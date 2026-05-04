SET search_path = public;

DROP FUNCTION IF EXISTS public.upsert_dealer_configurator_policy(
  uuid,
  uuid,
  text[],
  boolean,
  boolean,
  boolean,
  boolean
);
