--
-- PostgreSQL database dump
--

\restrict 5G05meZYAc8oVX3r7JpYVEa20msRpp4GT7QgLLweqPaeaf3ykuhZAQn4KTa1bkS

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _realtime;


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pg_net; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_net; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_net IS 'Async HTTP';


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: supabase_functions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA supabase_functions;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: bom_component_mode; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.bom_component_mode AS ENUM (
    'select',
    'fixed',
    'auto',
    'optional'
);


--
-- Name: contact_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contact_type AS ENUM (
    'architect',
    'interior_designer',
    'engineer',
    'project_manager',
    'end_customer'
);


--
-- Name: customer_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_type AS ENUM (
    'distributor',
    'reseller',
    'partner',
    'vip'
);


--
-- Name: directory_customer_type_name; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.directory_customer_type_name AS ENUM (
    'contractor',
    'architecture_studio',
    'design_studio',
    'end_user'
);


--
-- Name: headbox_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.headbox_type AS ENUM (
    'none',
    'cassette'
);


--
-- Name: manufacturing_order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.manufacturing_order_status AS ENUM (
    'draft',
    'planned',
    'in_production',
    'completed',
    'cancelled'
);


--
-- Name: material_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.material_type_enum AS ENUM (
    'fabric',
    'film',
    'mesh',
    'vinyl',
    'other'
);


--
-- Name: measure_basis_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.measure_basis_enum AS ENUM (
    'unit',
    'linear',
    'area'
);


--
-- Name: operating_system; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.operating_system AS ENUM (
    'manual',
    'motor'
);


--
-- Name: org_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.org_role AS ENUM (
    'owner',
    'admin',
    'member',
    'viewer',
    'superadmin',
    'operator',
    'procurement',
    'finance'
);


--
-- Name: org_user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.org_user_status AS ENUM (
    'invited',
    'active',
    'disabled'
);


--
-- Name: pack_uom_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pack_uom_enum AS ENUM (
    'ea',
    'm',
    'm2'
);


--
-- Name: portal_user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.portal_user_status AS ENUM (
    'draft',
    'invited',
    'active',
    'disabled'
);


--
-- Name: pricing_basis; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pricing_basis AS ENUM (
    'unit',
    'linear',
    'area'
);


--
-- Name: purchase_uom_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.purchase_uom_enum AS ENUM (
    'm',
    'm2',
    'yd',
    'ft',
    'ea',
    'set',
    'pack'
);


--
-- Name: quote_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.quote_status AS ENUM (
    'draft',
    'sent',
    'approved',
    'canceled'
);


--
-- Name: roll_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.roll_kind AS ENUM (
    'fabric',
    'window_film',
    'vinyl',
    'other'
);


--
-- Name: roll_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.roll_type AS ENUM (
    'fabric',
    'window_film',
    'vinyl',
    'mesh',
    'paper',
    'other'
);


--
-- Name: sales_order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sales_order_status AS ENUM (
    'draft',
    'confirmed',
    'in_production',
    'ready_for_delivery',
    'delivered',
    'cancelled'
);


--
-- Name: sales_order_tracking_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sales_order_tracking_status AS ENUM (
    'pending_confirmation',
    'confirmed',
    'in_production',
    'ready_for_delivery',
    'delivered',
    'canceled'
);


--
-- Name: side_channel_mode; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.side_channel_mode AS ENUM (
    'none',
    'side_only',
    'side_plus_bottom'
);


--
-- Name: supply_form_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.supply_form_enum AS ENUM (
    'each',
    'linear',
    'roll'
);


--
-- Name: system_size; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.system_size AS ENUM (
    's',
    'm',
    'l',
    'xl'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
    ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

    ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
    ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

    REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
    REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

    GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


--
-- Name: _trg_categorymargins_recompute_itemsmsrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._trg_categorymargins_recompute_itemsmsrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_category(new.organization_id, new.category_id);
  return new;
end;
$$;


--
-- Name: _trg_costsettings_recompute_itemsmsrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._trg_costsettings_recompute_itemsmsrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_org(new.organization_id);
  return new;
end;
$$;


--
-- Name: _trg_importtaxrules_recompute_itemsmsrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._trg_importtaxrules_recompute_itemsmsrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform public.recompute_catalogitems_msrp_for_category(new.organization_id, new.category_id);
  return new;
end;
$$;


--
-- Name: approve_quote(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approve_quote(p_quote_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_company_id uuid;
  v_role text;
begin
  select company_id, portal_user_role
  into v_company_id, v_role
  from public."CompanyPortalUsers"
  where user_id = auth.uid()
    and deleted = false
    and portal_user_status = 'active'
  limit 1;

  if v_company_id is null then
    raise exception 'Not a portal user';
  end if;

  if v_role <> 'member_manager' then
    raise exception 'Forbidden: only member_manager can approve quotes';
  end if;

  update public."Quotes"
  set status = 'approved',
      updated_at = now()
  where id = p_quote_id
    and deleted = false
    and company_id = v_company_id;

  if not found then
    raise exception 'Quote not found for your company';
  end if;
end;
$$;


--
-- Name: approve_quote_portal(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approve_quote_portal(p_quote_id uuid, p_action text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_portal_user RECORD;
  v_quote RECORD;
  v_new_status public.quote_status;
  v_result json;
BEGIN
  -- Get current portal user (now uses status column)
  SELECT * INTO v_portal_user
  FROM public.get_current_portal_user()
  LIMIT 1;

  IF v_portal_user.id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated as active portal user';
  END IF;

  -- Validate role: ONLY member_manager can approve
  IF v_portal_user.portal_user_role != 'member_manager' THEN
    RAISE EXCEPTION 'Only member managers can approve/reject quotes';
  END IF;

  -- Get quote
  SELECT * INTO v_quote
  FROM public."Quotes"
  WHERE id = p_quote_id
    AND deleted = false;

  IF v_quote.id IS NULL THEN
    RAISE EXCEPTION 'Quote not found';
  END IF;

  -- Validate company match
  IF v_quote.company_id != v_portal_user.company_id THEN
    RAISE EXCEPTION 'Quote does not belong to your company';
  END IF;

  -- Validate action
  IF p_action NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Invalid action. Must be "approve" or "reject"';
  END IF;

  -- Validate quote status (can only approve/reject from appropriate states)
  -- Allow approval from: 'draft', 'sent', 'pending_approval'
  IF v_quote.status NOT IN ('draft', 'sent', 'pending_approval') THEN
    RAISE EXCEPTION 'Quote status (%) does not allow approval/rejection. Must be draft, sent, or pending_approval', v_quote.status;
  END IF;

  -- Set new status
  IF p_action = 'approve' THEN
    v_new_status := 'approved'::public.quote_status;
  ELSE
    v_new_status := 'rejected'::public.quote_status;
  END IF;

  -- Update quote (bypasses RLS because function is SECURITY DEFINER)
  UPDATE public."Quotes"
  SET 
    status = v_new_status,
    updated_at = now()
  WHERE id = p_quote_id;

  -- Return result
  v_result := json_build_object(
    'success', true,
    'quote_id', p_quote_id,
    'action', p_action,
    'new_status', v_new_status,
    'message', format('Quote %s successfully', p_action)
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


--
-- Name: FUNCTION approve_quote_portal(p_quote_id uuid, p_action text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.approve_quote_portal(p_quote_id uuid, p_action text) IS 'Approve or reject a quote. ONLY member_manager role can call. Validates company match and quote status. Uses status column.';


--
-- Name: build_quote_line_config(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.build_quote_line_config(p_org_id uuid, p_quote_line_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select '{}'::jsonb;
$$;


--
-- Name: calculate_bom_price(uuid, uuid, numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_bom_price(p_parent_item_id uuid, p_organization_id uuid, p_width_m numeric, p_height_m numeric, p_area_sqm numeric) RETURNS TABLE(component_item_id uuid, category_id uuid, basis text, unit_cost numeric, qty numeric, extended_cost numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
  r RECORD;
  j jsonb;

  v_component_item_id uuid;
  v_qty_value numeric;
  v_qty_type text;

  v_basis text;
  v_unit_cost numeric(12,4);

  v_multiplier numeric := 1;
  v_qty numeric(12,4);
BEGIN
  FOR r IN
    SELECT to_jsonb(b) AS j
    FROM public."BOMComponents" b
    WHERE b.organization_id = p_organization_id
      AND b.deleted = false
      AND (
        (to_jsonb(b)->>'parent_item_id')::uuid = p_parent_item_id
        OR (to_jsonb(b)->>'parent_catalog_item_id')::uuid = p_parent_item_id
      )
  LOOP
    j := r.j;

    -- soporta nombres alternos para el componente hijo
    v_component_item_id :=
      COALESCE(
        NULLIF(j->>'child_item_id','')::uuid,
        NULLIF(j->>'component_item_id','')::uuid,
        NULLIF(j->>'catalog_item_id','')::uuid
      );

    IF v_component_item_id IS NULL THEN
      CONTINUE;
    END IF;

    -- soporta qty_value / qty / quantity
    v_qty_value :=
      COALESCE(
        NULLIF(j->>'qty_value','')::numeric,
        NULLIF(j->>'qty','')::numeric,
        NULLIF(j->>'quantity','')::numeric,
        1
      );

    -- soporta qty_type / qty_basis
    v_qty_type :=
      COALESCE(
        NULLIF(j->>'qty_type',''),
        NULLIF(j->>'qty_basis',''),
        'per_unit'
      );

    -- unit cost normalizado (tu función)
    SELECT u.basis, u.unit_cost
    INTO v_basis, v_unit_cost
    FROM public.get_catalog_item_unit_cost_norm(v_component_item_id, p_organization_id) u
    LIMIT 1;

    v_unit_cost := COALESCE(v_unit_cost, 0);

    -- multipliers segun qty_type
    v_multiplier := 1;

    IF v_qty_type IN ('per_width','per_linear_width','per_m_width','per_linear') THEN
      v_multiplier := COALESCE(p_width_m, 0);
    ELSIF v_qty_type IN ('per_height','per_m_height') THEN
      v_multiplier := COALESCE(p_height_m, 0);
    ELSIF v_qty_type IN ('per_area','per_sqm','per_m2') THEN
      v_multiplier := COALESCE(p_area_sqm, COALESCE(p_width_m,0) * COALESCE(p_height_m,0));
    ELSE
      v_multiplier := 1;
    END IF;

    v_qty := round(COALESCE(v_qty_value,1) * COALESCE(v_multiplier,1), 4);

    component_item_id := v_component_item_id;

    -- category_id (si CatalogItems la tiene como item_category_id)
    SELECT ci.item_category_id
    INTO category_id
    FROM public."CatalogItems" ci
    WHERE ci.id = v_component_item_id
    LIMIT 1;

    basis := v_basis;
    unit_cost := v_unit_cost;
    qty := v_qty;
    extended_cost := round(v_unit_cost * v_qty, 4);

    RETURN NEXT;
  END LOOP;

  RETURN;
END;
$$;


--
-- Name: FUNCTION calculate_bom_price(p_parent_item_id uuid, p_organization_id uuid, p_width_m numeric, p_height_m numeric, p_area_sqm numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.calculate_bom_price(p_parent_item_id uuid, p_organization_id uuid, p_width_m numeric, p_height_m numeric, p_area_sqm numeric) IS 'Explode BOMComponents for a parent item and compute extended costs using get_catalog_item_unit_cost_norm(). Supports qty_type (per_width/per_height/per_area/per_unit).';


--
-- Name: calculate_configured_product_totals(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_cp RECORD;
  v_bom_instance_id uuid;
  v_part RECORD;

  v_roll_msrp_unit numeric := 0;
  v_roll_cost_unit numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_total_cost numeric := 0;

  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;
  v_qty numeric := 1;

  v_bom_msrp numeric := 0;
  v_bom_total_cost numeric := 0;
  v_part_msrp numeric;
  v_part_total_cost numeric;

  v_roll_plus_bom_total numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- Locate latest BOMInstance for this configured product (may be NULL for previews)
  SELECT bi.id INTO v_bom_instance_id
  FROM public."BOMInstances" bi
  WHERE bi.configured_product_id = p_configured_product_id
    AND bi.organization_id = v_cp.organization_id
    AND bi.deleted = false
    AND bi.archived = false
  ORDER BY bi.created_at DESC
  LIMIT 1;

  -- Roll totals
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT msrp, total_cost
      INTO v_roll_msrp_unit, v_roll_cost_unit
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = v_cp.organization_id
    LIMIT 1;

    IF v_roll_msrp_unit IS NULL THEN
      SELECT msrp, total_cost
        INTO v_roll_msrp_unit, v_roll_cost_unit
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_cp.roll_catalog_item_id
      LIMIT 1;
    END IF;

    SELECT ci.roll_pricing_mode, ci.measure_basis
      INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
    v_qty := COALESCE(v_cp.quantity, 1);

    -- Default behavior:
    -- - Fabrics priced per m²: roll_width (m) × height (m) × qty
    -- - Per linear meter: height (m) × qty
    -- - Per unit: qty
    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := v_qty;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m * v_qty;
    ELSE
      -- per_square_meter OR unknown: treat as area
      v_roll_factor := (v_roll_width_m * v_height_m) * v_qty;
    END IF;

    v_roll_msrp_total := COALESCE(v_roll_msrp_unit, 0) * v_roll_factor;
    v_roll_total_cost := COALESCE(v_roll_cost_unit, 0) * v_roll_factor;
  END IF;

  -- BOM totals (components). If no BOMInstance yet, BOM totals stay 0.
  IF v_bom_instance_id IS NOT NULL THEN
    FOR v_part IN
      SELECT bil.resolved_part_id, bil.qty
      FROM public."BOMInstanceLines" bil
      WHERE bil.bom_instance_id = v_bom_instance_id
        AND bil.deleted = false
        AND bil.archived = false
        AND bil.resolved_part_id IS NOT NULL
    LOOP
      SELECT msrp, total_cost
        INTO v_part_msrp, v_part_total_cost
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_part.resolved_part_id
        AND organization_id = v_cp.organization_id
      LIMIT 1;

      IF v_part_msrp IS NULL THEN
        SELECT msrp, total_cost
          INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_part.resolved_part_id
        LIMIT 1;
      END IF;

      v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * COALESCE(v_part.qty, 0));
      v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * COALESCE(v_part.qty, 0));
    END LOOP;
  END IF;

  v_roll_plus_bom_total := v_roll_msrp_total + v_bom_msrp;
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  v_labor_amount := v_roll_plus_bom_total * (COALESCE(v_cp.labor_pct, 0) / 100.0);
  v_total_msrp := v_roll_plus_bom_total + v_accessories_total + v_labor_amount;

  -- Persist back to ConfiguredProducts (expected by frontend snapshot flow)
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    roll_total_cost = v_roll_total_cost,
    bom_total = v_bom_msrp,
    bom_total_cost = v_bom_total_cost,
    roll_plus_bom_total = v_roll_plus_bom_total,
    labor_amount = v_labor_amount,
    total_msrp = v_total_msrp,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_msrp,
    'roll_plus_bom_total', v_roll_plus_bom_total,
    'labor_amount', v_labor_amount,
    'accessories_total', v_accessories_total,
    'total_msrp', v_total_msrp,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost,
    'total_cost', (v_roll_total_cost + v_bom_total_cost)
  );
END;
$$;


--
-- Name: can_read_company_portal_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_company_portal_user(p_portal_row_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
BEGIN
  IF public.is_portal_user_self(p_portal_row_id) THEN
    RETURN true;
  END IF;

  SELECT cpu.organization_id
    INTO v_org_id
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.id = p_portal_row_id
    AND cpu.deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN public.is_org_user_member(v_org_id);
END;
$$;


--
-- Name: FUNCTION can_read_company_portal_user(p_portal_row_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.can_read_company_portal_user(p_portal_row_id uuid) IS 'Readable if user is self or internal member of same organization.';


--
-- Name: catalogitems_set_to_base_factor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.catalogitems_set_to_base_factor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.sku := btrim(NEW.sku);

  IF NEW.measure_basis = 'linear' AND NEW.purchase_uom IN ('m','yd','ft') THEN
    IF NEW.purchase_uom = 'm'  THEN NEW.to_base_m_factor := 1.0; END IF;
    IF NEW.purchase_uom = 'yd' THEN NEW.to_base_m_factor := 0.9144; END IF;
    IF NEW.purchase_uom = 'ft' THEN NEW.to_base_m_factor := 0.3048; END IF;
  ELSE
    NEW.to_base_m_factor := NULL;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: catalogitems_sync_roll_dimensions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.catalogitems_sync_roll_dimensions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- ---- WIDTH -> meters ----
  IF NEW.roll_width_value IS NOT NULL AND NEW.roll_width_uom IS NOT NULL THEN
    NEW.roll_width_m :=
      CASE NEW.roll_width_uom
        WHEN 'm'  THEN NEW.roll_width_value
        WHEN 'yd' THEN NEW.roll_width_value * 0.9144
        WHEN 'ft' THEN NEW.roll_width_value * 0.3048
        WHEN 'in' THEN NEW.roll_width_value * 0.0254
      END;
  END IF;

  -- ---- LENGTH -> meters ----
  IF NEW.roll_length_value IS NOT NULL AND NEW.roll_length_uom IS NOT NULL THEN
    NEW.roll_length_m :=
      CASE NEW.roll_length_uom
        WHEN 'm'  THEN NEW.roll_length_value
        WHEN 'yd' THEN NEW.roll_length_value * 0.9144
        WHEN 'ft' THEN NEW.roll_length_value * 0.3048
        WHEN 'in' THEN NEW.roll_length_value * 0.0254
      END;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: catalogitemsmsrp_guard_not_null(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.catalogitemsmsrp_guard_not_null() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.dealer_price := COALESCE(NEW.dealer_price, 0);
  NEW.msrp         := COALESCE(NEW.msrp, 0);
  RETURN NEW;
END;
$$;


--
-- Name: clear_my_must_change_password(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_my_must_change_password() RETURNS TABLE(org_updated integer, portal_updated integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_org integer := 0;
  v_portal integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  UPDATE public."OrganizationUsers"
  SET must_change_password = false,
      updated_at = now()
  WHERE user_id = v_uid
    AND deleted = false
    AND must_change_password = true;

  GET DIAGNOSTICS v_org = ROW_COUNT;

  UPDATE public."CompanyPortalUsers"
  SET must_change_password = false,
      updated_at = now()
  WHERE user_id = v_uid
    AND deleted = false
    AND must_change_password = true;

  GET DIAGNOSTICS v_portal = ROW_COUNT;

  RETURN QUERY SELECT v_org, v_portal;
END;
$$;


--
-- Name: compute_quote_line_cost(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compute_quote_line_cost(p_quote_line_id uuid, p_options jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    v_quote_line_record RECORD;
    v_cost_settings_record RECORD;
    v_catalog_item_record RECORD;
    v_conversions_record RECORD;
    v_existing_cost_record RECORD;
    v_component_record RECORD;
    v_bom_component_record RECORD;
    v_category_tax_record RECORD;
    v_base_material_cost numeric(12,4) := 0;
    v_labor_cost numeric(12,4) := 0;
    v_shipping_cost numeric(12,4) := 0;
    v_import_tax_cost numeric(12,4) := 0;
    v_total_cost numeric(12,4) := 0;
    v_quote_line_cost_id uuid;
    v_reset_labor boolean := COALESCE((p_options->>'reset_labor')::boolean, false);
    v_reset_shipping boolean := COALESCE((p_options->>'reset_shipping')::boolean, false);
    v_reset_import_tax boolean := COALESCE((p_options->>'reset_import_tax')::boolean, false);
    v_labor_percentage numeric(8,4) := 10.0000;
    v_shipping_percentage numeric(8,4) := 15.0000;
    v_global_import_tax_percentage numeric(8,4) := 0;
    v_labor_source text := 'auto';
    v_shipping_source text := 'auto';
    v_import_tax_source text := 'auto';
    v_unit_cost numeric(12,4);
    v_extended_cost numeric(12,4);
    v_category_tax_percentage numeric(8,4);
    v_category_tax_amount numeric(12,4);
    v_has_bom boolean := false;
    v_category_cost_map jsonb := '{}'::jsonb;
    v_category_id uuid;
    v_category_extended_cost numeric(12,4);
    v_area_sqm numeric;
    v_category_key text;
    v_category_value text;
    v_breakdown_key text;
    v_breakdown_value text;
BEGIN
    -- Step 1: Load QuoteLine + organization_id + dimensions
    SELECT 
        ql.id,
        ql.organization_id,
        ql.quote_id,
        ql.catalog_item_id,
        ql.qty,
        ql.computed_qty,
        ql.width_m,
        ql.height_m,
        q.currency
    INTO v_quote_line_record
    FROM "QuoteLines" ql
    INNER JOIN "Quotes" q ON q.id = ql.quote_id
    WHERE ql.id = p_quote_line_id
    AND ql.deleted = false
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'QuoteLine with id % not found or deleted', p_quote_line_id;
    END IF;
    
    -- Step 2: Check if catalog_item_id has a BOM
    SELECT EXISTS (
        SELECT 1
        FROM "BOMComponents" bom
        WHERE bom.parent_item_id = v_quote_line_record.catalog_item_id
        AND bom.organization_id = v_quote_line_record.organization_id
        AND bom.deleted = false
    ) INTO v_has_bom;
    
    -- Step 3: Calculate base_material_cost
    IF v_has_bom THEN
        -- Use BOM calculation
        v_area_sqm := CASE 
            WHEN v_quote_line_record.width_m IS NOT NULL 
                 AND v_quote_line_record.height_m IS NOT NULL 
            THEN v_quote_line_record.width_m * v_quote_line_record.height_m
            ELSE NULL
        END;
        
        -- Loop through BOM components and calculate costs
        FOR v_bom_component_record IN
            SELECT * FROM calculate_bom_price(
                v_quote_line_record.catalog_item_id,
                v_quote_line_record.organization_id,
                v_quote_line_record.width_m,
                v_quote_line_record.height_m,
                v_area_sqm
            )
        LOOP
            v_base_material_cost := v_base_material_cost + v_bom_component_record.extended_cost;
            
            -- Group by category for Import Tax calculation
            IF v_bom_component_record.category_id IS NOT NULL THEN
                v_category_id := v_bom_component_record.category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + v_bom_component_record.extended_cost;
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
        
        -- Multiply by quantity
        v_base_material_cost := v_base_material_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
        
        -- Also multiply category costs by quantity
        v_category_cost_map := (
            SELECT jsonb_object_agg(key, value::numeric * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1))
            FROM jsonb_each_text(v_category_cost_map)
        );
        
    ELSE
        -- Use existing logic: QuoteLineComponents or catalog_item_id direct
        -- First, try QuoteLineComponents
        SELECT SUM(COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) * qlc.qty)
        INTO v_base_material_cost
        FROM "QuoteLineComponents" qlc
        LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
        WHERE qlc.quote_line_id = p_quote_line_id
        AND qlc.deleted = false;
        
        -- If no QuoteLineComponents, fall back to catalog_item_id direct with conversions
        IF v_base_material_cost IS NULL OR v_base_material_cost = 0 THEN
            -- Load catalog item + conversions
            SELECT 
                ci.id,
                ci.cost_exw,
                ci.is_roll,
                ci.roll_pricing_mode,
                ci.measure_basis,
                ci.unit_of_measure,
                ci.category_id,
                conv.cost_exw_per_m,
                conv.cost_exw_per_m2,
                conv.cost_exw_per_ea
            INTO v_catalog_item_record
            FROM "CatalogItems" ci
            LEFT JOIN "CatalogItemConversions" conv 
                ON conv.catalog_item_id = ci.id 
                AND conv.organization_id = ci.organization_id
            WHERE ci.id = v_quote_line_record.catalog_item_id
            AND ci.is_active = true;
            
            IF FOUND THEN
                -- Determine which conversion to use based on item type
                
                -- ROLLS: Use roll_pricing_mode
                IF v_catalog_item_record.is_roll = true AND v_catalog_item_record.roll_pricing_mode IS NOT NULL THEN
                    
                    IF v_catalog_item_record.roll_pricing_mode = 'per_linear_meter' THEN
                        -- Use $/m * computed_qty (assuming computed_qty is in meters)
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                        
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_square_meter' THEN
                        -- Use $/m² * computed_qty (assuming computed_qty is in m²)
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                        
                    ELSIF v_catalog_item_record.roll_pricing_mode = 'per_unit' THEN
                        -- Use $/ea * qty (whole rolls)
                        v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                        v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                        
                    ELSE
                        -- Fallback: use cost_exw direct (shouldn't happen)
                        v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    END IF;
                
                -- NON-ROLLS: Use measure_basis
                ELSIF v_catalog_item_record.measure_basis = 'linear' THEN
                    -- Linear items (tubes, profiles, tracks, headbox): $/m
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    
                ELSIF v_catalog_item_record.measure_basis = 'area' THEN
                    -- Area items (non-roll): $/m²
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_m2, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                    
                ELSIF v_catalog_item_record.measure_basis = 'unit' THEN
                    -- Unit items (motors, accessories, pack/set): $/ea
                    v_unit_cost := COALESCE(v_catalog_item_record.cost_exw_per_ea, v_catalog_item_record.cost_exw, 0);
                    v_base_material_cost := v_unit_cost * GREATEST(v_quote_line_record.qty, 1);
                    
                ELSE
                    -- Fallback for legacy data without conversions
                    v_base_material_cost := COALESCE(v_catalog_item_record.cost_exw, 0) * GREATEST(v_quote_line_record.computed_qty, v_quote_line_record.qty, 1);
                END IF;
                
            ELSE
                -- Item not found or inactive
                v_base_material_cost := 0;
            END IF;
        END IF;
        
        -- Group QuoteLineComponents by category for Import Tax
        FOR v_component_record IN
            SELECT 
                qlc.catalog_item_id,
                COALESCE(qlc.unit_cost_exw, ci.cost_exw, 0) as unit_cost,
                qlc.qty,
                ci.item_category_id,
                ic.name as category_name
            FROM "QuoteLineComponents" qlc
            LEFT JOIN "CatalogItems" ci ON qlc.catalog_item_id = ci.id
            LEFT JOIN "ItemCategories" ic ON ci.item_category_id = ic.id
            WHERE qlc.quote_line_id = p_quote_line_id
            AND qlc.deleted = false
        LOOP
            IF v_component_record.item_category_id IS NOT NULL THEN
                v_category_id := v_component_record.item_category_id;
                v_category_extended_cost := COALESCE((v_category_cost_map->>v_category_id::text)::numeric, 0);
                v_category_extended_cost := v_category_extended_cost + (v_component_record.unit_cost * v_component_record.qty);
                v_category_cost_map := jsonb_set(
                    v_category_cost_map,
                    ARRAY[v_category_id::text],
                    to_jsonb(v_category_extended_cost)
                );
            END IF;
        END LOOP;
    END IF;
    
    -- Step 4: Load CostSettings for organization
    SELECT 
        id,
        currency_code,
        labor_percentage,
        shipping_percentage,
        import_tax_percent
    INTO v_cost_settings_record
    FROM "CostSettings"
    WHERE organization_id = v_quote_line_record.organization_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        v_labor_percentage := COALESCE(v_cost_settings_record.labor_percentage, 10.0000);
        v_shipping_percentage := COALESCE(v_cost_settings_record.shipping_percentage, 15.0000);
        v_global_import_tax_percentage := COALESCE(v_cost_settings_record.import_tax_percent, 0);
    END IF;
    
    -- Step 5: Check for existing QuoteLineCosts to preserve manual overrides
    SELECT * INTO v_existing_cost_record
    FROM "QuoteLineCosts"
    WHERE quote_line_id = p_quote_line_id
    AND deleted = false
    LIMIT 1;
    
    -- Step 6: Calculate labor and shipping costs
    IF v_existing_cost_record.id IS NOT NULL THEN
        -- Preserve manual overrides unless reset flags are set
        IF v_existing_cost_record.labor_source = 'manual' AND NOT v_reset_labor THEN
            v_labor_cost := v_existing_cost_record.labor_cost;
            v_labor_source := 'manual';
        ELSE
            v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
            v_labor_source := 'auto';
        END IF;
        
        IF v_existing_cost_record.shipping_source = 'manual' AND NOT v_reset_shipping THEN
            v_shipping_cost := v_existing_cost_record.shipping_cost;
            v_shipping_source := 'manual';
        ELSE
            v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
            v_shipping_source := 'auto';
        END IF;
    ELSE
        -- New calculation
        v_labor_cost := v_base_material_cost * (v_labor_percentage / 100.0);
        v_shipping_cost := v_base_material_cost * (v_shipping_percentage / 100.0);
    END IF;
    
    -- Step 7: Calculate Import Tax by category
    IF v_existing_cost_record.id IS NOT NULL 
       AND v_existing_cost_record.import_tax_source = 'manual' 
       AND NOT v_reset_import_tax THEN
        -- Preserve manual override
        v_import_tax_cost := v_existing_cost_record.import_tax_cost;
        v_import_tax_source := 'manual';
    ELSE
        -- Calculate import tax from categories
        v_import_tax_cost := 0;
        
        -- Loop through categories and apply category-specific or global tax
        FOR v_category_key, v_category_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_category_key::uuid;
            v_category_extended_cost := v_category_value::numeric;
            
            -- Try to get category-specific import tax rule
            SELECT import_tax_percentage
            INTO v_category_tax_percentage
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND active = true
            AND deleted = false
            LIMIT 1;
            
            -- If no category rule, use global default
            IF v_category_tax_percentage IS NULL THEN
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            -- Calculate tax for this category
            v_category_tax_amount := v_category_extended_cost * (v_category_tax_percentage / 100.0);
            v_import_tax_cost := v_import_tax_cost + v_category_tax_amount;
        END LOOP;
        
        v_import_tax_source := 'auto';
    END IF;
    
    -- Step 8: Calculate total_cost
    v_total_cost := v_base_material_cost + 
                    v_labor_cost + 
                    v_shipping_cost + 
                    v_import_tax_cost;
    
    -- Step 9: Upsert into QuoteLineCosts
    INSERT INTO "QuoteLineCosts" (
        organization_id,
        quote_id,
        quote_line_id,
        currency_code,
        base_material_cost,
        labor_cost,
        shipping_cost,
        import_tax_cost,
        labor_source,
        shipping_source,
        import_tax_source,
        total_cost
    )
    VALUES (
        v_quote_line_record.organization_id,
        v_quote_line_record.quote_id,
        p_quote_line_id,
        v_quote_line_record.currency,
        v_base_material_cost,
        v_labor_cost,
        v_shipping_cost,
        v_import_tax_cost,
        v_labor_source,
        v_shipping_source,
        v_import_tax_source,
        v_total_cost
    )
    ON CONFLICT (quote_line_id) 
    DO UPDATE SET
        base_material_cost = EXCLUDED.base_material_cost,
        labor_cost = EXCLUDED.labor_cost,
        shipping_cost = EXCLUDED.shipping_cost,
        import_tax_cost = EXCLUDED.import_tax_cost,
        labor_source = EXCLUDED.labor_source,
        shipping_source = EXCLUDED.shipping_source,
        import_tax_source = EXCLUDED.import_tax_source,
        total_cost = EXCLUDED.total_cost,
        updated_at = now()
    RETURNING id INTO v_quote_line_cost_id;
    
    -- Step 10: Update QuoteLineImportTaxBreakdown (if using BOM)
    IF v_has_bom THEN
        -- Delete existing breakdown
        DELETE FROM "QuoteLineImportTaxBreakdown"
        WHERE quote_line_id = p_quote_line_id
        AND deleted = false;
        
        -- Insert new breakdown by category
        FOR v_breakdown_key, v_breakdown_value IN
            SELECT key, value
            FROM jsonb_each_text(v_category_cost_map)
        LOOP
            v_category_id := v_breakdown_key::uuid;
            v_category_extended_cost := v_breakdown_value::numeric;
            
            -- Get category name
            SELECT name INTO v_category_tax_record.category_name
            FROM "ItemCategories"
            WHERE id = v_category_id
            AND deleted = false
            LIMIT 1;
            
            -- Get category-specific or global tax percentage
            SELECT import_tax_percentage
            INTO v_category_tax_percentage
            FROM "ImportTaxRules"
            WHERE organization_id = v_quote_line_record.organization_id
            AND category_id = v_category_id
            AND active = true
            AND deleted = false
            LIMIT 1;
            
            IF v_category_tax_percentage IS NULL THEN
                v_category_tax_percentage := v_global_import_tax_percentage;
            END IF;
            
            -- Insert breakdown record
            INSERT INTO "QuoteLineImportTaxBreakdown" (
                organization_id,
                quote_line_id,
                category_id,
                category_name,
                extended_cost,
                import_tax_percentage,
                import_tax_amount
            )
            VALUES (
                v_quote_line_record.organization_id,
                p_quote_line_id,
                v_category_id,
                COALESCE(v_category_tax_record.category_name, 'Unknown'),
                v_category_extended_cost,
                v_category_tax_percentage,
                v_category_extended_cost * (v_category_tax_percentage / 100.0)
            );
        END LOOP;
    END IF;
    
    RETURN v_quote_line_cost_id;
END;
$_$;


--
-- Name: FUNCTION compute_quote_line_cost(p_quote_line_id uuid, p_options jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.compute_quote_line_cost(p_quote_line_id uuid, p_options jsonb) IS 'Calculates quote line costs with CatalogItemConversions support. Uses cost_exw_per_m/m2/ea based on roll_pricing_mode and measure_basis. Supports pack/set via cost_exw_per_ea. Maintains backward compatibility.';


--
-- Name: compute_roll_conversions(numeric, text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compute_roll_conversions(p_cost_exw numeric, p_uom text, p_roll_width numeric) RETURNS TABLE(cost_exw_per_m numeric, cost_exw_per_m2 numeric)
    LANGUAGE sql IMMUTABLE
    AS $$
  with base as (
    select public.cost_to_per_m(p_cost_exw, p_uom) as per_m
  )
  select
    per_m,
    case
      when per_m is null then null
      when p_roll_width is null or p_roll_width <= 0 then null
      else (per_m / p_roll_width)
    end
  from base;
$$;


--
-- Name: cost_to_per_m(numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cost_to_per_m(p_cost numeric, p_uom text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  select
    case
      when p_cost is null then null
      when lower(coalesce(p_uom,'')) in ('yd','yard','yards') then (p_cost / 0.9144)
      when lower(coalesce(p_uom,'')) in ('m','meter','meters','mt') then p_cost
      else null
    end;
$$;


--
-- Name: create_bom_instance_for_configured_product(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_bom_instance_for_configured_product(p_org_id uuid, p_quote_line_id uuid, p_configured_product_id uuid, p_product_type_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_bom_instance_id uuid;
    v_configured_product RECORD;
BEGIN
    -- ✅ VALIDACIÓN: quote_line_id es REQUERIDO
    IF p_quote_line_id IS NULL THEN
        RAISE EXCEPTION 'quote_line_id is required to create BOMInstance';
    END IF;

    -- Validar que ConfiguredProduct existe
    SELECT * INTO v_configured_product
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_configured_product.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct % not found or is deleted', p_configured_product_id;
    END IF;

    -- Verificar si ya existe BOMInstance para este quote_line_id
    SELECT id INTO v_bom_instance_id
    FROM public."BOMInstances"
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false
    LIMIT 1;

    IF v_bom_instance_id IS NOT NULL THEN
        -- Ya existe, retornar
        RETURN v_bom_instance_id;
    END IF;

    -- Crear BOMInstance usando generate_bom_from_slots_for_configured_product
    -- ahora con quote_line_id
    v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(
        p_org_id,
        p_configured_product_id,
        p_product_type_id,
        p_quote_line_id  -- ✅ Pasar quote_line_id
    );
    
    RETURN v_bom_instance_id;
END;
$$;


--
-- Name: FUNCTION create_bom_instance_for_configured_product(p_org_id uuid, p_quote_line_id uuid, p_configured_product_id uuid, p_product_type_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_bom_instance_for_configured_product(p_org_id uuid, p_quote_line_id uuid, p_configured_product_id uuid, p_product_type_id uuid) IS 'Crea BOMInstance para un ConfiguredProduct existente cuando ya se tiene quote_line_id.
✅ REQUIERE: quote_line_id NO NULL (valida constraint).
Se usa después de crear QuoteLine para crear el BOMInstance asociado.';


--
-- Name: create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_configured_product_and_bom_preview(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb, p_quote_id uuid DEFAULT NULL::uuid, p_quote_line_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id uuid;
  v_bom_instance_id uuid;
  v_totals jsonb;
  v_hardware_color text;
  v_fabric_item_id uuid;
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_quantity numeric(12,4);
  v_roll_sku text;
  v_roll_collection_name text;
  v_roll_variant_name text;
  v_roll_width numeric(12,4);
BEGIN
  v_bom_template_id := public.select_best_bom_template_for_configured_product(
    p_org_id,
    p_product_type_id,
    p_config_snapshot
  );

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', p_org_id, p_product_type_id;
  END IF;

  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor',
    p_config_snapshot->>'operatingSystemColor'
  );

  v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'fabric_catalog_item_id')::uuid;
  END IF;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  END IF;

  v_width_mm := (p_config_snapshot->>'width_mm')::numeric;
  IF v_width_mm IS NULL THEN
    v_width_mm := COALESCE((p_config_snapshot->>'width_m')::numeric, 0) * 1000;
  END IF;

  v_height_mm := (p_config_snapshot->>'height_mm')::numeric;
  IF v_height_mm IS NULL THEN
    v_height_mm := COALESCE((p_config_snapshot->>'height_m')::numeric, 0) * 1000;
  END IF;

  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric, 1);

  -- Roll info (prefer normalized roll_width_m)
  IF v_fabric_item_id IS NOT NULL THEN
    SELECT
      ci.sku,
      ci.collection_name,
      ci.variant_name,
      COALESCE(ci.roll_width_m, ci.roll_width)
    INTO
      v_roll_sku,
      v_roll_collection_name,
      v_roll_variant_name,
      v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.is_roll = true
      AND ci.roll_type = 'fabric'
      AND ci.is_active = true
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts"(
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
    bottom_bar_item_id,
    bottom_bar_sku,
    headbox_item_id,
    headbox_sku,
    side_channel_item_id,
    side_channel_sku,
    bottom_channel_item_id,
    bottom_channel_sku,
    motor_item_id,
    motor_sku,
    drive_item_id,
    drive_sku,
    tube_item_id,
    tube_sku,
    operating_type,
    config_snapshot
  ) VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
    (p_config_snapshot->>'bottom_bar_item_id')::uuid,
    p_config_snapshot->>'bottom_bar_sku',
    (p_config_snapshot->>'headbox_item_id')::uuid,
    p_config_snapshot->>'headbox_sku',
    (p_config_snapshot->>'side_channel_item_id')::uuid,
    p_config_snapshot->>'side_channel_sku',
    (p_config_snapshot->>'bottom_channel_item_id')::uuid,
    p_config_snapshot->>'bottom_channel_sku',
    (p_config_snapshot->>'motor_item_id')::uuid,
    p_config_snapshot->>'motor_sku',
    (p_config_snapshot->>'drive_item_id')::uuid,
    p_config_snapshot->>'drive_sku',
    (p_config_snapshot->>'tube_item_id')::uuid,
    p_config_snapshot->>'tube_sku',
    COALESCE(
      p_config_snapshot->>'operating_type',
      p_config_snapshot->>'operation_type',
      p_config_snapshot->>'drive_type'
    ),
    p_config_snapshot
  )
  RETURNING id INTO v_configured_product_id;

  v_bom_instance_id := NULL;
  v_totals := public.calculate_configured_product_totals(v_configured_product_id);

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals
  );
END;
$$;


--
-- Name: FUNCTION create_configured_product_and_bom_preview(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb, p_quote_id uuid, p_quote_line_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb, p_quote_id uuid, p_quote_line_id uuid) IS 'Crea ConfiguredProduct y opcionalmente BOMInstance.
✅ CAMBIO: Solo crea BOMInstance si se proporciona quote_line_id.
Si quote_line_id es NULL, NO crea BOMInstance (se creará después cuando se tenga QuoteLine).
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';


--
-- Name: create_quote_line_cost_snapshot(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_quote_line_cost_snapshot(p_quote_line_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
  v_org_id uuid;
  v_quote_id uuid;
  v_configured_product_id uuid;
  v_inserted int := 0;
begin
  select ql.organization_id, ql.quote_id, ql.configured_product_id
    into v_org_id, v_quote_id, v_configured_product_id
  from public."QuoteLines" ql
  where ql.id = p_quote_line_id;

  if v_org_id is null then
    raise exception 'QuoteLine not found: %', p_quote_line_id;
  end if;

  if v_configured_product_id is null then
    raise exception 'QuoteLine % has no configured_product_id set', p_quote_line_id;
  end if;

  delete from public."QuoteLineCostLines"
  where quote_line_id = p_quote_line_id;

  insert into public."QuoteLineCostLines" (
    organization_id,
    quote_id,
    quote_line_id,
    "group",
    role,
    sort_order,
    catalog_item_id,
    sku,
    name,
    uom,
    qty,
    unit_cost_exw,
    shipping_unit_cost,
    import_tax_unit_cost,
    landed_unit_cost,
    msrp_unit,
    msrp_line,
    rule_note
  )
  select
    cpl.organization_id,
    v_quote_id,
    p_quote_line_id,
    cpl."group",
    cpl.role,
    cpl.sort_order,
    cpl.catalog_item_id,
    cpl.sku,
    cpl.name,
    cpl.uom,
    cpl.qty,
    cpl.unit_cost_exw,
    cpl.shipping_unit_cost,
    cpl.import_tax_unit_cost,
    cpl.landed_unit_cost,
    cpl.msrp_unit,
    cpl.msrp_line,
    cpl.rule_note
  from public."ConfiguredProductLines" cpl
  where cpl.organization_id = v_org_id
    and cpl.configured_product_id = v_configured_product_id;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;


--
-- Name: current_auth_email(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_auth_email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT lower(nullif(trim(auth.jwt() ->> 'email'), ''));
$$;


--
-- Name: delete_company_portal_user(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_company_portal_user(p_portal_user_id uuid, p_organization_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_deleted_count int;
BEGIN
  -- Soft delete: mark as deleted and disabled
  UPDATE public."CompanyPortalUsers"
  SET 
    deleted = true,
    status = 'disabled',
    updated_at = now()
  WHERE 
    id = p_portal_user_id
    AND organization_id = p_organization_id
    AND deleted = false;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  IF v_deleted_count = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Portal user not found or already deleted'
    );
  END IF;
  
  RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: FUNCTION delete_company_portal_user(p_portal_user_id uuid, p_organization_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_company_portal_user(p_portal_user_id uuid, p_organization_id uuid) IS 'Soft delete a company portal user. Marks deleted=true and status=disabled. Bypasses RLS. Only callable by authenticated users with proper organization membership.';


--
-- Name: delete_organization_user(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_organization_user(p_org_user_id uuid, p_organization_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_user_role text;
  v_result json;
BEGIN
  -- 1) Verify user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2) Check if user is superadmin or admin in the organization
  SELECT ou.role::text INTO v_user_role
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = auth.uid()
    AND ou.organization_id = p_organization_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'User not found in organization or not active';
  END IF;

  IF v_user_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only superadmins and admins can delete users';
  END IF;

  -- 3) Verify the user to delete exists and belongs to the organization
  IF NOT EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND organization_id = p_organization_id
      AND deleted = false
  ) THEN
    RAISE EXCEPTION 'User not found in organization or already deleted';
  END IF;

  -- 4) Prevent self-deletion
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND user_id = auth.uid()
      AND organization_id = p_organization_id
  ) THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- 4.5) Prevent deleting the last active superadmin
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" target
    WHERE target.id = p_org_user_id
      AND target.organization_id = p_organization_id
      AND target.deleted = false
      AND target.status = 'active'
      AND target.role::text = 'superadmin'
  ) THEN
    IF (
      SELECT count(*)
      FROM public."OrganizationUsers" su
      WHERE su.organization_id = p_organization_id
        AND su.deleted = false
        AND su.status = 'active'
        AND su.role::text = 'superadmin'
    ) <= 1 THEN
      RAISE EXCEPTION 'Cannot delete the last active superadmin';
    END IF;
  END IF;

  -- 5) Perform soft delete
  UPDATE public."OrganizationUsers"
  SET 
    deleted = true,
    updated_at = NOW()
  WHERE id = p_org_user_id
    AND organization_id = p_organization_id
    AND deleted = false;

  -- 6) Return success
  SELECT json_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'id', p_org_user_id
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'id', p_org_user_id
    );
END;
$$;


--
-- Name: FUNCTION delete_organization_user(p_org_user_id uuid, p_organization_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_organization_user(p_org_user_id uuid, p_organization_id uuid) IS 'Soft delete an organization user. Only superadmins/admins can call. Uses SECURITY DEFINER to bypass RLS. Prevents self-deletion and last-superadmin deletion.';


--
-- Name: directorycontacts_fill_org_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.directorycontacts_fill_org_id() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Si ya viene, listo
  IF NEW.organization_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Si hay company_id, derivar org_id desde Companies
  IF NEW.company_id IS NOT NULL THEN
    SELECT c.organization_id
      INTO NEW.organization_id
    FROM public."Companies" c
    WHERE c.id = NEW.company_id
      AND c.deleted = false
    LIMIT 1;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: enforce_active_item_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_active_item_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.item_role IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public."CatalogItemRoles" r
      WHERE r.role_code = NEW.item_role
        AND r.active = true
    ) THEN
      RAISE EXCEPTION 'item_role "%" no está activo en CatalogItemRoles', NEW.item_role;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: enforce_mo_company_matches_salesorder(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_mo_company_matches_salesorder() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_so_company uuid;
begin
  if new.sales_order_id is null then
    raise exception 'ManufacturingOrders.sales_order_id is required';
  end if;

  select so.company_id
    into v_so_company
  from public."SalesOrders" so
  where so.id = new.sales_order_id;

  -- Si SO aún no tiene company_id, no bloqueamos (MVP).
  if v_so_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_so_company;
  end if;

  if new.company_id <> v_so_company then
    raise exception 'ManufacturingOrders.company_id must match SalesOrders.company_id';
  end if;

  return new;
end;
$$;


--
-- Name: enforce_orderlist_company_matches_salesorder(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_orderlist_company_matches_salesorder() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_so_company uuid;
begin
  -- si no tienes sales_order_id en OrderList, este trigger no sirve.
  if new.sales_order_id is null then
    return new;
  end if;

  select so.company_id
    into v_so_company
  from public."SalesOrders" so
  where so.id = new.sales_order_id;

  if v_so_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_so_company;
  end if;

  if new.company_id <> v_so_company then
    raise exception 'OrderList.company_id must match SalesOrders.company_id';
  end if;

  return new;
end;
$$;


--
-- Name: enforce_salesorders_company_matches_quote(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_salesorders_company_matches_quote() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_quote_company uuid;
begin
  if new.quote_id is null then
    raise exception 'SalesOrders.quote_id is required';
  end if;

  select q.company_id
    into v_quote_company
  from public."Quotes" q
  where q.id = new.quote_id;

  -- Si el quote aún no tiene company_id, no bloqueamos (MVP).
  if v_quote_company is null then
    return new;
  end if;

  if new.company_id is null then
    new.company_id := v_quote_company;
  end if;

  if new.company_id <> v_quote_company then
    raise exception 'SalesOrders.company_id must match Quotes.company_id';
  end if;

  return new;
end;
$$;


--
-- Name: fill_msrp_item_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fill_msrp_item_identity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_sku text;
  v_name text;
  v_collection_name text;
  v_variant_name text;
  v_unit_of_measure text;
BEGIN
  IF NEW.sku IS NULL OR NEW.name IS NULL OR NEW.collection_name IS NULL OR NEW.variant_name IS NULL OR NEW.unit_of_measure IS NULL
  THEN
    SELECT ci.sku, ci.name, ci.collection_name, ci.variant_name, ci.unit_of_measure
      INTO v_sku, v_name, v_collection_name, v_variant_name, v_unit_of_measure
      FROM public."CatalogItems" ci
      WHERE ci.id = NEW.catalog_item_id;

    IF NEW.sku IS NULL THEN NEW.sku := v_sku; END IF;
    IF NEW.name IS NULL THEN NEW.name := v_name; END IF;
    IF NEW.collection_name IS NULL THEN NEW.collection_name := v_collection_name; END IF;
    IF NEW.variant_name IS NULL THEN NEW.variant_name := v_variant_name; END IF;
    IF NEW.unit_of_measure IS NULL THEN NEW.unit_of_measure := v_unit_of_measure; END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: fill_msrp_sku_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fill_msrp_sku_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_sku text;
  v_name text;
begin
  -- If already present, keep it (but we can also force overwrite; here we fill if null)
  if new.sku is null or new.name is null then
    select ci.sku, ci.name
      into v_sku, v_name
    from public."CatalogItems" ci
    where ci.id = new.catalog_item_id;

    if new.sku is null then new.sku := v_sku; end if;
    if new.name is null then new.name := v_name; end if;
  end if;

  return new;
end;
$$;


--
-- Name: generate_bom_from_slots(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_bom_from_slots(p_org_id uuid, p_quote_line_id uuid, p_product_type_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_ql RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config jsonb;
BEGIN
    SELECT * INTO v_ql
    FROM public."QuoteLines"
    WHERE id = p_quote_line_id
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_ql.id IS NULL THEN
        RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
    END IF;

    v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
    v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', 
            p_org_id, p_product_type_id;
    END IF;

    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND quote_line_id = p_quote_line_id
        AND deleted = false;

    INSERT INTO public."BOMInstances"(
        organization_id, 
        quote_line_id, 
        bom_template_id,
        configured_product_id
    )
    VALUES (p_org_id, p_quote_line_id, v_template_id, NULL)
    RETURNING id INTO v_instance_id;

    v_width_mm := COALESCE(v_ql.width_m, 0) * 1000;
    v_height_mm := COALESCE(v_ql.height_m, 0) * 1000;

    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        v_resolved_item := v_slot.catalog_item_id;

        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        IF v_has_component_rules THEN
            IF v_component.qty_type = 'fixed' THEN
                v_qty := v_component.qty_value;
            ELSIF v_component.qty_type = 'per_width' THEN
                v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_height' THEN
                v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_area' THEN
                v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
            ELSE
                v_qty := v_component.qty_value;
            END IF;

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
            INSERT INTO public."BOMInstanceLines"(
                organization_id,
                bom_instance_id,
                resolved_part_id,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                deleted
            ) VALUES (
                p_org_id,
                v_instance_id,
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        END IF;

        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                WITH bom_override AS (
                    SELECT 
                        bc.component_item_id AS child_item_id,
                        bc.component_role AS child_role,
                        bc.qty_value AS qty,
                        bc.uom,
                        COALESCE(ci.cost_exw, 0) AS child_cost
                    FROM public."BOMComponents" bc
                    JOIN public."CatalogItems" ci ON ci.id = bc.component_item_id
                    WHERE bc.organization_id = p_org_id
                        AND bc.bom_template_id = v_template_id
                        AND bc.parent_item_id = v_resolved_item
                        AND bc.component_scope = 'bom'
                        AND bc.deleted = false
                        AND bc.archived = false
                ),
                global_defaults AS (
                    SELECT 
                        cic.child_item_id,
                        cic.child_role,
                        cic.qty,
                        cic.uom,
                        COALESCE(ci.cost_exw, 0) AS child_cost
                    FROM public."CatalogItemComponents" cic
                    JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                    WHERE cic.organization_id = p_org_id
                        AND cic.parent_item_id = v_resolved_item
                        AND cic.deleted = false
                )
                SELECT * FROM bom_override
                UNION ALL
                SELECT * FROM global_defaults
                WHERE NOT EXISTS (SELECT 1 FROM bom_override)
            LOOP
                INSERT INTO public."BOMInstanceLines"(
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    part_role,
                    qty,
                    uom,
                    unit_cost_exw,
                    deleted
                ) VALUES (
                    p_org_id,
                    v_instance_id,
                    v_child.child_item_id,
                    v_child.child_role,
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;


--
-- Name: FUNCTION generate_bom_from_slots(p_org_id uuid, p_quote_line_id uuid, p_product_type_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.generate_bom_from_slots(p_org_id uuid, p_quote_line_id uuid, p_product_type_id uuid) IS 'Genera BOMInstance desde BOMTemplateSlots para QuoteLine.
✅ CORREGIDO: Usa BOMInstances y BOMInstanceLines (mayúsculas).';


--
-- Name: generate_bom_from_slots_for_configured_product(uuid, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_bom_from_slots_for_configured_product(p_org_id uuid, p_configured_product_id uuid, p_product_type_id uuid, p_quote_line_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_template_id uuid;
    v_instance_id uuid;
    v_cp RECORD;
    v_slot RECORD;
    v_component RECORD;
    v_resolved_item uuid;
    v_qty numeric(12,4);
    v_width_mm numeric(12,4);
    v_height_mm numeric(12,4);
    v_unit_cost numeric(12,4);
    v_unit_uom text;
    v_child RECORD;
    v_has_component_rules boolean;
    v_config_snapshot jsonb;
    v_selected_item_id uuid;
    v_selected_sku text;
    v_mounting_clip_qty numeric(12,4);
    v_mounting_clip_rule RECORD;
BEGIN
    -- 1. Obtener ConfiguredProduct
    SELECT * INTO v_cp
    FROM public."ConfiguredProducts"
    WHERE id = p_configured_product_id 
        AND organization_id = p_org_id
        AND deleted = false;

    IF v_cp.id IS NULL THEN
        RAISE EXCEPTION 'ConfiguredProduct not found %', p_configured_product_id;
    END IF;

    v_config_snapshot := v_cp.config_snapshot;
    v_template_id := v_cp.bom_template_id;

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'BOMTemplate not set in ConfiguredProduct %', p_configured_product_id;
    END IF;

    -- ✅ CAMBIO CRÍTICO: Solo crear BOMInstance si se proporciona quote_line_id
    IF p_quote_line_id IS NULL THEN
        -- NO crear BOMInstance sin quote_line_id
        RAISE NOTICE 'BOMInstance NO creado: quote_line_id es NULL. Retornando NULL.';
        RETURN NULL;
    END IF;

    -- 2. Soft-delete instancias previas (idempotencia)
    UPDATE public."BOMInstances"
        SET deleted = true
    WHERE organization_id = p_org_id
        AND (
            (configured_product_id = p_configured_product_id AND configured_product_id IS NOT NULL)
            OR (quote_line_id = p_quote_line_id AND quote_line_id IS NOT NULL)
        )
        AND deleted = false;

    -- 3. Crear nueva instancia con quote_line_id
    BEGIN
        INSERT INTO public."BOMInstances"(
            organization_id, 
            quote_line_id,  -- ✅ REQUERIDO
            configured_product_id, 
            bom_template_id
        )
        VALUES (p_org_id, p_quote_line_id, p_configured_product_id, v_template_id)
        RETURNING id INTO v_instance_id;

        IF v_instance_id IS NULL THEN
            RAISE EXCEPTION 'Failed to create BOMInstance: RETURNING id returned NULL. QuoteLine: %, ConfiguredProduct: %, Template: %', 
                p_quote_line_id, p_configured_product_id, v_template_id;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create BOMInstance for QuoteLine % and ConfiguredProduct %: %. Check constraints and schema.', 
                p_quote_line_id, p_configured_product_id, SQLERRM;
    END;

    v_width_mm := COALESCE(v_cp.width_mm, 0);
    v_height_mm := COALESCE(v_cp.height_mm, 0);

    -- 4. Iterar BOMTemplateSlots (PADRES) - misma lógica que antes
    FOR v_slot IN
        SELECT *
        FROM public."BOMTemplateSlots"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
        ORDER BY item_role ASC
    LOOP
        -- PASO 1: Resolver SKU PADRE desde config_snapshot
        v_selected_item_id := NULL;
        v_selected_sku := NULL;
        
        CASE v_slot.item_role
            WHEN 'bottom_bar' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_bar_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_bar_sku';
            WHEN 'headbox' THEN
                v_selected_item_id := (v_config_snapshot->>'headbox_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'headbox_sku';
            WHEN 'side_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'side_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'side_channel_sku';
            WHEN 'bottom_channel' THEN
                v_selected_item_id := (v_config_snapshot->>'bottom_channel_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'bottom_channel_sku';
            WHEN 'motor' THEN
                v_selected_item_id := (v_config_snapshot->>'motor_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'motor_sku';
            WHEN 'drive' THEN
                v_selected_item_id := (v_config_snapshot->>'drive_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'drive_sku';
            WHEN 'tube' THEN
                v_selected_item_id := (v_config_snapshot->>'tube_item_id')::uuid;
                v_selected_sku := v_config_snapshot->>'tube_sku';
            ELSE
                v_selected_item_id := (v_config_snapshot->>(v_slot.item_role || '_item_id'))::uuid;
                v_selected_sku := v_config_snapshot->>(v_slot.item_role || '_sku');
        END CASE;

        -- Resolver item
        IF v_selected_sku IS NOT NULL AND v_slot.catalog_item_id IS NOT NULL THEN
            SELECT ci.sku INTO v_resolved_item
            FROM public."CatalogItems" ci
            WHERE ci.id = v_slot.catalog_item_id
                AND TRIM(ci.sku) = TRIM(v_selected_sku);
                
            IF v_resolved_item IS NOT NULL THEN
                v_resolved_item := v_slot.catalog_item_id;
            END IF;
        ELSIF v_selected_item_id IS NOT NULL THEN
            v_resolved_item := v_selected_item_id;
        ELSE
            v_resolved_item := v_slot.catalog_item_id;
        END IF;

        -- PASO 2: Obtener reglas de qty/corte desde BOMComponents
        SELECT * INTO v_component
        FROM public."BOMComponents"
        WHERE organization_id = p_org_id
            AND bom_template_id = v_template_id
            AND component_role = v_slot.item_role
            AND deleted = false
        LIMIT 1;

        v_has_component_rules := (v_component.id IS NOT NULL);

        -- PASO 3: Calcular cantidad
        IF v_has_component_rules THEN
            IF v_component.qty_type = 'fixed' THEN
                v_qty := v_component.qty_value;
            ELSIF v_component.qty_type = 'per_width' THEN
                v_qty := ((v_width_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_height' THEN
                v_qty := ((v_height_mm + COALESCE(v_component.qty_delta_mm, 0)) / 1000.0) * v_component.qty_value;
            ELSIF v_component.qty_type = 'per_area' THEN
                v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_component.qty_value;
            ELSE
                v_qty := v_component.qty_value;
            END IF;

            IF v_component.waste_pct IS NOT NULL AND v_component.waste_pct > 0 THEN
                v_qty := v_qty * (1 + v_component.waste_pct);
            END IF;
        ELSE
            v_qty := v_slot.qty;
        END IF;

        -- PASO 4: Obtener costo y UOM
        IF v_resolved_item IS NOT NULL THEN
            SELECT ci.cost_exw, ci.unit_of_measure INTO v_unit_cost, v_unit_uom
            FROM public."CatalogItems" ci
            WHERE ci.id = v_resolved_item;
            
            v_unit_cost := COALESCE(v_unit_cost, 0);
            v_unit_uom := COALESCE(v_unit_uom, 'ea');
        ELSE
            v_unit_cost := 0;
            v_unit_uom := 'ea';
        END IF;

        -- PASO 5: Insertar línea del BOM (PADRE)
        IF v_resolved_item IS NOT NULL AND v_qty > 0 THEN
            INSERT INTO public."BOMInstanceLines"(
                organization_id,
                bom_instance_id,
                resolved_part_id,
                part_role,
                qty,
                uom,
                unit_cost_exw,
                deleted
            ) VALUES (
                p_org_id,
                v_instance_id,
                v_resolved_item,
                v_slot.item_role,
                v_qty,
                v_unit_uom,
                v_unit_cost,
                false
            );
        ELSIF v_resolved_item IS NULL AND v_qty > 0 THEN
            RAISE WARNING 'Skipping BOM line insertion for role %: qty=% but resolved_part_id is NULL', v_slot.item_role, v_qty;
        END IF;

        -- PASO 6: Si hay SKU resuelto, agregar HIJOS desde CatalogItemComponents
        IF v_resolved_item IS NOT NULL THEN
            FOR v_child IN
                SELECT 
                    cic.child_item_id,
                    cic.child_role,
                    cic.qty,
                    cic.uom,
                    COALESCE(ci.cost_exw, 0) AS child_cost
                FROM public."CatalogItemComponents" cic
                JOIN public."CatalogItems" ci ON ci.id = cic.child_item_id
                WHERE cic.organization_id = p_org_id
                    AND cic.parent_item_id = v_resolved_item
                    AND cic.deleted = false
                ORDER BY cic.sort_order ASC
            LOOP
                -- REGLA ESPECIAL: mounting_clip con qty_type=per_width
                IF v_child.child_role = 'mounting_clip' THEN
                    SELECT * INTO v_mounting_clip_rule
                    FROM public."BOMComponents"
                    WHERE organization_id = p_org_id
                        AND bom_template_id = v_template_id
                        AND component_role = 'mounting_clip'
                        AND depends_on_role = v_slot.item_role
                        AND qty_type = 'per_width'
                        AND deleted = false
                    LIMIT 1;

                    IF v_mounting_clip_rule.id IS NOT NULL THEN
                        v_mounting_clip_qty := CEIL((v_width_mm / 1000.0) * v_mounting_clip_rule.qty_value);
                        IF v_mounting_clip_qty < 2 THEN
                            v_mounting_clip_qty := 2;
                        END IF;
                        v_child.qty := v_mounting_clip_qty * v_qty;
                        v_child.uom := 'ea';
                    END IF;
                END IF;

                INSERT INTO public."BOMInstanceLines"(
                    organization_id,
                    bom_instance_id,
                    resolved_part_id,
                    part_role,
                    qty,
                    uom,
                    unit_cost_exw,
                    deleted
                ) VALUES (
                    p_org_id,
                    v_instance_id,
                    v_child.child_item_id,
                    v_child.child_role,
                    v_qty * v_child.qty,
                    v_child.uom,
                    v_child.child_cost,
                    false
                );
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_instance_id;
END;
$$;


--
-- Name: FUNCTION generate_bom_from_slots_for_configured_product(p_org_id uuid, p_configured_product_id uuid, p_product_type_id uuid, p_quote_line_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.generate_bom_from_slots_for_configured_product(p_org_id uuid, p_configured_product_id uuid, p_product_type_id uuid, p_quote_line_id uuid) IS 'Genera BOMInstance y BOMInstanceLines para un ConfiguredProduct.
✅ CAMBIO: Ahora acepta quote_line_id opcional.
- Si quote_line_id viene: crea BOMInstance con quote_line_id (requerido por constraint)
- Si quote_line_id es NULL: NO crea BOMInstance (retorna NULL)
Esto evita violar el constraint NOT NULL en BOMInstances.quote_line_id.';


--
-- Name: generate_bom_instance_for_quote_line(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_bom_instance_for_quote_line(p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
declare
  v_org_id uuid;
  v_product_type_code text;
  v_product_type_id uuid;

  v_template_id uuid;
  v_instance_id uuid;

  -- column/table existence flags (para no reventar si faltan)
  has_bomtemplates_archived boolean;
  has_bomtemplates_is_active boolean;
  has_bomtemplates_updated_at boolean;

  has_bomcomponents_deleted boolean;

  has_bominstances_quote_line_id boolean;
begin
  -- 0) Validaciones base
  select organization_id, product_type
    into v_org_id, v_product_type_code
  from public."QuoteLines"
  where id = p_quote_line_id;

  if v_org_id is null then
    raise exception 'QuoteLine not found %', p_quote_line_id;
  end if;

  if v_product_type_code is null or btrim(v_product_type_code) = '' then
    raise exception 'QuoteLine % has NULL/empty product_type', p_quote_line_id;
  end if;

  -- 1) Resolver ProductTypes.id usando QuoteLines.product_type (code)
  select pt.id
    into v_product_type_id
  from public."ProductTypes" pt
  where pt.organization_id = v_org_id
    and pt.code = v_product_type_code
  limit 1;

  if v_product_type_id is null then
    raise exception 'ProductTypes not found for organization_id=% and code=%', v_org_id, v_product_type_code;
  end if;

  -- 2) Detectar columnas reales en BOMTemplates / BOMComponents
  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='archived'
  ) into has_bomtemplates_archived;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='is_active'
  ) into has_bomtemplates_is_active;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMTemplates' and column_name='updated_at'
  ) into has_bomtemplates_updated_at;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMComponents' and column_name='deleted'
  ) into has_bomcomponents_deleted;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='BOMInstances' and column_name='quote_line_id'
  ) into has_bominstances_quote_line_id;

  -- 3) Seleccionar el BOMTemplate “mejor” (por product_type_id)
  --    (sin usar deleted porque en tu tabla NO existe)
  if has_bomtemplates_updated_at then
    execute format($q$
      select t.id
      from public."BOMTemplates" t
      where t.organization_id = $1
        and t.product_type_id = $2
        %s
        %s
      order by t.updated_at desc nulls last
      limit 1
    $q$,
      case when has_bomtemplates_is_active then 'and t.is_active = true' else '' end,
      case when has_bomtemplates_archived then 'and t.archived = false' else '' end
    )
    into v_template_id
    using v_org_id, v_product_type_id;
  else
    execute format($q$
      select t.id
      from public."BOMTemplates" t
      where t.organization_id = $1
        and t.product_type_id = $2
        %s
        %s
      order by t.created_at desc
      limit 1
    $q$,
      case when has_bomtemplates_is_active then 'and t.is_active = true' else '' end,
      case when has_bomtemplates_archived then 'and t.archived = false' else '' end
    )
    into v_template_id
    using v_org_id, v_product_type_id;
  end if;

  if v_template_id is null then
    raise exception 'No BOMTemplate found for organization_id=% product_type_id=% (code=%)',
      v_org_id, v_product_type_id, v_product_type_code;
  end if;

  -- 4) Crear BOMInstance
  v_instance_id := gen_random_uuid();

  if has_bominstances_quote_line_id then
    insert into public."BOMInstances"(id, organization_id, quote_line_id, bom_template_id, created_at)
    values (v_instance_id, v_org_id, p_quote_line_id, v_template_id, now());
  else
    -- fallback por si tu BOMInstances no tiene quote_line_id (no debería pasar, pero lo cubrimos)
    insert into public."BOMInstances"(id, organization_id, bom_template_id, created_at)
    values (v_instance_id, v_org_id, v_template_id, now());
  end if;

  -- 5) Copiar BOMComponents -> BOMInstanceLines (usando TU esquema real)
  --    BOMInstanceLines: part_role, resolved_part_id, qty, uom, etc.
  execute format($q$
    insert into public."BOMInstanceLines"(
      id,
      bom_instance_id,
      bom_component_id,
      resolved_part_id,
      part_role,
      qty,
      uom,
      unit_cost_exw,
      total_cost_exw,
      organization_id,
      created_at,
      deleted
    )
    select
      gen_random_uuid(),
      $1 as bom_instance_id,
      bc.id as bom_component_id,
      bc.component_item_id as resolved_part_id,
      bc.component_role as part_role,
      coalesce(bc.qty_value, 1)::numeric as qty,
      coalesce(bc.uom, 'ea')::text as uom,
      null::numeric as unit_cost_exw,
      null::numeric as total_cost_exw,
      bc.organization_id,
      now(),
      false
    from public."BOMComponents" bc
    where bc.organization_id = $2
      and bc.bom_template_id = $3
      %s
  $q$,
    case when has_bomcomponents_deleted then 'and bc.deleted = false' else '' end
  )
  using v_instance_id, v_org_id, v_template_id;

  return v_instance_id;
end;
$_$;


--
-- Name: generate_bom_instance_for_quote_line(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_bom_instance_for_quote_line(p_org_id uuid, p_quote_line_id uuid, p_product_type_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_config jsonb;
  v_template_id uuid;
  v_instance_id uuid;
  v_ql public."QuoteLines";
  v_comp public."BOMComponents";
  v_override_item uuid;
  v_item_id uuid;
  v_qty numeric(12,4);
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_unit_cost numeric(12,4);
begin
  select * into v_ql
  from public."QuoteLines"
  where id = p_quote_line_id
    and organization_id = p_org_id;

  if v_ql.id is null then
    raise exception 'QuoteLine not found % (org=%)', p_quote_line_id, p_org_id;
  end if;

  v_config := public.build_quote_line_config(p_org_id, p_quote_line_id);
  v_template_id := public.select_best_bom_template(p_org_id, p_product_type_id, v_config);

  update public."BOMInstances"
    set deleted = true
  where organization_id = p_org_id
    and quote_line_id = p_quote_line_id
    and deleted = false;

  insert into public."BOMInstances"(organization_id, quote_line_id, bom_template_id)
  values (p_org_id, p_quote_line_id, v_template_id)
  returning id into v_instance_id;

  v_width_mm := coalesce(v_ql.width_m, 0) * 1000;
  v_height_mm := coalesce(v_ql.height_m, 0) * 1000;

  for v_comp in
    select *
    from public."BOMComponents"
    where organization_id = p_org_id
      and bom_template_id = v_template_id
      and deleted = false
      and archived = false
    order by (depends_on_role is not null)::int, sort_order asc
  loop
    select qlc.catalog_item_id into v_override_item
    from public."QuoteLineComponents" qlc
    where qlc.organization_id = p_org_id
      and qlc.quote_line_id = p_quote_line_id
      and qlc.component_role = v_comp.component_role
      and qlc.kind = 'override'
      and qlc.deleted = false
    limit 1;

    if v_comp.qty_type = 'fixed' then
      v_qty := v_comp.qty_value;
    elsif v_comp.qty_type = 'per_width' then
      v_qty := ((v_width_mm + coalesce(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    elsif v_comp.qty_type = 'per_height' then
      v_qty := ((v_height_mm + coalesce(v_comp.qty_delta_mm, 0)) / 1000.0) * v_comp.qty_value;
    elsif v_comp.qty_type = 'per_area' then
      v_qty := ((v_width_mm/1000.0) * (v_height_mm/1000.0)) * v_comp.qty_value;
    else
      v_qty := v_comp.qty_value;
    end if;

    if v_comp.waste_pct is not null and v_comp.waste_pct > 0 then
      v_qty := v_qty * (1 + v_comp.waste_pct);
    end if;

    v_item_id := coalesce(v_override_item, v_comp.component_item_id);

    if v_item_id is not null and v_qty > 0 then
      select ci.cost_exw into v_unit_cost
      from public."CatalogItems" ci
      where ci.id = v_item_id;

      v_unit_cost := coalesce(v_unit_cost, 0);

      insert into public."BOMInstanceLines"(
        organization_id,
        bom_instance_id,
        resolved_part_id,
        part_role,
        qty,
        uom,
        unit_cost_exw,
        deleted
      ) values (
        p_org_id,
        v_instance_id,
        v_item_id,
        v_comp.component_role,
        v_qty,
        v_comp.uom,
        v_unit_cost,
        false
      );
    end if;
  end loop;

  return v_instance_id;
end;
$$;


--
-- Name: generate_bom_instance_for_quote_line_v1(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_bom_instance_for_quote_line_v1(p_org_id uuid, p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_product_type_id uuid;
  v_template_id uuid;
  v_instance_id uuid;

  v_width_mm numeric;
  v_height_mm numeric;

  v_rules jsonb;
  v_target int;
  v_clearance int;

  v_tube_width_mm numeric;
  v_fabric_width_mm numeric;

  r record;
  v_resolved uuid;
  v_qty numeric;
  v_uom text;
BEGIN
  -- product_type_id: en tu esquema NO está en QuoteLines.
  -- Así que: asumimos roller_shade por el BOMTemplate seleccionado (por ahora).
  -- (Si luego agregas product_type_id a QuoteLines, lo conectamos.)
  -- Para V1: usa el product_type_id de tus templates de Roller Shade.
  SELECT pt.id INTO v_product_type_id
  FROM public."ProductTypes" pt
  WHERE pt.organization_id = p_org_id
    AND pt.code = 'roller_shade'
  LIMIT 1;

  IF v_product_type_id IS NULL THEN
    RAISE EXCEPTION 'ProductTypes.code=roller_shade not found for org %', p_org_id;
  END IF;

  -- medidas
  SELECT (ql.width_m * 1000), (ql.height_m * 1000)
    INTO v_width_mm, v_height_mm
  FROM public."QuoteLines" ql
  WHERE ql.organization_id = p_org_id
    AND ql.id = p_quote_line_id;

  IF v_width_mm IS NULL OR v_height_mm IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % must have width_m and height_m', p_quote_line_id;
  END IF;

  -- seleccionar template
  v_template_id := public.select_best_bom_template_for_quote_line(
    p_org_id, v_product_type_id, p_quote_line_id
  );

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate for QuoteLine % (missing options?)', p_quote_line_id;
  END IF;

  -- rules
  SELECT bt.metadata->'rules' INTO v_rules
  FROM public."BOMTemplates" bt
  WHERE bt.id = v_template_id;

  v_target := COALESCE((v_rules->>'tube_total_target_mm')::int, 0);
  v_clearance := COALESCE((v_rules->>'fabric_width_clearance_total_mm')::int, 2);

  IF v_target = 0 THEN
    RAISE EXCEPTION 'Template % missing rules.tube_total_target_mm', v_template_id;
  END IF;

  v_tube_width_mm := v_width_mm - v_target;
  v_fabric_width_mm := v_tube_width_mm - v_clearance;

  -- upsert instance (hay unique index org+quote_line donde deleted=false)
  SELECT bi.id INTO v_instance_id
  FROM public."BOMInstances" bi
  WHERE bi.organization_id = p_org_id
    AND bi.quote_line_id = p_quote_line_id
    AND bi.deleted = false
  LIMIT 1;

  IF v_instance_id IS NULL THEN
    INSERT INTO public."BOMInstances"(organization_id, quote_line_id, bom_template_id, deleted)
    VALUES (p_org_id, p_quote_line_id, v_template_id, false)
    RETURNING id INTO v_instance_id;
  ELSE
    UPDATE public."BOMInstances"
    SET bom_template_id = v_template_id, updated_at = now()
    WHERE id = v_instance_id;

    DELETE FROM public."BOMInstanceLines" WHERE bom_instance_id = v_instance_id;
  END IF;

  -- generar lines desde BOMComponents
  FOR r IN
    SELECT *
    FROM public."BOMComponents" bc
    WHERE bc.organization_id = p_org_id
      AND bc.bom_template_id = v_template_id
      AND bc.deleted = false
      AND bc.archived = false
    ORDER BY bc.sort_order ASC
  LOOP
    v_resolved := public.resolve_catalog_item_for_bom_component(
      p_org_id,
      p_quote_line_id,
      r.component_role,
      r.component_item_id
    );

    -- qty por tipo (V1 simple)
    IF r.qty_type = 'fixed' THEN
      v_qty := r.qty_value;
      v_uom := r.uom;
    ELSIF r.qty_type = 'per_width' THEN
      -- qty en mm (corte)
      IF r.component_role = 'tube' THEN
        v_qty := v_tube_width_mm;
      ELSIF r.component_role IN ('fabric','bottom_bar_profile','bottom_rail_profile','side_channel_profile','track','top_rail_profile') THEN
        v_qty := v_fabric_width_mm;
      ELSE
        v_qty := v_width_mm;
      END IF;
      v_uom := 'mm';
    ELSIF r.qty_type = 'per_area' THEN
      v_qty := (v_fabric_width_mm * v_height_mm);
      v_uom := 'mm2';
    ELSE
      v_qty := r.qty_value;
      v_uom := r.uom;
    END IF;

    INSERT INTO public."BOMInstanceLines"(
      bom_instance_id, bom_component_id, resolved_part_id, part_role,
      qty, uom,
      cut_width_mm, cut_height_mm, cut_length_mm,
      unit_cost_exw, total_cost_exw
    )
    VALUES (
      v_instance_id, r.id, v_resolved, r.component_role,
      v_qty, v_uom,
      CASE WHEN r.component_role IN ('tube','fabric','bottom_bar_profile','bottom_rail_profile','side_channel_profile','track','top_rail_profile') THEN v_qty ELSE NULL END,
      CASE WHEN r.component_role = 'fabric' THEN v_height_mm ELSE NULL END,
      NULL,
      NULL, NULL
    );
  END LOOP;

  RETURN v_instance_id;
END;
$$;


--
-- Name: get_auth_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_auth_context() RETURNS TABLE(user_id uuid, is_org_user boolean, is_portal_user boolean, organization_id uuid, company_id uuid, needs_password boolean, access_allowed boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_company_id uuid;
  v_org_status text;
  v_portal_status text;
  v_org_must_change_password boolean;
  v_portal_must_change_password boolean;
  v_is_org_user boolean := false;
  v_is_portal_user boolean := false;
  v_access_allowed boolean := false;
  v_needs_password boolean := false;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- If no user, return empty context
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      NULL::uuid,
      false::boolean,
      false::boolean,
      NULL::uuid,
      NULL::uuid,
      false::boolean,
      false::boolean;
    RETURN;
  END IF;

  -- Check for OrganizationUser membership (active or invited)
  SELECT 
    ou.id,
    ou.organization_id,
    ou.status,
    COALESCE(ou.must_change_password, false)
  INTO 
    v_org_user_id,
    v_organization_id,
    v_org_status,
    v_org_must_change_password
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
    AND ou.status IN ('active', 'invited')
  LIMIT 1;

  IF v_org_user_id IS NOT NULL THEN
    v_is_org_user := true;
    v_access_allowed := true;
  END IF;

  -- Check for CompanyPortalUser membership (active or invited)
  IF v_org_user_id IS NULL THEN
    SELECT 
      cpu.id,
      cpu.company_id,
      cpu.organization_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_portal_user_id,
      v_company_id,
      v_organization_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;

    IF v_portal_user_id IS NOT NULL THEN
      v_is_portal_user := true;
      v_access_allowed := true;
    END IF;
  ELSE
    -- If org user, also try to get company_id and status from portal user
    SELECT 
      cpu.company_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_company_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  -- ✅ needs_password = true if must_change_password is true in EITHER table
  v_needs_password := COALESCE(v_org_must_change_password, false) OR COALESCE(v_portal_must_change_password, false);

  -- Return context
  RETURN QUERY SELECT 
    v_user_id,
    v_is_org_user,
    v_is_portal_user,
    v_organization_id,
    v_company_id,
    v_needs_password,
    v_access_allowed;
END;
$$;


--
-- Name: FUNCTION get_auth_context(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_auth_context() IS 'Get authentication context for current user. Checks membership in OrganizationUsers and CompanyPortalUsers. Returns membership status, organization/company IDs, password requirement (from must_change_password), and access permission. NO dependency on Profiles table. STABLE function safe for use in queries.';


--
-- Name: get_catalog_item_price_for_quote(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_catalog_item_price_for_quote(p_catalog_item_id uuid) RETURNS TABLE(measure_basis text, unit_price numeric, unit_label text)
    LANGUAGE sql STABLE
    AS $$
  select
    ci.measure_basis,
    case
      when coalesce(ci.measure_basis,'linear') = 'linear' then conv.cost_exw_per_m
      when ci.measure_basis = 'area' then conv.cost_exw_per_m2
      when ci.measure_basis = 'unit' then ci.cost_exw
      else conv.cost_exw_per_m
    end as unit_price,
    case
      when coalesce(ci.measure_basis,'linear') = 'linear' then 'ml'
      when ci.measure_basis = 'area' then 'm2'
      when ci.measure_basis = 'unit' then 'unit'
      else 'ml'
    end as unit_label
  from public."CatalogItems" ci
  left join public."CatalogItemConversions" conv
    on conv.catalog_item_id = ci.id
  where ci.id = p_catalog_item_id;
$$;


--
-- Name: get_catalog_item_unit_cost_norm(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_catalog_item_unit_cost_norm(p_catalog_item_id uuid, p_organization_id uuid) RETURNS TABLE(basis text, unit_cost numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_ci RECORD;
  v_conv RECORD;
  v_basis text;
  v_unit_cost numeric(12,4);
BEGIN
  SELECT
    ci.id,
    ci.organization_id,
    ci.is_roll,
    ci.roll_width,
    ci.unit_of_measure,
    ci.cost_exw
  INTO v_ci
  FROM public."CatalogItems" ci
  WHERE ci.id = p_catalog_item_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 'ea'::text, 0::numeric;
    RETURN;
  END IF;

  SELECT
    conv.cost_exw_per_m,
    conv.cost_exw_per_m2,
    conv.cost_exw_per_ea
  INTO v_conv
  FROM public."CatalogItemConversions" conv
  WHERE conv.catalog_item_id = p_catalog_item_id
    AND conv.organization_id = p_organization_id
  LIMIT 1;

  IF COALESCE(v_ci.is_roll,false) = true THEN
    IF v_conv.cost_exw_per_m2 IS NOT NULL THEN
      v_basis := 'm2';
      v_unit_cost := v_conv.cost_exw_per_m2;
    ELSIF v_conv.cost_exw_per_m IS NOT NULL THEN
      v_basis := 'm';
      v_unit_cost := v_conv.cost_exw_per_m;
    ELSE
      v_basis := 'ea';
      v_unit_cost := COALESCE(v_conv.cost_exw_per_ea, v_ci.cost_exw, 0);
    END IF;
  ELSE
    -- no-roll: prefer ea if available, else m if available
    IF v_conv.cost_exw_per_ea IS NOT NULL THEN
      v_basis := 'ea';
      v_unit_cost := v_conv.cost_exw_per_ea;
    ELSIF v_conv.cost_exw_per_m IS NOT NULL THEN
      v_basis := 'm';
      v_unit_cost := v_conv.cost_exw_per_m;
    ELSIF v_conv.cost_exw_per_m2 IS NOT NULL THEN
      v_basis := 'm2';
      v_unit_cost := v_conv.cost_exw_per_m2;
    ELSE
      v_basis := 'ea';
      v_unit_cost := COALESCE(v_ci.cost_exw, 0);
    END IF;
  END IF;

  RETURN QUERY SELECT v_basis, COALESCE(v_unit_cost,0)::numeric(12,4);
END;
$$;


--
-- Name: get_category_id_by_path(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_category_id_by_path(p_org uuid, p_path text) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  parts text[];
  i int;
  current_id uuid;
  part_name text;
BEGIN
  IF p_path IS NULL OR btrim(p_path) = '' THEN
    RETURN NULL;
  END IF;

  parts := regexp_split_to_array(p_path, '\s*>\s*');
  current_id := NULL;

  FOR i IN 1..array_length(parts, 1) LOOP
    part_name := btrim(parts[i]);

    SELECT c.id INTO current_id
    FROM public."CatalogCategories" c
    WHERE c.organization_id = p_org
      AND (
        (current_id IS NULL AND c.parent_id IS NULL)
        OR (c.parent_id = current_id)
      )
      AND lower(c.name) = lower(part_name)
    LIMIT 1;

    IF current_id IS NULL THEN
      RETURN NULL;
    END IF;
  END LOOP;

  RETURN current_id;
END;
$$;


--
-- Name: get_category_margins_for_category(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_category_margins_for_category(p_organization_id uuid, p_category_id uuid, OUT msrp_pct_sale_in numeric, OUT msrp_pct_sale_out numeric) RETURNS record
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_current_category_id uuid;
  v_found boolean := false;
BEGIN
  -- Valores por defecto
  msrp_pct_sale_in := 0.35;
  msrp_pct_sale_out := 0.65;

  -- Si no hay category_id, retornar defaults
  IF p_category_id IS NULL THEN
    RETURN;
  END IF;

  v_current_category_id := p_category_id;

  -- Buscar márgenes subiendo por la jerarquía de categorías
  WHILE v_current_category_id IS NOT NULL AND NOT v_found LOOP
    SELECT 
      COALESCE(cm.msrp_pct_sale_in, 0.35),
      COALESCE(cm.msrp_pct_sale_out, 0.65)
    INTO msrp_pct_sale_in, msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id
      AND cm.category_id = v_current_category_id
      AND COALESCE(cm.is_active, true) = true
    LIMIT 1;

    -- Si encontramos, salir
    IF FOUND THEN
      v_found := true;
    ELSE
      -- Si no encontramos, intentar con la categoría padre
      SELECT parent_id INTO v_current_category_id
      FROM public."CatalogCategories"
      WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  -- Si no encontramos nada, usar defaults
  IF NOT v_found THEN
    msrp_pct_sale_in := 0.35;
    msrp_pct_sale_out := 0.65;
  END IF;
END;
$$;


--
-- Name: FUNCTION get_category_margins_for_category(p_organization_id uuid, p_category_id uuid, OUT msrp_pct_sale_in numeric, OUT msrp_pct_sale_out numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_category_margins_for_category(p_organization_id uuid, p_category_id uuid, OUT msrp_pct_sale_in numeric, OUT msrp_pct_sale_out numeric) IS 'Busca márgenes (msrp_pct_sale_in, msrp_pct_sale_out) para una categoría, subiendo por la jerarquía hasta encontrar una regla activa. Si no encuentra, retorna defaults (35%, 65%).';


--
-- Name: get_current_portal_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_current_portal_user() RETURNS TABLE(id uuid, organization_id uuid, company_id uuid, portal_user_role text, status text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cpu.id,
    cpu.organization_id,
    cpu.company_id,
    -- Use role column directly (normalize legacy values)
    CASE 
      WHEN cpu.role IN ('member_manager', 'manager') THEN 'member_manager'::text
      WHEN cpu.role = 'member' THEN 'member'::text
      ELSE 'member'::text -- default fallback
    END as portal_user_role,
    cpu.status::text as status
  FROM public."CompanyPortalUsers" cpu
  WHERE (
    cpu.user_id = auth.uid()
    OR cpu.portal_user_email = (auth.jwt() ->> 'email')
  )
    AND cpu.deleted = false
    AND cpu.status IN ('active', 'invited')
  LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_current_portal_user(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_current_portal_user() IS 'Get current portal user info using status column. Returns empty if not a portal user or not active. Supports both user_id and email matching.';


--
-- Name: get_current_portal_user_company_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_current_portal_user_company_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select company_id
  from public."CompanyPortalUsers"
  where user_id = auth.uid()
    and deleted = false
    and portal_user_status = 'active'
  limit 1;
$$;


--
-- Name: get_import_tax_pct_for_category(uuid, uuid, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_import_tax_pct_for_category(p_organization_id uuid, p_category_id uuid, p_fallback_pct numeric DEFAULT 0) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_tax_pct numeric;
  v_current_category_id uuid;
BEGIN
  -- Si no hay category_id, retornar fallback
  IF p_category_id IS NULL THEN
    RETURN p_fallback_pct;
  END IF;

  v_current_category_id := p_category_id;
  v_tax_pct := NULL;

  -- Buscar regla activa subiendo por la jerarquía de categorías
  WHILE v_current_category_id IS NOT NULL AND v_tax_pct IS NULL LOOP
    SELECT import_tax_pct INTO v_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_organization_id
      AND category_id = v_current_category_id
      AND COALESCE(is_active, true) = true
    LIMIT 1;

    -- Si no encontramos, intentar con la categoría padre
    IF v_tax_pct IS NULL THEN
      SELECT parent_id INTO v_current_category_id
      FROM public."CatalogCategories"
      WHERE id = v_current_category_id;
    END IF;
  END LOOP;

  -- Retornar el valor encontrado o el fallback
  RETURN COALESCE(v_tax_pct, p_fallback_pct);
END;
$$;


--
-- Name: FUNCTION get_import_tax_pct_for_category(p_organization_id uuid, p_category_id uuid, p_fallback_pct numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_import_tax_pct_for_category(p_organization_id uuid, p_category_id uuid, p_fallback_pct numeric) IS 'Busca import_tax_pct para una categoría, subiendo por la jerarquía (parent_category_id) hasta encontrar una regla activa. Si no encuentra, retorna el fallback.';


--
-- Name: get_must_change_password(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_must_change_password() RETURNS TABLE(must_change_password boolean, user_type text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_org_must_change boolean;
  v_portal_must_change boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'none'::text;
    RETURN;
  END IF;

  -- Check OrganizationUsers
  SELECT ou.must_change_password
  INTO v_org_must_change
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
  LIMIT 1;

  IF v_org_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_org_must_change, 'org'::text;
    RETURN;
  END IF;

  -- Check CompanyPortalUsers
  SELECT cpu.must_change_password
  INTO v_portal_must_change
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.user_id = v_user_id
    AND cpu.deleted = false
  LIMIT 1;

  IF v_portal_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_portal_must_change, 'portal'::text;
    RETURN;
  END IF;

  -- No membership found
  RETURN QUERY SELECT false, 'none'::text;
END;
$$;


--
-- Name: FUNCTION get_must_change_password(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_must_change_password() IS 'Returns must_change_password flag and user type (org/portal/none) for the current authenticated user';


--
-- Name: get_my_portal_access(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_portal_access() RETURNS TABLE(id uuid, organization_id uuid, portal_user_email text, user_id uuid, role text, status text, deleted boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  SELECT
    cpu.id,
    cpu.organization_id,
    cpu.portal_user_email,
    cpu.user_id,
    cpu.role::text as role,
    cpu.status::text as status,
    cpu.deleted
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.deleted = false
    AND (cpu.status IS NULL OR cpu.status IN ('active', 'invited'))
    AND (
      cpu.user_id = auth.uid()
      OR lower(trim(cpu.portal_user_email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
    )
  ORDER BY cpu.created_at DESC NULLS LAST
  LIMIT 1;
$$;


--
-- Name: get_parent_sku_selections(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_parent_sku_selections(p_org_id uuid, p_quote_line_id uuid) RETURNS TABLE(component_role text, catalog_item_id uuid, sku text, item_name text)
    LANGUAGE sql STABLE
    AS $$
  SELECT 
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    ci.name as item_name
  FROM public."QuoteLineComponents" qlc
  LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false
  ORDER BY qlc.created_at ASC;
$$;


--
-- Name: FUNCTION get_parent_sku_selections(p_org_id uuid, p_quote_line_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_parent_sku_selections(p_org_id uuid, p_quote_line_id uuid) IS 'Get all parent SKU selections made by user for a quote line. Used for debugging and validation.';


--
-- Name: get_quote_line_option_value(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_quote_line_option_value(p_org_id uuid, p_quote_line_id uuid, p_key text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT qlc.payload->>'value'
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.deleted = false
    AND qlc.kind = 'option'
    AND qlc.component_role = p_key
  ORDER BY qlc.created_at DESC
  LIMIT 1;
$$;


--
-- Name: get_roll_unit_price_for_quote(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_roll_unit_price_for_quote(p_catalog_item_id uuid) RETURNS TABLE(roll_pricing_mode text, unit_price numeric, unit_label text)
    LANGUAGE sql STABLE
    AS $$
  select
    ci.roll_pricing_mode,
    case
      when ci.roll_pricing_mode = 'per_linear_meter' then conv.cost_exw_per_m
      when ci.roll_pricing_mode = 'per_square_meter' then conv.cost_exw_per_m2
      when ci.roll_pricing_mode = 'per_unit' then ci.cost_exw
      else conv.cost_exw_per_m
    end as unit_price,
    case
      when ci.roll_pricing_mode = 'per_linear_meter' then 'ml'
      when ci.roll_pricing_mode = 'per_square_meter' then 'm2'
      when ci.roll_pricing_mode = 'per_unit' then 'unit'
      else 'ml'
    end as unit_label
  from public."CatalogItems" ci
  left join public."CatalogItemConversions" conv
    on conv.catalog_item_id = ci.id
  where ci.id = p_catalog_item_id;
$$;


--
-- Name: handle_auth_user_created_for_org_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_auth_user_created_for_org_users() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Link OrganizationUsers where email matches and user_id is null
  UPDATE public."OrganizationUsers"
  SET
    user_id = NEW.id,
    status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE
    lower(user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION handle_auth_user_created_for_org_users(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.handle_auth_user_created_for_org_users() IS 'Automatically links OrganizationUsers invites when a new auth.users is created. Matches by lower(email).';


--
-- Name: handle_auth_user_created_for_portal_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_auth_user_created_for_portal_users() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  UPDATE public."CompanyPortalUsers"
  SET
    user_id = NEW.id,
    status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
    accepted_at = COALESCE(accepted_at, now()),
    updated_at = now()
  WHERE lower(portal_user_email) = lower(NEW.email)
    AND user_id IS NULL
    AND deleted = false;

  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION handle_auth_user_created_for_portal_users(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.handle_auth_user_created_for_portal_users() IS 'Automatically links CompanyPortalUsers invites when a new auth.users is created. Uses ONLY "status" column (not portal_user_status).';


--
-- Name: handle_quote_approved(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_quote_approved() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_sales_order_id uuid;
    v_sales_order_no text;
    v_quote_no text;
BEGIN
    -- Only process when status changes to 'approved'
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Check if SalesOrder already exists (idempotent)
        SELECT id INTO v_sales_order_id
        FROM public."SalesOrders"
        WHERE quote_id = NEW.id
        AND deleted = false
        LIMIT 1;

        -- If SalesOrder doesn't exist, create it
        IF v_sales_order_id IS NULL THEN
            -- Generate sales_order_no from quote_no
            v_quote_no := NEW.quote_no;
            v_sales_order_no := 'SO-' || v_quote_no || '-' || to_char(now(), 'YYYYMMDD-HH24MISS');

            -- Insert SalesOrder
            INSERT INTO public."SalesOrders" (
                organization_id,
                quote_id,
                sales_order_no,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                NEW.id,
                v_sales_order_no,
                'pending_confirmation',
                false,
                now(),
                now()
            )
            RETURNING id INTO v_sales_order_id;

            -- Insert OrderList (mirror of SalesOrder)
            INSERT INTO public."OrderList" (
                organization_id,
                sales_order_id,
                tracking_status,
                deleted,
                created_at,
                updated_at
            )
            VALUES (
                NEW.organization_id,
                v_sales_order_id,
                'pending_confirmation',
                false,
                now(),
                now()
            );
        END IF;

        -- Update Quote.tracking_status
        NEW.tracking_status := 'pending_confirmation';
    END IF;

    -- If status is NOT 'approved', ensure tracking_status is NULL
    IF NEW.status != 'approved' THEN
        NEW.tracking_status := NULL;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION handle_quote_approved(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.handle_quote_approved() IS 'Trigger function: When Quote.status changes to approved, creates SalesOrder and OrderList, and sets Quote.tracking_status to pending_confirmation.';


--
-- Name: is_company_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_company_member(p_company_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


--
-- Name: FUNCTION is_company_member(p_company_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_company_member(p_company_id uuid) IS 'Check if current user is member of company via organization. SECURITY DEFINER to avoid RLS recursion.';


--
-- Name: is_company_owner_or_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_company_owner_or_admin(p_company_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."Companies" c
    JOIN public."OrganizationUsers" ou ON ou.organization_id = c.organization_id
    WHERE c.id = p_company_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin') -- Added 'superadmin'
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


--
-- Name: FUNCTION is_company_owner_or_admin(p_company_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_company_owner_or_admin(p_company_id uuid) IS 'Check if current user is superadmin/owner/admin of company via organization. SECURITY DEFINER to avoid RLS recursion. Updated to include superadmin role.';


--
-- Name: is_company_portal_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_company_portal_user(p_company_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = p_company_id
      AND (
        cpu.user_id = auth.uid()
        OR cpu.portal_user_email = (auth.jwt() ->> 'email')
      )
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
  );
END;
$$;


--
-- Name: FUNCTION is_company_portal_user(p_company_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_company_portal_user(p_company_id uuid) IS 'Returns true if current user is a CompanyPortalUser (portal user) for the given company.';


--
-- Name: is_company_portal_user_with_write(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_company_portal_user_with_write(p_company_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.company_id = p_company_id
      AND (
        cpu.user_id = auth.uid()
        OR lower(cpu.portal_user_email) = lower(auth.jwt() ->> 'email')
      )
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
      AND cpu.role IN ('member_manager')   -- ✅ solo los que pueden write
  );
END;
$$;


--
-- Name: is_org_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_org_member(p_org_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND (ou.deleted IS NULL OR ou.deleted = false)
  );
END;
$$;


--
-- Name: FUNCTION is_org_member(p_org_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_org_member(p_org_id uuid) IS 'Check if current user is an active member of organization. SECURITY DEFINER to avoid RLS recursion.';


--
-- Name: is_org_owner_or_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_org_owner_or_admin(p_org_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'owner', 'admin') -- Added 'superadmin'
      AND ou.deleted = false
      AND ou.status = 'active'
  );
END;
$$;


--
-- Name: FUNCTION is_org_owner_or_admin(p_org_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_org_owner_or_admin(p_org_id uuid) IS 'Check if current user is superadmin/owner/admin in organization. SECURITY DEFINER to avoid RLS recursion. Updated to include superadmin role.';


--
-- Name: is_org_user_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_org_user_member(p_org_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;


--
-- Name: FUNCTION is_org_user_member(p_org_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_org_user_member(p_org_id uuid) IS 'Returns true if current user is an active/invited OrganizationUser member (non-superadmin).';


--
-- Name: is_org_user_superadmin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_org_user_superadmin(p_org_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'admin', 'owner')
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;


--
-- Name: FUNCTION is_org_user_superadmin(p_org_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_org_user_superadmin(p_org_id uuid) IS 'Returns true if current user is superadmin/admin/owner in the organization. Used for RLS policies that allow full access.';


--
-- Name: is_pack_uom(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_pack_uom(p_uom text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT lower(coalesce(p_uom,'')) = ANY (ARRAY[
    'pack','set','box','case','bag'
  ]);
$$;


--
-- Name: is_portal_user_self(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_portal_user_self(p_portal_row_id uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_uid uuid;
  v_jwt_email text;
  v_row_user_id uuid;
  v_row_email text;
BEGIN
  v_uid := auth.uid();

  IF v_uid IS NULL THEN
    RETURN false;
  END IF;

  SELECT cpu.user_id, cpu.portal_user_email
    INTO v_row_user_id, v_row_email
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.id = p_portal_row_id
    AND cpu.deleted = false
  LIMIT 1;

  -- not found
  IF v_row_user_id IS NULL AND v_row_email IS NULL THEN
    RETURN false;
  END IF;

  -- linked user_id match
  IF v_row_user_id IS NOT NULL AND v_row_user_id = v_uid THEN
    RETURN true;
  END IF;

  -- fallback email match (unlinked invites)
  v_jwt_email := NULLIF(lower(trim(auth.jwt() ->> 'email')), '');

  IF v_jwt_email IS NOT NULL
     AND v_row_email IS NOT NULL
     AND lower(trim(v_row_email)) = v_jwt_email THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;


--
-- Name: FUNCTION is_portal_user_self(p_portal_row_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_portal_user_self(p_portal_row_id uuid) IS 'True if current user matches the portal record by user_id or jwt email fallback.';


--
-- Name: is_unit_uom(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_unit_uom(p_uom text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT lower(coalesce(p_uom,'')) = ANY (ARRAY[
    'ea','pcs','pc','unit','piece'
  ]);
$$;


--
-- Name: link_my_invites(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.link_my_invites() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_org_updated int := 0;
  v_portal_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select lower(coalesce(auth.jwt() ->> 'email', '')) into v_email;

  if v_email = '' then
    raise exception 'Missing email in auth context';
  end if;

  -- OrganizationUsers: pegar user_id y activar si estaba invited
  update public."OrganizationUsers"
    set user_id = v_uid,
        status = case when status = 'invited' then 'active' else status end,
        updated_at = now()
  where lower(user_email) = v_email
    and (user_id is null or user_id = v_uid);

  get diagnostics v_org_updated = row_count;

  -- CompanyPortalUsers: ojo a tu columna de email: portal_user_email
  update public."CompanyPortalUsers"
    set user_id = v_uid,
        status = case when status = 'invited' then 'active' else status end,
        updated_at = now()
  where lower(portal_user_email) = v_email
    and (user_id is null or user_id = v_uid);

  get diagnostics v_portal_updated = row_count;

  return jsonb_build_object(
    'ok', true,
    'org_updated', v_org_updated,
    'portal_updated', v_portal_updated
  );
end;
$$;


--
-- Name: link_my_org_invites(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.link_my_org_invites() RETURNS TABLE(linked_count integer, updated_ids uuid[])
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_user_email text;
  v_linked_count integer := 0;
  v_updated_ids uuid[] := ARRAY[]::uuid[];
  v_portal_linked_count integer := 0;
  v_portal_updated_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  v_user_id := auth.uid();
  v_user_email := (SELECT email FROM auth.users WHERE id = v_user_id);

  IF v_user_id IS NULL OR v_user_email IS NULL THEN
    RAISE WARNING '[link_my_org_invites] No authenticated user or email found. Skipping link.';
    RETURN QUERY SELECT 0::integer, ARRAY[]::uuid[];
    RETURN;
  END IF;

  -- Link OrganizationUsers
  WITH updated AS (
    UPDATE public."OrganizationUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_linked_count, v_updated_ids
  FROM updated;

  -- Link CompanyPortalUsers (✅ SOLO status)
  WITH updated_portal AS (
    UPDATE public."CompanyPortalUsers"
    SET
      user_id = v_user_id,
      status = CASE WHEN status = 'invited' THEN 'active' ELSE status END,
      accepted_at = COALESCE(accepted_at, now()),
      updated_at = now()
    WHERE lower(portal_user_email) = lower(v_user_email)
      AND user_id IS NULL
      AND deleted = false
    RETURNING id
  )
  SELECT COUNT(*)::integer, ARRAY_AGG(id)::uuid[]
  INTO v_portal_linked_count, v_portal_updated_ids
  FROM updated_portal;

  RETURN QUERY
    SELECT (v_linked_count + v_portal_linked_count)::integer,
           (COALESCE(v_updated_ids, ARRAY[]::uuid[]) || COALESCE(v_portal_updated_ids, ARRAY[]::uuid[]))::uuid[];
END;
$$;


--
-- Name: FUNCTION link_my_org_invites(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.link_my_org_invites() IS 'Links both OrganizationUsers and CompanyPortalUsers invites for the current authenticated user. Matches by email. Uses ONLY "status" column (not portal_user_status). Returns combined count and array of all updated IDs.';


--
-- Name: list_matching_bom_templates(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_matching_bom_templates(p_org uuid, p_product_type uuid, p_config jsonb) RETURNS TABLE(id uuid, code text, name text, metadata jsonb)
    LANGUAGE sql STABLE
    AS $$
  SELECT bt.id, bt.code, bt.name, bt.metadata
  FROM public."BOMTemplates" bt
  WHERE bt.organization_id = p_org
    AND bt.product_type_id = p_product_type
    AND bt.active = true
    AND bt.deleted = false
    AND bt.archived = false
    AND bt.metadata @> p_config
  ORDER BY bt.code;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: OrganizationUsers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."OrganizationUsers" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    user_id uuid,
    user_email text NOT NULL,
    user_name text,
    role public.org_role DEFAULT 'member'::public.org_role NOT NULL,
    status public.org_user_status DEFAULT 'invited'::public.org_user_status NOT NULL,
    invited_by_user_id uuid,
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    accepted_at timestamp with time zone,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    must_change_password boolean DEFAULT true NOT NULL,
    temp_password_set_at timestamp with time zone,
    CONSTRAINT organizationusers_role_check CHECK (((role)::text = ANY (ARRAY['superadmin'::text, 'admin'::text, 'operator'::text, 'procurement'::text, 'finance'::text])))
);


--
-- Name: TABLE "OrganizationUsers"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."OrganizationUsers" IS 'Organization users - internal users with roles (owner, admin, member, viewer)';


--
-- Name: COLUMN "OrganizationUsers".user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."OrganizationUsers".user_id IS 'FK to auth.users. Nullable until user accepts invite.';


--
-- Name: COLUMN "OrganizationUsers".user_email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."OrganizationUsers".user_email IS 'User email (lowercased). Unique per organization when not deleted.';


--
-- Name: COLUMN "OrganizationUsers".status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."OrganizationUsers".status IS 'Status: invited (pending), active (accepted), disabled (inactive)';


--
-- Name: list_organization_users(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_organization_users(p_organization_id uuid) RETURNS SETOF public."OrganizationUsers"
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
BEGIN
  -- Obtener caller user_id
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es miembro de la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Allow superadmin, admin, and owner (legacy) roles to list users
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins, admins, and owners can list organization users';
  END IF;

  -- Retornar usuarios de la organización (deleted=false)
  RETURN QUERY
  SELECT ou.*
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.deleted = false
  ORDER BY ou.created_at DESC;
END;
$$;


--
-- Name: FUNCTION list_organization_users(p_organization_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.list_organization_users(p_organization_id uuid) IS 'List all users in an organization. Only superadmins, admins, and owners can call.';


--
-- Name: msrp_compute_for_item(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msrp_compute_for_item(p_item_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_org_id uuid;
  v_category_id uuid;
  v_cost_exw numeric;

  v_shipping_pct numeric;
  v_import_tax_pct numeric;
  v_min_margin_pct numeric;
  v_msrp_pct_sale_in numeric;
  v_msrp_pct_sale_out numeric;

  v_material_cost numeric;
  v_shipping_cost numeric;
  v_import_tax_cost numeric;
  v_total_cost numeric;

  v_dealer_price numeric;
  v_msrp numeric;
BEGIN
  SELECT organization_id, category_id, COALESCE(cost_exw, 0)
    INTO v_org_id, v_category_id, v_cost_exw
  FROM public."CatalogItems"
  WHERE id = p_item_id;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  SELECT
    r.shipping_pct,
    r.import_tax_pct,
    r.minimum_margin_pct,
    r.msrp_pct_sale_in,
    r.msrp_pct_sale_out
  INTO
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_in,
    v_msrp_pct_sale_out
  FROM public.msrp_get_effective_rates(v_org_id, v_category_id) r;

  v_material_cost := COALESCE(v_cost_exw, 0);

  v_shipping_cost := round(v_material_cost * COALESCE(v_shipping_pct, 0), 6);
  v_import_tax_cost := round((v_material_cost + v_shipping_cost) * COALESCE(v_import_tax_pct, 0), 6);
  v_total_cost := round(v_material_cost + v_shipping_cost + v_import_tax_cost, 6);

  -- Dealer Price = Total Cost / (1 - minimum_margin_pct)
  v_dealer_price := round(v_total_cost / NULLIF(1 - COALESCE(v_min_margin_pct, 0), 0), 6);

  -- MSRP = Dealer Price / (1 - msrp_pct_sale_out)
  v_msrp := round(v_dealer_price / NULLIF(1 - COALESCE(v_msrp_pct_sale_out, 0), 0), 6);

  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id,
    organization_id,
    category_id,

    cost_exw,

    shipping_pct,
    import_tax_pct,
    minimum_margin_pct,
    msrp_pct_sale_out,

    shipping_cost,
    import_tax_cost,
    total_cost,

    dealer_price,
    msrp,

    updated_at
  )
  VALUES (
    p_item_id,
    v_org_id,
    v_category_id,

    v_cost_exw,

    COALESCE(v_shipping_pct, 0),
    COALESCE(v_import_tax_pct, 0),
    COALESCE(v_min_margin_pct, 0),
    COALESCE(v_msrp_pct_sale_out, 0),

    COALESCE(v_shipping_cost, 0),
    COALESCE(v_import_tax_cost, 0),
    COALESCE(v_total_cost, 0),

    COALESCE(v_dealer_price, 0),
    COALESCE(v_msrp, 0),

    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    category_id     = EXCLUDED.category_id,

    cost_exw        = EXCLUDED.cost_exw,

    shipping_pct        = EXCLUDED.shipping_pct,
    import_tax_pct      = EXCLUDED.import_tax_pct,
    minimum_margin_pct  = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out   = EXCLUDED.msrp_pct_sale_out,

    shipping_cost   = EXCLUDED.shipping_cost,
    import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost      = EXCLUDED.total_cost,

    dealer_price    = EXCLUDED.dealer_price,
    msrp            = EXCLUDED.msrp,

    updated_at      = now();
END;
$$;


--
-- Name: FUNCTION msrp_compute_for_item(p_item_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.msrp_compute_for_item(p_item_id uuid) IS 'Calcula MSRP para un CatalogItem.

Regla:
- total_cost = cost_exw + shipping_cost + import_tax_cost
- dealer_price = total_cost / (1 - minimum_margin_pct)
- msrp = dealer_price / (1 - msrp_pct_sale_out)

Nota: msrp_pct_sale_out es margen sobre la venta (margin-on-sale), aplicado sobre dealer_price.';


--
-- Name: msrp_get_effective_rates(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msrp_get_effective_rates(p_org_id uuid, p_category_id uuid) RETURNS TABLE(shipping_pct numeric, import_tax_pct numeric, minimum_margin_pct numeric, msrp_pct_sale_in numeric, msrp_pct_sale_out numeric)
    LANGUAGE sql STABLE
    AS $$
  WITH cs AS (
    SELECT
      COALESCE(shipping_pct, 0)::numeric AS shipping_pct,
      COALESCE(global_import_tax_pct, 0)::numeric AS global_import_tax_pct,
      COALESCE(minimum_margin_pct, 0)::numeric AS minimum_margin_pct,
      COALESCE(default_msrp_pct_sale_out, 0)::numeric AS default_msrp_pct_sale_out
    FROM public."CostSettings"
    WHERE organization_id = p_org_id
    LIMIT 1
  ),
  cm AS (
    SELECT
      msrp_pct_sale_in::numeric  AS msrp_pct_sale_in,
      msrp_pct_sale_out::numeric AS msrp_pct_sale_out
    FROM public."CategoryMargins"
    WHERE organization_id = p_org_id
      AND category_id = p_category_id
      AND is_active = true
    LIMIT 1
  ),
  it AS (
    SELECT
      import_tax_pct::numeric AS import_tax_pct
    FROM public."ImportTaxRules"
    WHERE organization_id = p_org_id
      AND category_id = p_category_id
      AND is_active = true
    LIMIT 1
  )
  SELECT
    -- shipping: siempre sale de CostSettings (default org)
    COALESCE((SELECT shipping_pct FROM cs), 0) AS shipping_pct,

    -- import tax: ImportTaxRules por categoría si existe; si no, global_import_tax_pct
    COALESCE((SELECT import_tax_pct FROM it), (SELECT global_import_tax_pct FROM cs), 0) AS import_tax_pct,

    -- min margin: CostSettings
    COALESCE((SELECT minimum_margin_pct FROM cs), 0) AS minimum_margin_pct,

    -- MSRP % sale out: CategoryMargins si existe; si no, default_msrp_pct_sale_out
    COALESCE((SELECT msrp_pct_sale_in  FROM cm),
             (1 - COALESCE((SELECT msrp_pct_sale_out FROM cm),
                           (SELECT default_msrp_pct_sale_out FROM cs),
                           0)
             )
    ) AS msrp_pct_sale_in,

    COALESCE((SELECT msrp_pct_sale_out FROM cm),
             (SELECT default_msrp_pct_sale_out FROM cs),
             0
    ) AS msrp_pct_sale_out
$$;


--
-- Name: msrp_recompute_for_category(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.msrp_recompute_for_category(p_category_id uuid, p_organization_id uuid DEFAULT NULL::uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
  v_item RECORD;
  v_count integer := 0;
  v_org_filter text;
BEGIN
  -- Construir filtro de organización si se proporciona
  IF p_organization_id IS NOT NULL THEN
    v_org_filter := format('AND organization_id = %L', p_organization_id);
  ELSE
    v_org_filter := '';
  END IF;

  -- Recalcular todos los items de la categoría (y subcategorías si aplica)
  FOR v_item IN
    EXECUTE format('
      SELECT id
      FROM public."CatalogItems"
      WHERE category_id = $1
        AND cost_exw > 0
        AND organization_id IS NOT NULL
        %s
    ', v_org_filter)
    USING p_category_id
  LOOP
    BEGIN
      PERFORM public.msrp_compute_for_item(v_item.id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
    END;
  END LOOP;

  RETURN v_count;
END;
$_$;


--
-- Name: FUNCTION msrp_recompute_for_category(p_category_id uuid, p_organization_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.msrp_recompute_for_category(p_category_id uuid, p_organization_id uuid) IS 'Recalcula MSRP para todos los CatalogItems de una categoría. Útil cuando cambian ImportTaxRules o CategoryMargins.';


--
-- Name: next_company_no(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_company_no(p_org_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_next_no integer;
BEGIN
  -- Atomically increment next_company_no and get the new value
  UPDATE public."Organizations"
  SET next_company_no = next_company_no + 1
  WHERE id = p_org_id
  RETURNING next_company_no INTO v_next_no;
  
  -- If organization not found, raise error
  IF v_next_no IS NULL THEN
    RAISE EXCEPTION 'Organization % not found', p_org_id;
  END IF;
  
  -- Return sequential number as text (e.g., "1", "2", "3")
  RETURN v_next_no::text;
END;
$$;


--
-- Name: FUNCTION next_company_no(p_org_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.next_company_no(p_org_id uuid) IS 'Atomically increments Organizations.next_company_no and returns sequential company number as text. Used by trigger on Companies insert. SECURITY DEFINER to avoid RLS recursion.';


--
-- Name: on_quote_approved_create_sales_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_quote_approved_create_sales_order() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_so_id uuid;
  v_so_no text;
begin
  if new.status = 'approved' and old.status is distinct from new.status then

    if not exists (
      select 1 from "SalesOrders"
      where quote_id = new.id and deleted = false
    ) then

      v_so_no := 'SO-' || to_char(now(),'YYMMDD') || '-' ||
                 substr(replace(gen_random_uuid()::text,'-',''),1,6);

      insert into "SalesOrders" (
        organization_id,
        quote_id,
        sales_order_no
      ) values (
        new.organization_id,
        new.id,
        v_so_no
      )
      returning id into v_so_id;

      insert into "OrderList" (
        organization_id,
        sales_order_id
      ) values (
        new.organization_id,
        v_so_id
      );

      update "Quotes"
      set tracking_status = 'pending_confirmation'
      where id = new.id;
    end if;
  end if;

  return new;
end;
$$;


--
-- Name: on_sales_order_status_mirror(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.on_sales_order_status_mirror() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  update "OrderList"
  set tracking_status = new.tracking_status
  where sales_order_id = new.id
    and deleted = false;

  update "Quotes"
  set tracking_status = new.tracking_status
  where id = new.quote_id
    and status = 'approved'
    and deleted = false;

  return new;
end;
$$;


--
-- Name: quote_lines_set_company_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quote_lines_set_company_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.company_id is null and new.quote_id is not null then
    select q.company_id
      into new.company_id
    from public."Quotes" q
    where q.id = new.quote_id
      and q.organization_id = new.organization_id
    limit 1;
  end if;

  return new;
end;
$$;


--
-- Name: quote_lines_validate_company(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.quote_lines_validate_company() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_quote_company uuid;
begin
  if new.quote_id is null then
    return new;
  end if;

  select q.company_id
    into v_quote_company
  from public."Quotes" q
  where q.id = new.quote_id
    and q.organization_id = new.organization_id
  limit 1;

  -- si el quote no existe (o no matchea org), bloquear
  if v_quote_company is null then
    raise exception 'QuoteLines: quote_id % has no company_id (or quote not found) for org %',
      new.quote_id, new.organization_id;
  end if;

  -- si alguien manda company_id distinto al del quote, bloquear
  if new.company_id is not null and new.company_id <> v_quote_company then
    raise exception 'QuoteLines: company_id % does not match Quotes.company_id % for quote %',
      new.company_id, v_quote_company, new.quote_id;
  end if;

  -- si viene null, se lo ponemos (por si el otro trigger no corrió por orden)
  if new.company_id is null then
    new.company_id := v_quote_company;
  end if;

  return new;
end;
$$;


--
-- Name: rebuild_catalogitem_conversions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rebuild_catalogitem_conversions(p_org uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  if p_org is null then
    truncate table public."CatalogItemConversions";
  else
    delete from public."CatalogItemConversions" where organization_id = p_org;
  end if;

  insert into public."CatalogItemConversions" (
    catalog_item_id,
    organization_id,
    cost_exw_input,
    unit_of_measure_input,
    roll_width_input,
    cost_exw_per_m,
    cost_exw_per_m2,
    computed_at
  )
  select
    ci.id,
    ci.organization_id,
    ci.cost_exw,
    ci.unit_of_measure,
    ci.roll_width,
    c.cost_exw_per_m,
    c.cost_exw_per_m2,
    now()
  from public."CatalogItems" ci
  cross join lateral public.compute_roll_conversions(ci.cost_exw, ci.unit_of_measure, ci.roll_width) c
  where coalesce(ci.is_roll,false) = true
    and (p_org is null or ci.organization_id = p_org);
end;
$$;


--
-- Name: recompute_catalog_item_msrp(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recompute_catalog_item_msrp(p_organization_id uuid, p_catalog_item_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_cost_exw numeric;
  v_category_id uuid;
  v_unit_of_measure text;

  v_shipping_pct numeric := 0;
  v_import_tax_pct numeric := 0;

  v_min_margin_pct numeric := 0.35;
  v_msrp_pct_sale_out numeric := 0.65;

  v_material_cost numeric := 0;
  v_shipping_cost numeric := 0;
  v_import_tax_cost numeric := 0;
  v_total_cost numeric := 0;

  v_dealer_price numeric := 0;
  v_msrp numeric := 0;
BEGIN
  SELECT ci.cost_exw, ci.category_id, ci.unit_of_measure
    INTO v_cost_exw, v_category_id, v_unit_of_measure
  FROM public."CatalogItems" ci
  WHERE ci.id = p_catalog_item_id;

  IF v_cost_exw IS NULL THEN
    v_cost_exw := 0;
  END IF;

  IF v_unit_of_measure IS NULL OR v_unit_of_measure = '' THEN
    v_unit_of_measure := 'ea';
  END IF;

  -- Load defaults from CostSettings
  SELECT
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, 0),
    COALESCE(cs.minimum_margin_pct, cs.default_margin_pct, v_min_margin_pct),
    COALESCE(cs.msrp_pct_sale_out, v_msrp_pct_sale_out)
  INTO
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_out
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_organization_id
  LIMIT 1;

  -- Override with CategoryMargins when present
  IF v_category_id IS NOT NULL THEN
    SELECT
      COALESCE(cm.minimum_margin_pct, v_min_margin_pct),
      COALESCE(cm.msrp_pct_sale_out, v_msrp_pct_sale_out)
    INTO
      v_min_margin_pct,
      v_msrp_pct_sale_out
    FROM public."CategoryMargins" cm
    WHERE cm.organization_id = p_organization_id
      AND cm.category_id = v_category_id
    LIMIT 1;
  END IF;

  v_material_cost := v_cost_exw;
  v_shipping_cost := v_material_cost * v_shipping_pct;
  v_import_tax_cost := (v_material_cost + v_shipping_cost) * v_import_tax_pct;
  v_total_cost := v_material_cost + v_shipping_cost + v_import_tax_cost;

  -- Dealer and MSRP formulas (dealer-based MSRP)
  v_dealer_price := round(v_total_cost / NULLIF(1 - v_min_margin_pct, 0), 4);
  v_msrp := round(v_dealer_price / NULLIF(1 - v_msrp_pct_sale_out, 0), 4);

  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    unit_of_measure,
    cost_exw,
    shipping_pct,
    import_tax_pct,
    minimum_margin_pct,
    msrp_pct_sale_out,

    shipping_cost,
    import_tax_cost,
    total_cost,
    dealer_price,
    msrp,
    updated_at
  )
  VALUES (
    p_organization_id,
    p_catalog_item_id,
    v_unit_of_measure,
    v_cost_exw,
    v_shipping_pct,
    v_import_tax_pct,
    v_min_margin_pct,
    v_msrp_pct_sale_out,

    v_shipping_cost,
    v_import_tax_cost,
    v_total_cost,
    v_dealer_price,
    v_msrp,
    now()
  )
  ON CONFLICT (organization_id, catalog_item_id)
  DO UPDATE SET
    unit_of_measure = EXCLUDED.unit_of_measure,
    cost_exw = EXCLUDED.cost_exw,
    shipping_pct = EXCLUDED.shipping_pct,
    import_tax_pct = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out = EXCLUDED.msrp_pct_sale_out,
    shipping_cost = EXCLUDED.shipping_cost,
    import_tax_cost = EXCLUDED.import_tax_cost,
    total_cost = EXCLUDED.total_cost,
    dealer_price = EXCLUDED.dealer_price,
    msrp = EXCLUDED.msrp,
    updated_at = now();
END;
$$;


--
-- Name: FUNCTION recompute_catalog_item_msrp(p_organization_id uuid, p_catalog_item_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.recompute_catalog_item_msrp(p_organization_id uuid, p_catalog_item_id uuid) IS 'Recompute CatalogItemsMSRP for one item.
Rule:
- dealer_price = total_cost / (1 - minimum_margin_pct)
- msrp = dealer_price / (1 - msrp_pct_sale_out)';


--
-- Name: recompute_catalogitems_msrp_for_category(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recompute_catalogitems_msrp_for_category(p_org_id uuid, p_category_id uuid) RETURNS void
    LANGUAGE sql
    AS $$
  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    category_id,
    sku,
    name,
    collection_name,
    variant_name,
    unit_of_measure,
    cost_exw,
    shipping_pct,
    import_tax_pct,
    minimum_margin_pct,
    msrp_pct_sale_out,
    shipping_cost,
    import_tax_cost,
    total_cost,
    dealer_price,
    msrp,
    updated_at
  )
  SELECT
    p_org_id,
    ci.id,
    ci.category_id,
    ci.sku,
    ci.name,
    ci.collection_name,
    ci.variant_name,
    ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(rates.shipping_pct, 0),
    COALESCE(rates.import_tax_pct, 0),
    COALESCE(rates.minimum_margin_pct, 0.35),
    COALESCE(rates.msrp_pct_sale_out, 0.65),
    round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) as shipping_cost,
    round(
      (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
      * COALESCE(rates.import_tax_pct, 0),
      4
    ) as import_tax_cost,
    round(
      COALESCE(ci.cost_exw, 0) +
      round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
      round(
        (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
        * COALESCE(rates.import_tax_pct, 0),
        4
      ),
      4
    ) as total_cost,
    round(
      (COALESCE(ci.cost_exw, 0) +
       round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
       round(
         (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
         * COALESCE(rates.import_tax_pct, 0),
         4
       ))
      / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0),
      4
    ) as dealer_price,
    round(
      round(
        (COALESCE(ci.cost_exw, 0) +
         round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4) +
         round(
           (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(rates.shipping_pct, 0), 4))
           * COALESCE(rates.import_tax_pct, 0),
           4
         ))
        / NULLIF(1 - COALESCE(rates.minimum_margin_pct, 0.35), 0),
        4
      )
      / NULLIF(1 - COALESCE(rates.msrp_pct_sale_out, 0.65), 0),
      4
    ) as msrp,
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public.msrp_get_effective_rates(p_org_id, ci.category_id) rates ON true
  WHERE ci.organization_id = p_org_id
    AND ci.category_id = p_category_id
    AND ci.is_active = true
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw           = EXCLUDED.cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out  = EXCLUDED.msrp_pct_sale_out,
    shipping_cost      = EXCLUDED.shipping_cost,
    import_tax_cost    = EXCLUDED.import_tax_cost,
    total_cost         = EXCLUDED.total_cost,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
$$;


--
-- Name: recompute_catalogitems_msrp_for_org(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recompute_catalogitems_msrp_for_org(p_org uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    organization_id,
    catalog_item_id,
    category_id,
    sku,
    name,
    collection_name,
    variant_name,
    unit_of_measure,
    cost_exw,
    shipping_pct,
    import_tax_pct,
    minimum_margin_pct,
    msrp_pct_sale_out,
    shipping_cost,
    import_tax_cost,
    total_cost,
    dealer_price,
    msrp,
    updated_at
  )
  SELECT
    ci.organization_id,
    ci.id,
    ci.category_id,
    ci.sku,
    ci.name,
    ci.collection_name,
    ci.variant_name,
    ci.unit_of_measure,
    COALESCE(ci.cost_exw, 0),
    COALESCE(cs.shipping_pct, 0),
    COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
    COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35),
    COALESCE(cm.msrp_pct_sale_out, cs.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65),

    round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4),
    round(
      (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
      * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
      4
    ),
    round(
      COALESCE(ci.cost_exw, 0) +
      round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
      round(
        (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
        * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
        4
      ),
      4
    ),
    round(
      (COALESCE(ci.cost_exw, 0) +
       round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
       round(
         (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
         * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
         4
       ))
      / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35), 0),
      4
    ),
    round(
      round(
        (COALESCE(ci.cost_exw, 0) +
         round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4) +
         round(
           (COALESCE(ci.cost_exw, 0) + round(COALESCE(ci.cost_exw, 0) * COALESCE(cs.shipping_pct, 0), 4))
           * COALESCE(cs.import_tax_pct, cs.global_import_tax_pct, 0),
           4
         ))
        / NULLIF(1 - COALESCE(cm.minimum_margin_pct, cs.minimum_margin_pct, cs.default_margin_pct, 0.35), 0),
        4
      )
      / NULLIF(1 - COALESCE(cm.msrp_pct_sale_out, cs.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65), 0),
      4
    ),
    now()
  FROM public."CatalogItems" ci
  LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
  LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id AND cm.category_id = ci.category_id
  WHERE ci.organization_id = p_org
    AND ci.is_active = true
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw           = EXCLUDED.cost_exw,
    shipping_pct       = EXCLUDED.shipping_pct,
    import_tax_pct     = EXCLUDED.import_tax_pct,
    minimum_margin_pct = EXCLUDED.minimum_margin_pct,
    msrp_pct_sale_out  = EXCLUDED.msrp_pct_sale_out,
    shipping_cost      = EXCLUDED.shipping_cost,
    import_tax_cost    = EXCLUDED.import_tax_cost,
    total_cost         = EXCLUDED.total_cost,
    dealer_price       = EXCLUDED.dealer_price,
    msrp               = EXCLUDED.msrp,
    updated_at         = now();
END;
$$;


--
-- Name: resolve_catalog_item_for_bom_component(uuid, uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_catalog_item_for_bom_component(p_org_id uuid, p_quote_line_id uuid, p_component_role text, p_component_item_id uuid) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_color text := public.get_quote_line_option_value(p_org_id, p_quote_line_id, 'hardware_color');
  v_collection text;
  v_variant text;
  v_id uuid;
BEGIN
  -- 1) SKU fijo
  IF p_component_item_id IS NOT NULL THEN
    RETURN p_component_item_id;
  END IF;

  -- 2) Tela (roll) por collection+variant en QuoteLines
  IF p_component_role = 'fabric' THEN
    SELECT ql.collection_name, ql.variant_name
      INTO v_collection, v_variant
    FROM public."QuoteLines" ql
    WHERE ql.organization_id = p_org_id
      AND ql.id = p_quote_line_id;

    SELECT ci.id INTO v_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.deleted = false
      AND ci.is_roll = true
      AND ci.collection_name = v_collection
      AND ci.variant_name = v_variant
    LIMIT 1;

    IF v_id IS NULL THEN
      RAISE EXCEPTION 'No fabric roll found for collection=% variant=% (QuoteLine %)', v_collection, v_variant, p_quote_line_id;
    END IF;

    RETURN v_id;
  END IF;

  -- 3) Hardware por role + color (si existe)
  IF v_color IS NOT NULL THEN
    SELECT ci.id INTO v_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.deleted = false
      AND ci.item_role = p_component_role
      AND ci.color = v_color
    ORDER BY ci.updated_at DESC
    LIMIT 1;

    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

  -- 4) Fallback por role sin color
  SELECT ci.id INTO v_id
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = p_org_id
    AND ci.deleted = false
    AND ci.item_role = p_component_role
  ORDER BY ci.updated_at DESC
  LIMIT 1;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'No CatalogItem found for role=% (QuoteLine %)', p_component_role, p_quote_line_id;
  END IF;

  RETURN v_id;
END;
$$;


--
-- Name: resolve_component_item_id(uuid, text, text, uuid, jsonb, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_component_item_id(p_org_id uuid, p_component_role text, p_sku_rule text, p_quote_line_id uuid, p_config jsonb, p_fixed_component_item_id uuid, p_override_item_id uuid) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_item_id uuid;
  v_hw_color text;
  v_ql public."QuoteLines";
BEGIN
  -- fixed or override
  IF p_override_item_id IS NOT NULL THEN
    RETURN p_override_item_id;
  END IF;

  IF p_fixed_component_item_id IS NOT NULL THEN
    RETURN p_fixed_component_item_id;
  END IF;

  SELECT * INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id
    AND organization_id = p_org_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  IF p_sku_rule = 'FABRIC_BY_COLLECTION_VARIANT' OR p_component_role = 'fabric' THEN
    IF v_ql.collection_name IS NULL OR v_ql.variant_name IS NULL THEN
      RAISE EXCEPTION 'Missing collection_name/variant_name on QuoteLine %', p_quote_line_id;
    END IF;

    SELECT ci.id INTO v_item_id
    FROM public."CatalogItems" ci
    WHERE ci.organization_id = p_org_id
      AND ci.is_roll = true
      AND ci.collection_name = v_ql.collection_name
      AND ci.variant_name = v_ql.variant_name
      AND ci.is_active = true
    LIMIT 1;

    IF v_item_id IS NULL THEN
      RAISE EXCEPTION 'No roll CatalogItem found for collection %, variant %',
        v_ql.collection_name, v_ql.variant_name;
    END IF;

    RETURN v_item_id;
  END IF;

  -- hardware: ROLE_AND_COLOR
  v_hw_color := NULL;

  -- expect config has a row 'hardware_color': {"hardware_color":"White"}
  IF (p_config ? 'hardware_color') THEN
    v_hw_color := NULLIF(p_config#>>ARRAY['hardware_color','hardware_color'], '');
  END IF;

  IF v_hw_color IS NULL THEN
    RAISE EXCEPTION 'hardware_color is required to resolve role %', p_component_role;
  END IF;

  -- Resolve uniquely
  SELECT ci.id INTO v_item_id
  FROM public."CatalogItems" ci
  WHERE ci.organization_id = p_org_id
    AND ci.is_roll = false
    AND ci.item_role = p_component_role
    AND ci.color = v_hw_color
    AND ci.is_active = true
  LIMIT 2;

  IF v_item_id IS NULL THEN
    RAISE EXCEPTION 'No hardware CatalogItem found for role % with color %', p_component_role, v_hw_color;
  END IF;

  -- Ambiguity check (LIMIT 2 trick)
  IF (SELECT COUNT(*) FROM public."CatalogItems" ci
      WHERE ci.organization_id = p_org_id
        AND ci.is_roll = false
        AND ci.item_role = p_component_role
        AND ci.color = v_hw_color
        AND ci.is_active = true) > 1 THEN
    RAISE EXCEPTION 'Ambiguous match for role % and color %; add more filters (manufacturer/system) or normalize catalog', p_component_role, v_hw_color;
  END IF;

  RETURN v_item_id;
END $$;


--
-- Name: FUNCTION resolve_component_item_id(p_org_id uuid, p_component_role text, p_sku_rule text, p_quote_line_id uuid, p_config jsonb, p_fixed_component_item_id uuid, p_override_item_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.resolve_component_item_id(p_org_id uuid, p_component_role text, p_sku_rule text, p_quote_line_id uuid, p_config jsonb, p_fixed_component_item_id uuid, p_override_item_id uuid) IS 'LEGACY function. Uses sku_resolution_rule heuristics (ROLE_AND_COLOR, etc). 
New BOM generation uses explicit user selections (QuoteLineComponents kind=selection). 
Kept for backward compatibility.';


--
-- Name: resolve_quote_line_product_type_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_quote_line_product_type_id(p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
  v_org_id uuid;
  v_catalog_item_id uuid;
  v_product_type_code text;
  v_product_type_id uuid;
  has_ptid boolean;
BEGIN
  -- ¿QuoteLines tiene product_type_id?
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='QuoteLines'
      AND column_name='product_type_id'
  ) INTO has_ptid;

  -- Leer QuoteLine base (siempre)
  SELECT organization_id,
         catalog_item_id,
         product_type
  INTO v_org_id, v_catalog_item_id, v_product_type_code
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine not found %', p_quote_line_id;
  END IF;

  -- 1) Si existe QuoteLines.product_type_id úsalo
  IF has_ptid THEN
    EXECUTE 'SELECT product_type_id FROM public."QuoteLines" WHERE id = $1'
      INTO v_product_type_id
      USING p_quote_line_id;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  -- 2) Intentar por ProductTypes.code = QuoteLines.product_type (texto)
  IF to_regclass('public."ProductTypes"') IS NOT NULL AND v_product_type_code IS NOT NULL AND btrim(v_product_type_code) <> '' THEN
    EXECUTE 'SELECT id FROM public."ProductTypes" WHERE organization_id = $1 AND code = $2 LIMIT 1'
      INTO v_product_type_id
      USING v_org_id, v_product_type_code;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  -- 3) Resolver por CatalogItemProductTypes (la que tú tienes)
  IF to_regclass('public."CatalogItemProductTypes"') IS NOT NULL AND v_catalog_item_id IS NOT NULL THEN
    EXECUTE 'SELECT product_type_id
             FROM public."CatalogItemProductTypes"
             WHERE organization_id = $1 AND catalog_item_id = $2
             ORDER BY created_at DESC NULLS LAST
             LIMIT 1'
      INTO v_product_type_id
      USING v_org_id, v_catalog_item_id;

    IF v_product_type_id IS NOT NULL THEN
      RETURN v_product_type_id;
    END IF;
  END IF;

  RAISE EXCEPTION 'Cannot resolve product_type_id for QuoteLine % (org %, catalog_item %, product_type "%")',
    p_quote_line_id, v_org_id, v_catalog_item_id, v_product_type_code;
END;
$_$;


--
-- Name: save_quote_line_cost_snapshot(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_quote_line_cost_snapshot(p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_org_id uuid;
  v_quote_id uuid;
  v_result record;
  v_snapshot_id uuid;
BEGIN
  -- 1. Obtener org y quote
  SELECT organization_id, quote_id
  INTO v_org_id, v_quote_id
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  -- 2. Calcular costo (tu función que YA funciona)
  SELECT *
  INTO v_result
  FROM public.compute_quote_line_cost(
    p_quote_line_id,
    '{}'::jsonb
  );

  -- 3. Guardar snapshot
  INSERT INTO public."QuoteLineCosts" (
    organization_id,
    quote_id,
    quote_line_id,

    quantity,
    cost_exw,
    material_cost,

    labor_pct,
    labor_cost,

    shipping_pct,
    shipping_cost,

    import_tax_pct,
    import_tax_cost,

    total_cost
  )
  VALUES (
    v_org_id,
    v_quote_id,
    p_quote_line_id,

    v_result.quantity,
    v_result.cost_exw,
    v_result.material_cost,

    v_result.labor_pct,
    v_result.labor_cost,

    v_result.shipping_pct,
    v_result.shipping_cost,

    v_result.import_tax_pct,
    v_result.import_tax_cost,

    v_result.total_cost
  )
  RETURNING id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$;


--
-- Name: save_quote_line_prices_snapshot(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_quote_line_prices_snapshot(p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_cost record;
  v_q  record;
  v_default_margin numeric := 0.65; -- fallback si viene null
  v_discount_pct   numeric := 0;    -- fallback si viene null
  v_margin_pct     numeric;
  v_msrp           numeric;
  v_net_price      numeric;
  v_version        int;
BEGIN
  -- 1) Tomar la QuoteLine actual
  SELECT
    ql.id,
    ql.default_margin_pct,
    ql.discount_pct,
    ql.pricing_version
  INTO v_q
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  -- 2) Tomar el último snapshot de costo
  SELECT *
  INTO v_cost
  FROM public."QuoteLineCosts"
  WHERE quote_line_id = p_quote_line_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No QuoteLineCosts snapshot for QuoteLine %', p_quote_line_id;
  END IF;

  -- 3) Margin / discount
  v_margin_pct   := COALESCE(v_q.default_margin_pct, v_default_margin);
  v_discount_pct := COALESCE(v_q.discount_pct, v_discount_pct);

  -- 4) MSRP basado en costo total / (1 - margin)
  v_msrp := round(v_cost.total_cost / nullif(1 - v_margin_pct, 0), 4);

  -- 5) Net price = MSRP * (1 - discount)
  v_net_price := round(v_msrp * (1 - v_discount_pct), 4);

  -- 6) Bump pricing_version
  v_version := COALESCE(v_q.pricing_version, 0) + 1;

  -- 7) Guardar en QuoteLines (snapshot final de precios)
  UPDATE public."QuoteLines"
  SET
    msrp = v_msrp,
    net_price = v_net_price,
    pricing_version = v_version,
    pricing_locked = true,
    last_priced_at = now(),
    updated_at = now()
  WHERE id = p_quote_line_id;

  RETURN p_quote_line_id;
END;
$$;


--
-- Name: select_best_bom_template(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_best_bom_template(p_org_id uuid, p_product_type_id uuid, p_config jsonb) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_template_id uuid;
BEGIN
  SELECT t.id
  INTO v_template_id
  FROM public."BOMTemplates" t
  WHERE t.organization_id = p_org_id
    AND t.product_type_id = p_product_type_id
    AND t.archived = false
    AND t.is_active = true
  ORDER BY
    COALESCE((t.metadata->>'priority')::int, 0) DESC,
    t.updated_at DESC
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE EXCEPTION
      'No BOMTemplate found for org %, product_type %',
      p_org_id, p_product_type_id;
  END IF;

  RETURN v_template_id;
END;
$$;


--
-- Name: select_best_bom_template_for_configured_product(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_best_bom_template_for_configured_product(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_template_id uuid;
    v_hardware_color text;
    v_selected_bottom_bar_sku text;
    v_selected_headbox_sku text;
    v_selected_side_channel_sku text;
    v_selected_bottom_channel_sku text;
    v_selected_motor_sku text;
    v_selected_drive_sku text;
    v_selected_tube_sku text;
    v_operating_type text; -- 'motor' o 'manual'
    v_matching_count integer;
    v_debug_info text;
    v_match_score integer;
BEGIN
    -- Extraer valores del config_snapshot
    v_hardware_color := p_config_snapshot->>'hardware_color';
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'hardwareColor';
    END IF;
    IF v_hardware_color IS NULL THEN
        v_hardware_color := p_config_snapshot->>'operatingSystemColor';
    END IF;
    
    -- Normalizar hardware_color (capitalize first letter)
    IF v_hardware_color IS NOT NULL THEN
        v_hardware_color := UPPER(SUBSTRING(v_hardware_color, 1, 1)) || LOWER(SUBSTRING(v_hardware_color, 2));
    END IF;
    
    v_selected_bottom_bar_sku := p_config_snapshot->>'bottom_bar_sku';
    v_selected_headbox_sku := p_config_snapshot->>'headbox_sku';
    v_selected_side_channel_sku := p_config_snapshot->>'side_channel_sku';
    v_selected_bottom_channel_sku := p_config_snapshot->>'bottom_channel_sku';
    v_selected_motor_sku := p_config_snapshot->>'motor_sku';
    v_selected_drive_sku := p_config_snapshot->>'drive_sku';
    v_selected_tube_sku := p_config_snapshot->>'tube_sku';
    
    -- ✅ CRITICAL: Determinar Operating Type (obligatorio)
    -- Si hay motor_sku, operating_type = 'motor'
    -- Si hay drive_sku, operating_type = 'manual'
    -- NO pueden estar ambos
    IF v_selected_motor_sku IS NOT NULL AND v_selected_drive_sku IS NOT NULL THEN
        RAISE WARNING 'Invalid config: both motor_sku and drive_sku are set. Only one should be set.';
        -- Preferir motor si ambos están presentes
        v_operating_type := 'motor';
        v_selected_drive_sku := NULL;
    ELSIF v_selected_motor_sku IS NOT NULL THEN
        v_operating_type := 'motor';
    ELSIF v_selected_drive_sku IS NOT NULL THEN
        v_operating_type := 'manual';
    ELSE
        v_operating_type := NULL;
    END IF;

    -- ✅ DEBUG: Log valores extraídos
    v_debug_info := format(
        'Config snapshot: hardware_color=%s, operating_type=%s, bottom_bar_sku=%s, headbox_sku=%s, motor_sku=%s, drive_sku=%s, tube_sku=%s, side_channel_sku=%s, bottom_channel_sku=%s',
        v_hardware_color,
        v_operating_type,
        v_selected_bottom_bar_sku,
        v_selected_headbox_sku,
        v_selected_motor_sku,
        v_selected_drive_sku,
        v_selected_tube_sku,
        v_selected_side_channel_sku,
        v_selected_bottom_channel_sku
    );
    RAISE NOTICE '%', v_debug_info;

    -- ✅ FILTRADO PROGRESIVO: Buscar templates que coincidan EXACTAMENTE
    -- OBLIGATORIOS primero, luego OPCIONALES
    -- Usar subquery para calcular score y ordenar
    WITH scored_templates AS (
        SELECT bt.id,
               bt.hardware_color,
               bt.metadata,
               bt.updated_at,
               -- Calcular score: más coincidencias = mejor
               (CASE WHEN v_hardware_color IS NOT NULL 
                          AND LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_bar_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_bar'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_tube_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'tube'
                                        AND TRIM(ci.sku) = TRIM(v_selected_tube_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'motor' AND v_selected_motor_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'motor'
                                        AND TRIM(ci.sku) = TRIM(v_selected_motor_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_operating_type = 'manual' AND v_selected_drive_sku IS NOT NULL
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'drive'
                                        AND TRIM(ci.sku) = TRIM(v_selected_drive_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_headbox_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'headbox'
                                        AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_side_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'side_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku))
                     THEN 1 ELSE 0 END) +
               (CASE WHEN v_selected_bottom_channel_sku IS NOT NULL 
                          AND EXISTS (SELECT 1 FROM "public"."BOMTemplateSlots" bts
                                      JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                                      WHERE bts.bom_template_id = bt.id
                                        AND bts.organization_id = p_org_id
                                        AND bts.item_role = 'bottom_channel'
                                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku))
                     THEN 1 ELSE 0 END) AS match_score
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false
            -- ✅ OBLIGATORIO 1: hardware_color debe coincidir EXACTAMENTE
            AND (
                v_hardware_color IS NULL 
                OR LOWER(TRIM(COALESCE(bt.hardware_color, ''))) = LOWER(TRIM(v_hardware_color))
            )
            -- ✅ OBLIGATORIO 2: Bottom Bar SKU debe coincidir EXACTAMENTE
            AND (
                v_selected_bottom_bar_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'bottom_bar'
                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_bar_sku)
                )
            )
            -- ✅ OBLIGATORIO 3: Tube SKU debe coincidir EXACTAMENTE
            AND (
                v_selected_tube_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'tube'
                        AND TRIM(ci.sku) = TRIM(v_selected_tube_sku)
                )
            )
            -- ✅ OBLIGATORIO 4: Operating Type (motor O drive, no ambos)
            AND (
                v_operating_type IS NULL
                OR (
                    v_operating_type = 'motor' 
                    AND v_selected_motor_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                    -- ✅ Validar que NO tenga drive_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                )
                OR (
                    v_operating_type = 'manual' 
                    AND v_selected_drive_sku IS NOT NULL
                    AND EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'drive'
                            AND TRIM(ci.sku) = TRIM(v_selected_drive_sku)
                    )
                    -- ✅ Validar que NO tenga motor_sku (no puede tener ambos)
                    AND NOT EXISTS (
                        SELECT 1 FROM "public"."BOMTemplateSlots" bts
                        JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                        WHERE bts.bom_template_id = bt.id
                            AND bts.organization_id = p_org_id
                            AND bts.item_role = 'motor'
                            AND TRIM(ci.sku) = TRIM(v_selected_motor_sku)
                    )
                )
            )
            -- ✅ OPCIONAL 1: Headbox SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_headbox_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'headbox'
                        AND TRIM(ci.sku) = TRIM(v_selected_headbox_sku)
                )
            )
            -- ✅ OPCIONAL 2: Side Channel SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_side_channel_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'side_channel'
                        AND TRIM(ci.sku) = TRIM(v_selected_side_channel_sku)
                )
            )
            -- ✅ OPCIONAL 3: Bottom Channel SKU (si está seleccionado, debe coincidir)
            AND (
                v_selected_bottom_channel_sku IS NULL
                OR EXISTS (
                    SELECT 1 FROM "public"."BOMTemplateSlots" bts
                    JOIN "public"."CatalogItems" ci ON ci.id = bts.catalog_item_id
                    WHERE bts.bom_template_id = bt.id
                        AND bts.organization_id = p_org_id
                        AND bts.item_role = 'bottom_channel'
                        AND TRIM(ci.sku) = TRIM(v_selected_bottom_channel_sku)
                )
            )
    )
    SELECT st.id, st.match_score
    INTO v_template_id, v_match_score
    FROM scored_templates st
    ORDER BY 
        -- 1. Priorizar por score (más coincidencias primero) - CRÍTICO para desambiguar
        st.match_score DESC,
        -- 2. Priorizar templates que coincidan con hardware_color exacto
        CASE 
            WHEN v_hardware_color IS NOT NULL 
                 AND LOWER(TRIM(COALESCE(st.hardware_color, ''))) = LOWER(TRIM(v_hardware_color)) 
            THEN 0 
            ELSE 1 
        END,
        -- 3. Luego por priority en metadata
        COALESCE((st.metadata->>'priority')::int, 0) DESC,
        -- 4. Finalmente por updated_at (más reciente primero)
        st.updated_at DESC
    LIMIT 1;

    -- ✅ DEBUG: Si no se encontró template, log información de debugging
    IF v_template_id IS NULL THEN
        -- Contar templates disponibles para este product_type_id
        SELECT COUNT(*) INTO v_matching_count
        FROM "public"."BOMTemplates" bt
        WHERE bt.organization_id = p_org_id
            AND bt.product_type_id = p_product_type_id
            AND bt.deleted = false
            AND bt.archived = false;
        
        RAISE WARNING 'No BOMTemplate found for org=%, product_type_id=%, hardware_color=%, operating_type=%. Available templates for product_type: %. Config: %',
            p_org_id, p_product_type_id, v_hardware_color, v_operating_type, v_matching_count, v_debug_info;
    ELSE
        RAISE NOTICE 'BOMTemplate found: % (score: %) for org=%, product_type_id=%, hardware_color=%, operating_type=%',
            v_template_id, v_match_score, p_org_id, p_product_type_id, v_hardware_color, v_operating_type;
    END IF;

    RETURN v_template_id;
END;
$$;


--
-- Name: FUNCTION select_best_bom_template_for_configured_product(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.select_best_bom_template_for_configured_product(p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb) IS 'Selecciona el mejor BOMTemplate para una configuración con filtrado progresivo.
✅ FILTRADO PROGRESIVO:
- OBLIGATORIOS: ProductType, Color (hardware_color), Bottom Bar (bottom_bar_sku), Operating Type (motor_sku O drive_sku, no ambos), Tube (tube_sku)
- OPCIONALES: Headbox (headbox_sku), Side Channel (side_channel_sku), Bottom Channel (bottom_channel_sku)
✅ VALIDACIONES:
- SKUs deben coincidir EXACTAMENTE (trim, case-sensitive)
- hardware_color debe coincidir EXACTAMENTE (case-insensitive)
- Operating Type: motor O manual, no ambos
- No permite SKUs duplicados en el mismo template
✅ PRIORIZACIÓN:
- Ordena por score de coincidencias (más coincidencias = mejor)
- Luego por hardware_color exacto
- Luego por priority en metadata
- Finalmente por updated_at (más reciente primero)';


--
-- Name: select_best_bom_template_for_quote_line(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_best_bom_template_for_quote_line(p_org_id uuid, p_product_type_id uuid, p_quote_line_id uuid) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_best_template_id uuid;
  v_best_score int := -1;
  v_candidate RECORD;
  v_match_score int;
  v_user_roles text[];
BEGIN
  -- 1. Obtener roles seleccionados por el usuario (kind='selection')
  SELECT ARRAY_AGG(DISTINCT qlc.component_role) INTO v_user_roles
  FROM public."QuoteLineComponents" qlc
  WHERE qlc.organization_id = p_org_id
    AND qlc.quote_line_id = p_quote_line_id
    AND qlc.kind = 'selection'
    AND qlc.deleted = false;

  -- Si no hay roles seleccionados, usar array vacío
  v_user_roles := COALESCE(v_user_roles, ARRAY[]::text[]);

  -- 2. Buscar templates por product_type_id
  FOR v_candidate IN
    SELECT 
      bt.id,
      bt.updated_at,
      COALESCE((bt.metadata->>'priority')::int, 0) AS priority
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      priority DESC,
      bt.updated_at DESC
  LOOP
    -- 3. Score por coincidencias de roles
    SELECT COUNT(*) INTO v_match_score
    FROM public."BOMTemplateSlots" slots
    WHERE slots.organization_id = p_org_id
      AND slots.bom_template_id = v_candidate.id
      AND slots.item_role = ANY(v_user_roles);

    IF v_match_score > v_best_score THEN
      v_best_score := v_match_score;
      v_best_template_id := v_candidate.id;
    END IF;
  END LOOP;

  -- 4. Fallback: primer template por ProductType
  IF v_best_template_id IS NULL THEN
    SELECT bt.id INTO v_best_template_id
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org_id
      AND bt.product_type_id = p_product_type_id
      AND bt.deleted = false
      AND bt.archived = false
      AND bt.active = true
    ORDER BY 
      COALESCE((bt.metadata->>'priority')::int, 0) DESC,
      bt.updated_at DESC
    LIMIT 1;
  END IF;

  RETURN v_best_template_id;
END;
$$;


--
-- Name: FUNCTION select_best_bom_template_for_quote_line(p_org_id uuid, p_product_type_id uuid, p_quote_line_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.select_best_bom_template_for_quote_line(p_org_id uuid, p_product_type_id uuid, p_quote_line_id uuid) IS 'Selecciona el mejor BOMTemplate basado en:
1. ProductType (primer filtro)
2. Color (hardware_color, segundo filtro)
3. Comparación de selecciones SKU del usuario con slots del template (más coincidencias = mejor)';


--
-- Name: select_best_bom_template_v2(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_best_bom_template_v2(p_org uuid, p_product_type uuid, p_config jsonb) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  WITH cfg AS (
    SELECT COALESCE(p_config, '{}'::jsonb) AS c
  ),
  candidates AS (
    SELECT
      bt.id,
      bt.code,
      COALESCE(bt.metadata->'requires','{}'::jsonb) AS req
    FROM public."BOMTemplates" bt
    WHERE bt.organization_id = p_org
      AND bt.product_type_id = p_product_type
      AND bt.active = true
      AND bt.deleted = false
      AND bt.archived = false
  ),
  matched AS (
    SELECT c.id, c.code
    FROM candidates c, cfg
    WHERE
      -- config incluye todas las condiciones del requires (uuid o null)
      (cfg.c @> c.req)

      -- XOR: drive_id vs motor_id (exactamente uno existe en requires)
      AND (
        ( (c.req ? 'drive_id') AND NOT (c.req ? 'motor_id') )
        OR
        ( (c.req ? 'motor_id') AND NOT (c.req ? 'drive_id') )
      )
  )
  SELECT m.id
  FROM matched m
  ORDER BY m.code
  LIMIT 1;
$$;


--
-- Name: select_best_bom_template_v2_strict(uuid, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_best_bom_template_v2_strict(p_org uuid, p_product_type uuid, p_config jsonb) RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_id uuid;
BEGIN
  -- obligatorios roller (segun lo que me dijiste)
  IF NOT (p_config ? 'tube_id') OR (p_config->>'tube_id') IS NULL THEN
    RAISE EXCEPTION 'Missing tube_id in config';
  END IF;

  IF NOT (p_config ? 'bottom_bar_id') OR (p_config->>'bottom_bar_id') IS NULL THEN
    RAISE EXCEPTION 'Missing bottom_bar_id in config';
  END IF;

  -- XOR drive/motor
  IF (p_config ? 'drive_id') AND (p_config ? 'motor_id') THEN
    RAISE EXCEPTION 'Config cannot contain both drive_id and motor_id';
  END IF;

  IF NOT (p_config ? 'drive_id') AND NOT (p_config ? 'motor_id') THEN
    RAISE EXCEPTION 'Config must contain drive_id OR motor_id';
  END IF;

  SELECT public.select_best_bom_template_v2(p_org, p_product_type, p_config)
  INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'No BOMTemplate found for org %, product_type %', p_org, p_product_type;
  END IF;

  RETURN v_id;
END;
$$;


--
-- Name: set_company_no(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_company_no() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Only set company_no if it's null or empty
  IF NEW.company_no IS NULL OR TRIM(NEW.company_no) = '' THEN
    NEW.company_no := public.next_company_no(NEW.organization_id);
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION set_company_no(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_company_no() IS 'Trigger function to auto-assign company_no on Companies insert if not provided. Never recalculates existing company_no.';


--
-- Name: set_quote_line_company_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_quote_line_company_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- si no viene company_id, herédalo del Quote
  if new.company_id is null and new.quote_id is not null then
    select q.company_id
      into new.company_id
    from public."Quotes" q
    where q.id = new.quote_id
      and q.organization_id = new.organization_id
    limit 1;
  end if;

  return new;
end;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end $$;


--
-- Name: set_updated_at_product_type_role_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at_product_type_role_rules() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: sync_bom_template_slot_sku(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_bom_template_slot_sku() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_item_id uuid;
  v_sku text;
BEGIN
  v_item_id := COALESCE(NEW.fixed_catalog_item_id, NEW.catalog_item_id);
  IF v_item_id IS NULL THEN
    NEW.slot_sku := NULL;
    RETURN NEW;
  END IF;

  SELECT trim(ci.sku) INTO v_sku
  FROM public."CatalogItems" ci
  WHERE ci.id = v_item_id
    AND (ci.organization_id = NEW.organization_id OR ci.organization_id IS NULL)
  LIMIT 1;

  NEW.slot_sku := v_sku;
  RETURN NEW;
END;
$$;


--
-- Name: sync_catalogitem_collection_name_from_roll_collection(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_catalogitem_collection_name_from_roll_collection() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v_name text;
begin
  if new.roll_collection_id is null then
    return new;
  end if;

  select name into v_name
  from public."CatalogRollCollections"
  where id = new.roll_collection_id;

  if v_name is not null then
    new.collection_name = v_name;
  end if;

  return new;
end;
$$;


--
-- Name: sync_catalogitems_manufacturer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_catalogitems_manufacturer() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_name text;
  v_id uuid;
BEGIN
  -- Normalize
  v_name := btrim(COALESCE(NEW.manufacturer, ''));

  -- If empty, keep manufacturer_id as-is (do not null it automatically)
  IF v_name = '' THEN
    RETURN NEW;
  END IF;

  -- Upsert Manufacturer row (case-insensitive)
  INSERT INTO public."Manufacturers"(organization_id, name)
  VALUES (NEW.organization_id, v_name)
  ON CONFLICT (organization_id, lower(name)) DO NOTHING;

  -- Fetch id
  SELECT id INTO v_id
  FROM public."Manufacturers"
  WHERE organization_id = NEW.organization_id
    AND lower(name) = lower(v_name)
  LIMIT 1;

  NEW.manufacturer_id := v_id;

  RETURN NEW;
END;
$$;


--
-- Name: sync_catalogitems_to_msrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_catalogitems_to_msrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id, organization_id, category_id,
    sku, name, collection_name, variant_name, unit_of_measure,
    cost_exw, shipping_cost, import_tax_cost, total_cost,
    dealer_price, msrp
  )
  VALUES (
    NEW.id, NEW.organization_id, NEW.category_id,
    NEW.sku, NEW.name, NEW.collection_name, NEW.variant_name, NEW.unit_of_measure,
    0, 0, 0, 0,
    0, 0
  )
  ON CONFLICT (catalog_item_id) DO UPDATE SET
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION sync_catalogitems_to_msrp(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_catalogitems_to_msrp() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with dealer_price=0, msrp=0 to satisfy NOT NULL.';


--
-- Name: sync_catalogitems_to_msrp_safe(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_catalogitems_to_msrp_safe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO public."CatalogItemsMSRP" (
    catalog_item_id,
    organization_id,
    category_id,

    cost_exw,
    shipping_cost,
    import_tax_cost,
    total_cost,

    dealer_price,
    msrp,

    sku,
    name,
    collection_name,
    variant_name,
    unit_of_measure,

    updated_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.category_id,

    COALESCE(NEW.cost_exw, 0),
    0,
    0,
    COALESCE(NEW.cost_exw, 0),

    0,
    0,

    NEW.sku,
    NEW.name,
    NEW.collection_name,
    NEW.variant_name,
    NEW.unit_of_measure,

    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    organization_id = EXCLUDED.organization_id,
    sku = EXCLUDED.sku,
    name = EXCLUDED.name,
    collection_name = EXCLUDED.collection_name,
    variant_name = EXCLUDED.variant_name,
    unit_of_measure = EXCLUDED.unit_of_measure,
    category_id = EXCLUDED.category_id,
    updated_at = now();

  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION sync_catalogitems_to_msrp_safe(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_catalogitems_to_msrp_safe() IS 'Sync identity (sku, name, collection_name, variant_name, unit_of_measure) from CatalogItems to CatalogItemsMSRP. If row does not exist, INSERT with minimal values. On UPDATE only touches identity, NOT cost_exw or total_cost (handled by msrp_compute_for_item).';


--
-- Name: sync_order_list_tracking_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_order_list_tracking_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Update OrderList.tracking_status to match SalesOrder
    UPDATE public."OrderList"
    SET 
        tracking_status = NEW.tracking_status,
        updated_at = now()
    WHERE sales_order_id = NEW.id
    AND deleted = false;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION sync_order_list_tracking_status(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_order_list_tracking_status() IS 'Trigger function: Syncs OrderList.tracking_status to match SalesOrders.tracking_status (mirror).';


--
-- Name: tg_set_company_id_from_portal_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tg_set_company_id_from_portal_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  v record;
begin
  -- if already provided, keep it
  if new.company_id is not null then
    return new;
  end if;

  -- if function exists, try to infer from portal user
  begin
    select * into v
    from public.get_current_portal_user();

    if v.id is not null then
      new.company_id := v.company_id;
    end if;

  exception
    when undefined_function then
      -- get_current_portal_user() not installed; do nothing
      null;
  end;

  return new;
end;
$$;


--
-- Name: trg_catalog_items_recompute_msrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_catalog_items_recompute_msrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.cost_exw is distinct from old.cost_exw then
    -- recalcula para el org del item
    perform public.recompute_catalog_item_msrp(new.organization_id, new.id);
  end if;
  return new;
end;
$$;


--
-- Name: trg_catalogitems_validate_roll_pricing_mode(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_catalogitems_validate_roll_pricing_mode() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- If it's a roll, it MUST have a pricing mode
  if coalesce(new.is_roll,false) = true then
    if new.roll_pricing_mode is null then
      new.roll_pricing_mode := 'per_linear_meter';
    end if;

    -- If priced per m2, roll_width must be present (>0)
    if new.roll_pricing_mode = 'per_square_meter' then
      if new.roll_width is null or new.roll_width <= 0 then
        raise exception 'roll_width is required (>0, meters) when roll_pricing_mode = per_square_meter';
      end if;
    end if;

  else
    -- Non-roll items should not carry roll pricing mode (keeps data clean)
    new.roll_pricing_mode := null;
  end if;

  return new;
end;
$$;


--
-- Name: trg_catalogitems_write_conversions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_catalogitems_write_conversions() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_per_m  numeric := NULL;
  v_per_m2 numeric := NULL;
  v_per_ea numeric := NULL;
  v_effective_width_m numeric := NULL;
BEGIN
  IF NEW.cost_exw IS NULL OR NEW.unit_of_measure IS NULL THEN
    RETURN NEW;
  END IF;

  -- =========================
  -- LINEAR ($/m)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('m','meter','meters') THEN
    v_per_m := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) = 'ft' THEN
    v_per_m := NEW.cost_exw / 0.3048;

  ELSIF lower(NEW.unit_of_measure) = 'yd' THEN
    v_per_m := NEW.cost_exw / 0.9144;
  END IF;

  -- =========================
  -- ROLL AREA ($/m2)
  -- =========================
  -- Use roll_width_m (normalized) if available, fallback to roll_width (legacy)
  IF coalesce(NEW.is_roll, false) = true AND v_per_m IS NOT NULL THEN
    v_effective_width_m := COALESCE(NEW.roll_width_m, NEW.roll_width);
    
    IF v_effective_width_m IS NOT NULL AND v_effective_width_m > 0 THEN
      v_per_m2 := v_per_m / v_effective_width_m;
    END IF;
  END IF;

  -- =========================
  -- UNIT ($/ea)
  -- =========================
  IF lower(NEW.unit_of_measure) IN ('ea','pcs','pc','unit','piece') THEN
    v_per_ea := NEW.cost_exw;

  ELSIF lower(NEW.unit_of_measure) IN ('pack','set','box','case','bag')
        AND NEW.units_per_purchase_unit IS NOT NULL
        AND NEW.units_per_purchase_unit > 0 THEN
    v_per_ea := NEW.cost_exw / NEW.units_per_purchase_unit;
  END IF;

  -- =========================
  -- UPSERT
  -- =========================
  INSERT INTO public."CatalogItemConversions" (
    catalog_item_id,
    organization_id,
    cost_exw_input,
    unit_of_measure_input,
    roll_width_input,
    cost_exw_per_m,
    cost_exw_per_m2,
    cost_exw_per_ea,
    computed_at
  )
  VALUES (
    NEW.id,
    NEW.organization_id,
    NEW.cost_exw,
    NEW.unit_of_measure,
    v_effective_width_m, -- Use normalized width for consistency
    v_per_m,
    v_per_m2,
    v_per_ea,
    now()
  )
  ON CONFLICT (catalog_item_id)
  DO UPDATE SET
    cost_exw_input = EXCLUDED.cost_exw_input,
    unit_of_measure_input = EXCLUDED.unit_of_measure_input,
    roll_width_input = EXCLUDED.roll_width_input,
    cost_exw_per_m = EXCLUDED.cost_exw_per_m,
    cost_exw_per_m2 = EXCLUDED.cost_exw_per_m2,
    cost_exw_per_ea = EXCLUDED.cost_exw_per_ea,
    computed_at = EXCLUDED.computed_at;

  RETURN NEW;
END;
$_$;


--
-- Name: trg_companies_set_company_no(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_companies_set_company_no() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.company_no is null or btrim(new.company_no) = '' then
    new.company_no := public.next_company_no(new.organization_id);
  end if;
  return new;
end;
$$;


--
-- Name: trg_quote_lines_generate_bom_instance_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_quote_lines_generate_bom_instance_fn() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
  v_product_type_id uuid;
BEGIN
  -- Solo en INSERT
  IF TG_OP = 'INSERT' THEN

    -- ✅ Resolver product_type_id
    -- 1) Si QuoteLines tiene product_type_id úsalo
    BEGIN
      EXECUTE 'SELECT ($1).product_type_id' INTO v_product_type_id USING NEW;
    EXCEPTION WHEN undefined_column THEN
      v_product_type_id := NULL;
    END;

    -- 2) Fallback: intenta por ConfiguredProducts si existe relación
    IF v_product_type_id IS NULL THEN
      BEGIN
        EXECUTE $q$
          SELECT cp.product_type_id
          FROM public."ConfiguredProducts" cp
          WHERE cp.id = ($1).configured_product_id
          LIMIT 1
        $q$ INTO v_product_type_id USING NEW;
      EXCEPTION WHEN undefined_column THEN
        v_product_type_id := NULL;
      END;
    END IF;

    -- 3) Fallback FINAL: primer template activo del org (si tienes un default)
    IF v_product_type_id IS NULL THEN
      SELECT bt.product_type_id
      INTO v_product_type_id
      FROM public."BOMTemplates" bt
      WHERE bt.organization_id = NEW.organization_id
        AND bt.deleted = false
        AND bt.archived = false
        AND bt.is_active = true
      ORDER BY COALESCE((bt.metadata->>'priority')::int, 0) DESC, bt.updated_at DESC
      LIMIT 1;
    END IF;

    IF v_product_type_id IS NULL THEN
      RAISE EXCEPTION 'Cannot generate BOMInstance: product_type_id could not be resolved for QuoteLine %', NEW.id;
    END IF;

    -- ✅ Llamada CORRECTA (3 params)
    PERFORM public.generate_bom_instance_for_quote_line(
      NEW.organization_id,
      NEW.id,
      v_product_type_id
    );
  END IF;

  RETURN NEW;
END;
$_$;


--
-- Name: trig_catmargins_msrp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_catmargins_msrp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_item_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF (OLD.msrp_pct_sale_in = NEW.msrp_pct_sale_in) 
       AND (OLD.msrp_pct_sale_out = NEW.msrp_pct_sale_out) THEN
      RETURN NEW;
    END IF;
  END IF;
  
  -- Recompute all items in this category
  FOR v_item_id IN
    SELECT id FROM public."CatalogItems"
    WHERE organization_id = NEW.organization_id
      AND category_id = NEW.category_id
      AND cost_exw IS NOT NULL AND cost_exw > 0
      AND is_active = true
  LOOP
    PERFORM "public"."msrp_compute_for_item"(v_item_id);
  END LOOP;
  
  RETURN NEW;
END;
$$;


--
-- Name: trig_enforce_msrp_sources(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_enforce_msrp_sources() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_org uuid;
  v_cat uuid;
  r record;
BEGIN
  v_org := NEW.organization_id;
  v_cat := NEW.category_id;

  IF v_org IS NULL OR v_cat IS NULL THEN
    SELECT organization_id, category_id INTO v_org, v_cat
    FROM public."CatalogItems"
    WHERE id = NEW.catalog_item_id;
    NEW.organization_id := COALESCE(NEW.organization_id, v_org);
    NEW.category_id := COALESCE(NEW.category_id, v_cat);
  END IF;

  IF NEW.organization_id IS NULL OR NEW.category_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO r
  FROM public.msrp_get_effective_rates(NEW.organization_id, NEW.category_id);

  NEW.shipping_pct       := COALESCE(r.shipping_pct, 0);
  NEW.import_tax_pct     := COALESCE(r.import_tax_pct, 0);
  NEW.minimum_margin_pct := COALESCE(r.minimum_margin_pct, 0);
  NEW.msrp_pct_sale_out  := COALESCE(r.msrp_pct_sale_out, 0);

  RETURN NEW;
END;
$$;


--
-- Name: trig_recompute_msrp_on_catalog_item_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_recompute_msrp_on_catalog_item_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR
     (TG_OP = 'UPDATE' AND (
       (OLD.cost_exw IS DISTINCT FROM NEW.cost_exw) OR
       (OLD.category_id IS DISTINCT FROM NEW.category_id)
     )) THEN
    -- Llamar siempre que organization_id exista (también con cost_exw=0; msrp_compute pone 0 en msrp_sale_in/out)
    PERFORM public.msrp_compute_for_item(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trig_recompute_msrp_on_category_margin_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_recompute_msrp_on_category_margin_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_count integer;
BEGIN
  -- Recalcular todos los items de la categoría afectada
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    v_count := public.msrp_recompute_for_category(NEW.category_id, NEW.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de cambio en CategoryMargins', v_count, NEW.category_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_count := public.msrp_recompute_for_category(OLD.category_id, OLD.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de eliminación en CategoryMargins', v_count, OLD.category_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: trig_recompute_msrp_on_cost_settings_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_recompute_msrp_on_cost_settings_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_item RECORD;
  v_count integer := 0;
BEGIN
  -- Solo recalcular si cambió shipping_pct o global_import_tax_pct
  IF (TG_OP = 'UPDATE' AND (
    (OLD.shipping_pct IS DISTINCT FROM NEW.shipping_pct) OR
    (OLD.global_import_tax_pct IS DISTINCT FROM NEW.global_import_tax_pct)
  )) OR (TG_OP = 'INSERT') THEN
    -- Recalcular todos los items de la organización
    FOR v_item IN
      SELECT id
      FROM public."CatalogItems"
      WHERE organization_id = NEW.organization_id
        AND cost_exw > 0
    LOOP
      BEGIN
        PERFORM public.msrp_compute_for_item(v_item.id);
        v_count := v_count + 1;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE WARNING 'Error recalculando item %: %', v_item.id, SQLERRM;
      END;
    END LOOP;
    
    RAISE NOTICE 'Recalculados % items para organización % después de cambio en CostSettings', v_count, NEW.organization_id;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: trig_recompute_msrp_on_import_tax_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trig_recompute_msrp_on_import_tax_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_count integer;
BEGIN
  -- Recalcular todos los items de la categoría afectada
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    v_count := public.msrp_recompute_for_category(NEW.category_id, NEW.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de cambio en ImportTaxRules', v_count, NEW.category_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_count := public.msrp_recompute_for_category(OLD.category_id, OLD.organization_id);
    RAISE NOTICE 'Recalculados % items para categoría % después de eliminación en ImportTaxRules', v_count, OLD.category_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: upsert_organization_user(uuid, text, public.org_role, public.org_user_status, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_organization_user(p_organization_id uuid, p_user_email text, p_role public.org_role, p_status public.org_user_status DEFAULT 'invited'::public.org_user_status, p_user_name text DEFAULT NULL::text) RETURNS TABLE(id uuid, organization_id uuid, user_id uuid, user_email text, user_name text, role public.org_role, status public.org_user_status, invited_by_user_id uuid, invited_at timestamp with time zone, accepted_at timestamp with time zone, deleted boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
  v_existing_id uuid;
  v_current_user_name text;
  v_result_record public."OrganizationUsers"%ROWTYPE;
BEGIN
  -- Obtener caller user_id (SECURITY DEFINER preserva auth.uid())
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es superadmin o admin en la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Solo permitir superadmin y admin (los valores que pueden gestionar usuarios)
  -- También aceptar 'owner' como legacy (mapeado a superadmin)
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins and admins can manage organization users';
  END IF;

  -- Validar que admins no pueden crear superadmins
  IF v_caller_role::text IN ('admin') AND p_role::text = 'superadmin' THEN
    RAISE EXCEPTION 'Admins cannot create superadmins';
  END IF;

  -- También prevenir que admin cree 'owner' (legacy)
  IF v_caller_role::text IN ('admin') AND p_role::text = 'owner' THEN
    RAISE EXCEPTION 'Admins cannot create owners';
  END IF;

  -- Normalizar email
  p_user_email := lower(trim(p_user_email));

  -- Buscar si ya existe (incluyendo deleted=true para "revivir")
  -- Use explicit table alias to avoid ambiguity with RETURNS TABLE
  SELECT ou.id INTO v_existing_id
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND lower(ou.user_email) = p_user_email;

  IF v_existing_id IS NOT NULL THEN
    -- UPDATE: reactivar si estaba deleted, actualizar role/status/user_name
    -- Get current user_name first to preserve it if p_user_name is null
    SELECT ou2.user_name INTO v_current_user_name
    FROM public."OrganizationUsers" ou2
    WHERE ou2.id = v_existing_id;
    
    -- Use fully qualified column reference to avoid ambiguity with RETURNS TABLE id column
    UPDATE public."OrganizationUsers"
    SET
      role = p_role,
      status = p_status,
      user_name = COALESCE(p_user_name, v_current_user_name), -- Update name if provided, else keep existing
      deleted = false,
      updated_at = now()
    WHERE public."OrganizationUsers".id = v_existing_id
    RETURNING public."OrganizationUsers".* INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  ELSE
    -- INSERT: nuevo usuario
    INSERT INTO public."OrganizationUsers" (
      organization_id,
      user_email,
      user_name,
      role,
      status,
      user_id, -- NULL hasta que acepte invite
      invited_by_user_id,
      invited_at,
      deleted,
      created_at,
      updated_at
    ) VALUES (
      p_organization_id,
      p_user_email,
      p_user_name, -- Include user_name in insert
      p_role,
      p_status,
      NULL, -- user_id será NULL hasta que acepte invite
      v_caller_user_id,
      now(),
      false,
      now(),
      now()
    )
    RETURNING * INTO v_result_record;
    
    -- Return as TABLE
    RETURN QUERY SELECT
      v_result_record.id,
      v_result_record.organization_id,
      v_result_record.user_id,
      v_result_record.user_email,
      v_result_record.user_name,
      v_result_record.role,
      v_result_record.status,
      v_result_record.invited_by_user_id,
      v_result_record.invited_at,
      v_result_record.accepted_at,
      v_result_record.deleted,
      v_result_record.created_at,
      v_result_record.updated_at;
  END IF;
END;
$$;


--
-- Name: FUNCTION upsert_organization_user(p_organization_id uuid, p_user_email text, p_role public.org_role, p_status public.org_user_status, p_user_name text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.upsert_organization_user(p_organization_id uuid, p_user_email text, p_role public.org_role, p_status public.org_user_status, p_user_name text) IS 'Upsert organization user. Only superadmins/admins can call. Returns the created/updated OrganizationUsers row. Fixed ambiguous id column reference.';


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_;

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS SETOF realtime.wal_rls
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: add_prefixes(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.add_prefixes(_bucket_id text, _name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    prefixes text[];
BEGIN
    prefixes := "storage"."get_prefixes"("_name");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, "_bucket_id" ON CONFLICT DO NOTHING;
    END IF;
END;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: delete_leaf_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


--
-- Name: delete_prefix(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix(_bucket_id text, _name text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name") + 1
          AND "prefixes"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM "storage"."objects"
        WHERE "objects"."bucket_id" = "_bucket_id"
          AND "storage"."get_level"("objects"."name") = "storage"."get_level"("_name") + 1
          AND "objects"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name")
          AND "prefixes"."name" = "_name";
        RETURN true;
    END IF;
END;
$$;


--
-- Name: delete_prefix_hierarchy_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix_hierarchy_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix text;
BEGIN
    prefix := "storage"."get_prefix"(OLD."name");

    IF coalesce(prefix, '') != '' THEN
        PERFORM "storage"."delete_prefix"(OLD."bucket_id", prefix);
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_level(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_level(name text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


--
-- Name: get_prefix(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefix(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


--
-- Name: get_prefixes(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefixes(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE "C" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                name COLLATE "C" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE "C" ASC) as e order by name COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$_$;


--
-- Name: lock_top_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.lock_top_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$$;


--
-- Name: objects_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: objects_insert_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_insert_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    NEW.level := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: objects_update_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: objects_update_level_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_level_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Set the new level
        NEW."level" := "storage"."get_level"(NEW."name");
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: objects_update_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Retrieve old prefixes
        old_prefixes := "storage"."get_prefixes"(OLD."name");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM "storage"."objects"
                 WHERE "bucket_id" = OLD."bucket_id"
                   AND "name" <> OLD."name"
                   AND "name" LIKE (prefix || '%')
             )
         )
        DELETE FROM "storage"."prefixes" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    END IF;
    -- Set the new level
    NEW."level" := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: prefixes_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: prefixes_insert_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    RETURN NEW;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql
    AS $$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$$;


--
-- Name: search_legacy_v1(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v1_optimised(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v1_optimised(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE "C") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE "C" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE "C" %s $5)', cursor_op);
        sort_expr := format('name COLLATE "C" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$_$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


--
-- Name: http_request(); Type: FUNCTION; Schema: supabase_functions; Owner: -
--

CREATE FUNCTION supabase_functions.http_request() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'supabase_functions'
    AS $$
  DECLARE
    request_id bigint;
    payload jsonb;
    url text := TG_ARGV[0]::text;
    method text := TG_ARGV[1]::text;
    headers jsonb DEFAULT '{}'::jsonb;
    params jsonb DEFAULT '{}'::jsonb;
    timeout_ms integer DEFAULT 1000;
  BEGIN
    IF url IS NULL OR url = 'null' THEN
      RAISE EXCEPTION 'url argument is missing';
    END IF;

    IF method IS NULL OR method = 'null' THEN
      RAISE EXCEPTION 'method argument is missing';
    END IF;

    IF TG_ARGV[2] IS NULL OR TG_ARGV[2] = 'null' THEN
      headers = '{"Content-Type": "application/json"}'::jsonb;
    ELSE
      headers = TG_ARGV[2]::jsonb;
    END IF;

    IF TG_ARGV[3] IS NULL OR TG_ARGV[3] = 'null' THEN
      params = '{}'::jsonb;
    ELSE
      params = TG_ARGV[3]::jsonb;
    END IF;

    IF TG_ARGV[4] IS NULL OR TG_ARGV[4] = 'null' THEN
      timeout_ms = 1000;
    ELSE
      timeout_ms = TG_ARGV[4]::integer;
    END IF;

    CASE
      WHEN method = 'GET' THEN
        SELECT http_get INTO request_id FROM net.http_get(
          url,
          params,
          headers,
          timeout_ms
        );
      WHEN method = 'POST' THEN
        payload = jsonb_build_object(
          'old_record', OLD,
          'record', NEW,
          'type', TG_OP,
          'table', TG_TABLE_NAME,
          'schema', TG_TABLE_SCHEMA
        );

        SELECT http_post INTO request_id FROM net.http_post(
          url,
          payload,
          params,
          headers,
          timeout_ms
        );
      ELSE
        RAISE EXCEPTION 'method argument % is invalid', method;
    END CASE;

    INSERT INTO supabase_functions.hooks
      (hook_table_id, hook_name, request_id)
    VALUES
      (TG_RELID, TG_NAME, request_id);

    RETURN NEW;
  END
$$;


--
-- Name: extensions; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.extensions (
    id uuid NOT NULL,
    type text,
    settings jsonb,
    tenant_external_id text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: tenants; Type: TABLE; Schema: _realtime; Owner: -
--

CREATE TABLE _realtime.tenants (
    id uuid NOT NULL,
    name text,
    external_id text,
    jwt_secret character varying(255),
    max_concurrent_users integer DEFAULT 200 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    max_events_per_second integer DEFAULT 100 NOT NULL,
    postgres_cdc_default text DEFAULT 'postgres_cdc_rls'::text,
    max_bytes_per_second integer DEFAULT 100000 NOT NULL,
    max_channels_per_client integer DEFAULT 100 NOT NULL,
    max_joins_per_second integer DEFAULT 500 NOT NULL,
    suspend boolean DEFAULT false,
    jwt_jwks jsonb,
    notify_private_alpha boolean DEFAULT false,
    private_only boolean DEFAULT false NOT NULL,
    migrations_ran integer DEFAULT 0,
    broadcast_adapter character varying(255) DEFAULT 'gen_rpc'::character varying,
    max_presence_events_per_second integer DEFAULT 1000,
    max_payload_size_in_kb integer DEFAULT 3000,
    CONSTRAINT jwt_secret_or_jwt_jwks_required CHECK (((jwt_secret IS NOT NULL) OR (jwt_jwks IS NOT NULL)))
);


--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text NOT NULL,
    code_challenge_method auth.code_challenge_method NOT NULL,
    code_challenge text NOT NULL,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'stores metadata for pkce logins';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: BOMComponents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BOMComponents" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    bom_template_id uuid NOT NULL,
    component_item_id uuid,
    component_role text NOT NULL,
    qty_type text DEFAULT 'fixed'::text NOT NULL,
    qty_value numeric(12,4) DEFAULT 1 NOT NULL,
    qty_delta_mm numeric(12,4) DEFAULT 0 NOT NULL,
    uom text DEFAULT 'ea'::text NOT NULL,
    waste_pct numeric(7,4) DEFAULT 0 NOT NULL,
    auto_select boolean DEFAULT true NOT NULL,
    sku_resolution_rule text DEFAULT 'ROLE_AND_COLOR'::text NOT NULL,
    depends_on_role text,
    cut_axis text,
    cut_delta_mm numeric(12,4) DEFAULT 0 NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    component_mode public.bom_component_mode DEFAULT 'auto'::public.bom_component_mode NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    type_per_unit text,
    component_scope text DEFAULT 'bom'::text NOT NULL,
    slot_id uuid,
    qty_spacing_mm integer,
    qty_min numeric,
    parent_component_id uuid,
    component_sub_role text,
    metadata jsonb,
    CONSTRAINT "BOMComponents_component_scope_check" CHECK ((component_scope = ANY (ARRAY['bom'::text, 'sku'::text]))),
    CONSTRAINT bomcomponents_component_role_check CHECK ((component_role = ANY (ARRAY['tube'::text, 'track'::text, 'bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text, 'side_channel'::text, 'top_rail'::text, 'headbox'::text, 'bracket'::text, 'idler'::text, 'drive'::text, 'motor'::text, 'chain'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'wand'::text, 'end_cap'::text, 'filler'::text, 'tape'::text, 'consumable'::text, 'fastener'::text, 'accessory'::text, 'carrier'::text, 'belt'::text, 'belt_connector'::text, 'hook'::text, 'brush'::text, 'fabric'::text, 'adapter'::text, 'bearing'::text, 'connector'::text, 'guide'::text, 'rail_connector'::text, 'spring'::text, 'stopper'::text, 'mounting_clip'::text, 'end_plug'::text]))),
    CONSTRAINT bomcomponents_component_scope_check CHECK ((component_scope = ANY (ARRAY['template'::text, 'bom'::text]))),
    CONSTRAINT bomcomponents_depends_on_role_check CHECK (((depends_on_role IS NULL) OR (depends_on_role = ANY (ARRAY['tube'::text, 'track'::text, 'bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text, 'side_channel'::text, 'top_rail'::text, 'headbox'::text, 'bracket'::text, 'idler'::text, 'drive'::text, 'motor'::text, 'chain'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'wand'::text, 'end_cap'::text, 'filler'::text, 'tape'::text, 'consumable'::text, 'fastener'::text, 'accessory'::text, 'carrier'::text, 'belt'::text, 'belt_connector'::text, 'hook'::text, 'brush'::text, 'fabric'::text, 'adapter'::text, 'bearing'::text, 'connector'::text, 'guide'::text, 'rail_connector'::text, 'spring'::text, 'stopper'::text, 'mounting_clip'::text, 'end_plug'::text])))),
    CONSTRAINT bomcomponents_fixed_requires_item CHECK ((((component_mode <> 'fixed'::public.bom_component_mode) AND (component_item_id IS NULL)) OR ((component_mode = 'fixed'::public.bom_component_mode) AND (component_item_id IS NOT NULL)) OR (component_mode = ANY (ARRAY['select'::public.bom_component_mode, 'auto'::public.bom_component_mode, 'optional'::public.bom_component_mode]))))
);


--
-- Name: COLUMN "BOMComponents".component_sub_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMComponents".component_sub_role IS 'Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)';


--
-- Name: COLUMN "BOMComponents".metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMComponents".metadata IS 'Additional JSON metadata for component configuration';


--
-- Name: BOMInstanceLines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BOMInstanceLines" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bom_instance_id uuid NOT NULL,
    bom_component_id uuid,
    resolved_part_id uuid,
    part_role text NOT NULL,
    qty numeric(12,4) NOT NULL,
    uom text NOT NULL,
    cut_length_mm numeric(12,4),
    cut_width_mm numeric(12,4),
    cut_height_mm numeric(12,4),
    unit_cost_exw numeric(12,4),
    total_cost_exw numeric(12,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    CONSTRAINT bominstancelines_part_role_check CHECK ((part_role = ANY (ARRAY['tube'::text, 'track'::text, 'bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text, 'side_channel'::text, 'top_rail'::text, 'headbox'::text, 'bracket'::text, 'idler'::text, 'drive'::text, 'motor'::text, 'adapter'::text, 'chain'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'wand'::text, 'end_cap'::text, 'filler'::text, 'tape'::text, 'consumable'::text, 'fastener'::text, 'accessory'::text, 'carrier'::text, 'belt'::text, 'belt_connector'::text])))
);


--
-- Name: COLUMN "BOMInstanceLines".resolved_part_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMInstanceLines".resolved_part_id IS 'FK to CatalogItems. Can be NULL for structural lines without SKU (user has not selected yet).';


--
-- Name: CatalogItems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItems" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    sku text NOT NULL,
    unit_of_measure text NOT NULL,
    description text,
    category_id uuid,
    image_url text,
    measure_basis text NOT NULL,
    collection_name text,
    variant_name text,
    roll_width numeric(12,4),
    color text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    cost_exw numeric(12,4),
    manufacturer text,
    manufacturer_id uuid,
    is_roll boolean DEFAULT false NOT NULL,
    roll_collection_id uuid,
    roll_type public.roll_type,
    item_role text,
    roll_pricing_mode text,
    units_per_purchase_unit numeric(12,4) DEFAULT 1 NOT NULL,
    purchase_unit text DEFAULT 'each'::text NOT NULL,
    roll_width_value numeric,
    roll_width_uom text,
    roll_width_m numeric,
    roll_length_value numeric,
    roll_length_uom text,
    roll_length_m numeric,
    CONSTRAINT catalogitems_item_role_check CHECK (((item_role IS NULL) OR (item_role = ANY (ARRAY['accessory'::text, 'adapter'::text, 'bearing'::text, 'belt'::text, 'belt_connector'::text, 'bottom_bar'::text, 'bottom_bar_profile'::text, 'bottom_channel'::text, 'bottom_rail_profile'::text, 'bracket'::text, 'brush'::text, 'cable'::text, 'carrier'::text, 'cassette'::text, 'chain'::text, 'chain_clip'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'consumable'::text, 'control'::text, 'drive'::text, 'drive_adapter'::text, 'drive_manual'::text, 'drive_motorized'::text, 'end_cap'::text, 'end_plug'::text, 'fabric'::text, 'fascia'::text, 'fastener'::text, 'filler'::text, 'guide'::text, 'handle'::text, 'hardware'::text, 'headbox'::text, 'hook'::text, 'idler'::text, 'motor'::text, 'mount_profile'::text, 'mounting_clip'::text, 'rail_connector'::text, 'screw_cap'::text, 'side_channel'::text, 'side_channel_profile'::text, 'spring'::text, 'stopper'::text, 'sub_bracket'::text, 'tape'::text, 'top_rail'::text, 'top_rail_profile'::text, 'track'::text, 'tube'::text, 'wand'::text, 'window_film'::text])))),
    CONSTRAINT catalogitems_purchase_unit_chk CHECK ((purchase_unit = ANY (ARRAY['each'::text, 'pack'::text, 'set'::text, 'box'::text, 'case'::text]))),
    CONSTRAINT catalogitems_roll_length_uom_chk CHECK (((roll_length_uom IS NULL) OR (roll_length_uom = ANY (ARRAY['m'::text, 'yd'::text, 'ft'::text, 'in'::text])))),
    CONSTRAINT catalogitems_roll_pricing_mode_chk CHECK (((roll_pricing_mode IS NULL) OR (roll_pricing_mode = ANY (ARRAY['per_linear_meter'::text, 'per_square_meter'::text, 'per_unit'::text])))),
    CONSTRAINT catalogitems_roll_type_requires_is_roll CHECK (((roll_type IS NULL) OR (is_roll = true))),
    CONSTRAINT catalogitems_roll_width_uom_chk CHECK (((roll_width_uom IS NULL) OR (roll_width_uom = ANY (ARRAY['m'::text, 'yd'::text, 'ft'::text, 'in'::text])))),
    CONSTRAINT catalogitems_units_per_purchase_unit_chk CHECK (((units_per_purchase_unit IS NULL) OR (units_per_purchase_unit > (0)::numeric)))
);


--
-- Name: COLUMN "CatalogItems".roll_pricing_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItems".roll_pricing_mode IS 'How this roll/fabric is priced in quotes: per_linear_meter | per_square_meter | per_unit.';


--
-- Name: COLUMN "CatalogItems".units_per_purchase_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItems".units_per_purchase_unit IS 'If unit_of_measure is pack/set/box, how many EA are inside that purchase unit. Used to normalize to $/ea.';


--
-- Name: BOMInstanceLinesOrdered; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public."BOMInstanceLinesOrdered" AS
 SELECT bil.id,
    bil.organization_id,
    bil.bom_instance_id,
    bil.bom_component_id,
    bil.resolved_part_id,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.cut_width_mm,
    bil.cut_height_mm,
    bil.cut_length_mm,
    bil.created_at,
    bil.deleted,
    bil.archived,
    ci.sku,
    ci.name,
    bc.component_role AS template_role,
    bc.sort_order AS template_sort_order,
    pbc.component_role AS parent_role,
    pbc.sort_order AS parent_sort_order,
    COALESCE(pbc.component_role, bil.part_role) AS group_role,
        CASE
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'tube'::text) THEN 10
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'motor'::text) THEN 20
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'drive'::text) THEN 21
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'idler'::text) THEN 22
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'bracket'::text) THEN 30
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'mounting_clip'::text) THEN 31
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'adapter'::text) THEN 40
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'bearing'::text) THEN 41
            WHEN (COALESCE(pbc.component_role, bil.part_role) = ANY (ARRAY['chain'::text, 'wand'::text, 'belt'::text, 'belt_connector'::text, 'chain_stop'::text, 'chain_tensioner'::text])) THEN 50
            WHEN (COALESCE(pbc.component_role, bil.part_role) = ANY (ARRAY['end_cap'::text, 'filler'::text])) THEN 60
            WHEN (COALESCE(pbc.component_role, bil.part_role) = ANY (ARRAY['headbox'::text, 'cassette'::text, 'top_rail'::text, 'track'::text, 'side_channel'::text])) THEN 70
            WHEN (COALESCE(pbc.component_role, bil.part_role) = ANY (ARRAY['bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text])) THEN 80
            WHEN (COALESCE(pbc.component_role, bil.part_role) = ANY (ARRAY['fastener'::text, 'consumable'::text, 'tape'::text])) THEN 90
            WHEN (COALESCE(pbc.component_role, bil.part_role) = 'accessory'::text) THEN 95
            ELSE 999
        END AS role_rank,
        CASE
            WHEN ((bil.bom_component_id IS NOT NULL) AND (bc.parent_component_id IS NOT NULL)) THEN 1
            ELSE 0
        END AS is_child
   FROM (((public."BOMInstanceLines" bil
     LEFT JOIN public."CatalogItems" ci ON ((ci.id = bil.resolved_part_id)))
     LEFT JOIN public."BOMComponents" bc ON ((bc.id = bil.bom_component_id)))
     LEFT JOIN public."BOMComponents" pbc ON ((pbc.id = bc.parent_component_id)))
  WHERE ((bil.deleted IS DISTINCT FROM true) AND (bil.archived IS DISTINCT FROM true));


--
-- Name: BOMInstances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BOMInstances" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_line_id uuid NOT NULL,
    bom_template_id uuid NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    configured_product_id uuid,
    archived boolean DEFAULT false NOT NULL
);


--
-- Name: BOMTemplateSlots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BOMTemplateSlots" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    bom_template_id uuid NOT NULL,
    item_role text NOT NULL,
    required boolean DEFAULT true NOT NULL,
    catalog_item_id uuid,
    qty numeric(12,4) DEFAULT 1 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    selection_mode text DEFAULT 'user_select'::text NOT NULL,
    fixed_catalog_item_id uuid,
    slot_sku text,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    CONSTRAINT bomtemplateslots_item_role_check CHECK ((item_role = ANY (ARRAY['tube'::text, 'track'::text, 'bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text, 'side_channel'::text, 'top_rail'::text, 'headbox'::text, 'bracket'::text, 'idler'::text, 'drive'::text, 'motor'::text, 'chain'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'wand'::text, 'end_cap'::text, 'filler'::text, 'tape'::text, 'consumable'::text, 'fastener'::text, 'accessory'::text, 'carrier'::text, 'belt'::text, 'belt_connector'::text, 'hook'::text, 'brush'::text, 'fabric'::text, 'adapter'::text, 'bearing'::text, 'connector'::text, 'guide'::text, 'rail_connector'::text, 'spring'::text, 'stopper'::text, 'mounting_clip'::text, 'end_plug'::text]))),
    CONSTRAINT bomtemplateslots_selection_mode_check CHECK ((selection_mode = ANY (ARRAY['user_select'::text, 'fixed'::text, 'none_allowed'::text])))
);


--
-- Name: BOMTemplates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."BOMTemplates" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_type_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true,
    hardware_color text,
    sort_order integer DEFAULT 0 NOT NULL,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb,
    deleted boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN "BOMTemplates".hardware_color; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMTemplates".hardware_color IS 'Hardware color (White, Black, Silver, Bronze, etc.) to differentiate templates for the same product type. NULL means template applies to all colors.';


--
-- Name: COLUMN "BOMTemplates".sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMTemplates".sort_order IS 'Display order for templates (lower numbers appear first). Used for drag-and-drop reordering.';


--
-- Name: COLUMN "BOMTemplates".description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMTemplates".description IS 'Optional description for the BOM template.';


--
-- Name: COLUMN "BOMTemplates".metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."BOMTemplates".metadata IS 'Additional metadata for the BOM template (rules, priority, etc).';


--
-- Name: CatalogCategories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogCategories" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    parent_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT catalogcategories_parent_not_self CHECK (((parent_id IS NULL) OR (parent_id <> id)))
);


--
-- Name: CatalogItemComponents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemComponents" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    parent_item_id uuid NOT NULL,
    child_item_id uuid NOT NULL,
    child_role text NOT NULL,
    qty numeric(12,4) DEFAULT 1 NOT NULL,
    uom text DEFAULT 'ea'::text NOT NULL,
    required boolean DEFAULT true NOT NULL,
    notes text,
    sort_order integer DEFAULT 0 NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT catalogitemcomponents_child_role_check CHECK ((child_role = ANY (ARRAY['adapter'::text, 'end_cap'::text, 'fastener'::text, 'idler'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'filler'::text, 'chain'::text, 'belt'::text, 'belt_connector'::text, 'hem_weight'::text, 'brush'::text, 'accessory'::text, 'carrier'::text, 'consumable'::text, 'hook'::text, 'mounting_clip'::text, 'bearing'::text, 'connector'::text, 'end_plug'::text, 'guide'::text, 'rail_connector'::text, 'spring'::text, 'stopper'::text])))
);


--
-- Name: TABLE "CatalogItemComponents"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."CatalogItemComponents" IS 'SKU → HIJOS relationship. Defines which child components (adapter, end_cap, screw, etc) are included with a parent SKU (motor, bracket, etc). Used by generate_bom_from_slots() to expand children components.';


--
-- Name: COLUMN "CatalogItemComponents".parent_item_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemComponents".parent_item_id IS 'FK to CatalogItems. The parent SKU (motor, bracket, tube, etc).';


--
-- Name: COLUMN "CatalogItemComponents".child_item_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemComponents".child_item_id IS 'FK to CatalogItems. The child component (adapter, end_cap, screw, etc).';


--
-- Name: COLUMN "CatalogItemComponents".child_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemComponents".child_role IS 'Role of child component. Must be a valid child role (adapter, end_cap, screw, etc).';


--
-- Name: CONSTRAINT catalogitemcomponents_child_role_check ON "CatalogItemComponents"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT catalogitemcomponents_child_role_check ON public."CatalogItemComponents" IS 'Validates that child_role is one of the canonical child roles. Updated 2026-01-20 to include all required child roles: adapter, end_cap, fastener, idler, chain_stop, chain_tensioner, filler, chain, belt, belt_connector, hem_weight, brush, accessory, carrier, consumable, hook, mounting_clip, bearing, connector, end_plug, guide, rail_connector, spring, stopper';


--
-- Name: CatalogItemConversions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemConversions" (
    catalog_item_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    cost_exw_input numeric,
    unit_of_measure_input text,
    roll_width_input numeric,
    cost_exw_per_m numeric,
    cost_exw_per_m2 numeric,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    cost_exw_per_ea numeric
);


--
-- Name: TABLE "CatalogItemConversions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."CatalogItemConversions" IS 'Stored conversions for roll items (fabrics). Keeps CatalogItems clean for mass imports.';


--
-- Name: CatalogItemProductTypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemProductTypes" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    catalog_item_id uuid NOT NULL,
    product_type_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    catalog_item_sku text,
    catalog_item_name text
);


--
-- Name: CatalogItemRoles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemRoles" (
    role_code text NOT NULL,
    label text NOT NULL,
    description text,
    default_category_id uuid,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    role_name text DEFAULT ''::text NOT NULL,
    role_description text,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE "CatalogItemRoles"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."CatalogItemRoles" IS 'Tabla canónica de roles de componentes. Fuente única de verdad para item_role y part_role en todo el sistema.';


--
-- Name: COLUMN "CatalogItemRoles".role_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemRoles".role_code IS 'Código único del role (snake_case). Debe coincidir exactamente con valores usados en CatalogItems.item_role, BOMTemplateSlots.item_role, y BomInstanceLines.part_role.';


--
-- Name: COLUMN "CatalogItemRoles".role_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemRoles".role_name IS 'Nombre legible del role (ej: "Motor", "Headbox", "Bottom Bar")';


--
-- Name: COLUMN "CatalogItemRoles".role_description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."CatalogItemRoles".role_description IS 'Descripción opcional del role';


--
-- Name: CatalogItemRollSpecs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemRollSpecs" (
    catalog_item_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    can_rotate boolean DEFAULT false NOT NULL,
    is_weldable boolean DEFAULT false NOT NULL,
    raw_material text,
    openness_factor_pct numeric(6,3),
    weight_g_m2 numeric(10,3),
    weight_kg_m2 numeric(10,3),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT roll_specs_openness_range CHECK (((openness_factor_pct IS NULL) OR ((openness_factor_pct >= (0)::numeric) AND (openness_factor_pct <= (100)::numeric)))),
    CONSTRAINT roll_specs_weight_nonnegative CHECK ((((weight_g_m2 IS NULL) OR (weight_g_m2 >= (0)::numeric)) AND ((weight_kg_m2 IS NULL) OR (weight_kg_m2 >= (0)::numeric))))
);


--
-- Name: CatalogItemSupply; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemSupply" (
    catalog_item_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    supply_type text NOT NULL,
    supply_origin text NOT NULL,
    lead_time_min_days integer NOT NULL,
    lead_time_max_days integer NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "CatalogItemSupply_supply_origin_check" CHECK ((supply_origin = ANY (ARRAY['local'::text, 'import'::text]))),
    CONSTRAINT "CatalogItemSupply_supply_type_check" CHECK ((supply_type = ANY (ARRAY['stock'::text, 'order'::text]))),
    CONSTRAINT catalog_item_supply_lead_time_ok CHECK ((lead_time_min_days <= lead_time_max_days))
);


--
-- Name: CatalogItemsMSRP; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogItemsMSRP" (
    catalog_item_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    category_id uuid,
    cost_exw numeric(12,4) NOT NULL,
    import_tax_cost numeric(12,4) NOT NULL,
    shipping_cost numeric(12,4) NOT NULL,
    total_cost numeric(12,4) NOT NULL,
    sku text,
    name text,
    collection_name text,
    variant_name text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    unit_of_measure text,
    shipping_pct numeric(7,4),
    import_tax_pct numeric(7,4),
    minimum_margin_pct numeric(7,4),
    msrp_pct_sale_out numeric(7,4),
    dealer_price numeric DEFAULT 0 NOT NULL,
    msrp numeric DEFAULT 0 NOT NULL
);


--
-- Name: CatalogRoleCategoryMap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CatalogRoleCategoryMap" (
    organization_id uuid NOT NULL,
    role_code text NOT NULL,
    target_category_id uuid NOT NULL,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: CategoryMargins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CategoryMargins" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    category_id uuid NOT NULL,
    msrp_pct_sale_in numeric(7,4) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    msrp_pct_sale_out numeric(7,4) DEFAULT 0.65 NOT NULL,
    minimum_margin_pct numeric(7,4) GENERATED ALWAYS AS (msrp_pct_sale_in) STORED
);


--
-- Name: Companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Companies" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    company_name text NOT NULL,
    company_email text,
    company_phone text,
    status text DEFAULT 'active'::text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    company_no text,
    customer_type public.customer_type DEFAULT 'reseller'::public.customer_type,
    identification_number text,
    website text,
    alt_phone text,
    primary_contact_id uuid,
    street_address_line_1 text,
    street_address_line_2 text,
    city text,
    state text,
    zip_code text,
    country text,
    billing_same_as_location boolean DEFAULT true,
    billing_street_address_line_1 text,
    billing_street_address_line_2 text,
    billing_city text,
    billing_state text,
    billing_zip_code text,
    billing_country text,
    notes text,
    CONSTRAINT companies_org_required CHECK ((organization_id IS NOT NULL))
);


--
-- Name: COLUMN "Companies".identification_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".identification_number IS 'Tax ID or business registration number';


--
-- Name: COLUMN "Companies".website; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".website IS 'Company website URL';


--
-- Name: COLUMN "Companies".alt_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".alt_phone IS 'Alternative phone number';


--
-- Name: COLUMN "Companies".primary_contact_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".primary_contact_id IS 'Primary contact person from DirectoryContacts';


--
-- Name: COLUMN "Companies".street_address_line_1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".street_address_line_1 IS 'Primary street address';


--
-- Name: COLUMN "Companies".street_address_line_2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".street_address_line_2 IS 'Secondary street address (suite, unit, etc.)';


--
-- Name: COLUMN "Companies".city; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".city IS 'City';


--
-- Name: COLUMN "Companies".state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".state IS 'State or province';


--
-- Name: COLUMN "Companies".zip_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".zip_code IS 'ZIP or postal code';


--
-- Name: COLUMN "Companies".country; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".country IS 'Country';


--
-- Name: COLUMN "Companies".billing_same_as_location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_same_as_location IS 'If true, billing address is same as location address';


--
-- Name: COLUMN "Companies".billing_street_address_line_1; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_street_address_line_1 IS 'Billing street address line 1';


--
-- Name: COLUMN "Companies".billing_street_address_line_2; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_street_address_line_2 IS 'Billing street address line 2';


--
-- Name: COLUMN "Companies".billing_city; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_city IS 'Billing city';


--
-- Name: COLUMN "Companies".billing_state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_state IS 'Billing state or province';


--
-- Name: COLUMN "Companies".billing_zip_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_zip_code IS 'Billing ZIP or postal code';


--
-- Name: COLUMN "Companies".billing_country; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".billing_country IS 'Billing country';


--
-- Name: COLUMN "Companies".notes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Companies".notes IS 'Additional notes about the dealer/company';


--
-- Name: CompanyPortalUsers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CompanyPortalUsers" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    status public.portal_user_status DEFAULT 'draft'::public.portal_user_status NOT NULL,
    invited_by_user_id uuid,
    invited_at timestamp with time zone,
    accepted_at timestamp with time zone,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    organization_id uuid,
    portal_user_email text,
    portal_user_name text,
    company_id uuid,
    role text DEFAULT 'member'::text NOT NULL,
    must_change_password boolean DEFAULT true NOT NULL,
    temp_password_set_at timestamp with time zone,
    CONSTRAINT company_portal_role_check CHECK ((role = ANY (ARRAY['member'::text, 'member_manager'::text]))),
    CONSTRAINT companyportalusers_portal_user_role_check CHECK ((role = ANY (ARRAY['member_manager'::text, 'member'::text]))),
    CONSTRAINT companyportalusers_role_check CHECK ((role = ANY (ARRAY['member_manager'::text, 'member'::text])))
);


--
-- Name: ConfiguredProducts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ConfiguredProducts" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_id uuid,
    bom_template_id uuid NOT NULL,
    product_type_id uuid NOT NULL,
    width_mm numeric(12,4),
    height_mm numeric(12,4),
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    hardware_color text,
    bom_total numeric(12,4) DEFAULT 0,
    labor_pct numeric(5,2) DEFAULT 0,
    accessories_total numeric(12,4) DEFAULT 0,
    total_msrp numeric(12,4) DEFAULT 0,
    config_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    roll_catalog_item_id uuid,
    roll_sku text,
    roll_collection_name text,
    roll_variant_name text,
    roll_width numeric(12,4),
    roll_msrp_total numeric(12,4) DEFAULT 0,
    roll_plus_bom_total numeric(12,4) DEFAULT 0,
    bottom_bar_item_id uuid,
    bottom_bar_sku text,
    headbox_item_id uuid,
    headbox_sku text,
    side_channel_item_id uuid,
    side_channel_sku text,
    bottom_channel_item_id uuid,
    bottom_channel_sku text,
    motor_item_id uuid,
    motor_sku text,
    drive_item_id uuid,
    drive_sku text,
    tube_item_id uuid,
    tube_sku text,
    operating_type text,
    roll_total_cost numeric(12,4) DEFAULT 0,
    bom_total_cost numeric(12,4) DEFAULT 0,
    labor_amount numeric(12,4) DEFAULT 0
);


--
-- Name: TABLE "ConfiguredProducts"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."ConfiguredProducts" IS 'Snapshot completo de producto configurado (Roll + BOM) antes de crear QuoteLine. Contiene precios calculados y toda la configuración.';


--
-- Name: COLUMN "ConfiguredProducts".bom_total; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".bom_total IS 'Total MSRP sale_out de todos los componentes BOM (padres + hijos) desde BOMInstanceLines.';


--
-- Name: COLUMN "ConfiguredProducts".config_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".config_snapshot IS 'JSONB con snapshot completo de la configuración desde ProductConfigurator. Incluye todas las selecciones y opciones.';


--
-- Name: COLUMN "ConfiguredProducts".metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".metadata IS 'JSONB para datos adicionales flexibles.';


--
-- Name: COLUMN "ConfiguredProducts".roll_msrp_total; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".roll_msrp_total IS 'MSRP Sale out × Ancho del rollo total × Altura de la medida de measurements × quantity.';


--
-- Name: COLUMN "ConfiguredProducts".roll_plus_bom_total; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".roll_plus_bom_total IS 'Suma de Roll MSRP + BOM Total (antes de aplicar labor y accessories).';


--
-- Name: COLUMN "ConfiguredProducts".roll_total_cost; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".roll_total_cost IS 'Costo real total del roll (usando CatalogItemsMSRP.total_cost). 
Calculado como: total_cost del roll × roll_width × height_m × quantity';


--
-- Name: COLUMN "ConfiguredProducts".bom_total_cost; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."ConfiguredProducts".bom_total_cost IS 'Costo real total del BOM (suma de CatalogItemsMSRP.total_cost de cada BOMInstanceLine).
Calculado como: SUM(total_cost × qty) para cada línea del BOM';


--
-- Name: CostSettings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."CostSettings" (
    organization_id uuid NOT NULL,
    labor_pct numeric(7,4) DEFAULT 0 NOT NULL,
    shipping_pct numeric(7,4) DEFAULT 0 NOT NULL,
    global_import_tax_pct numeric(7,4) DEFAULT 0 NOT NULL,
    minimum_margin_pct numeric(7,4) DEFAULT 0 NOT NULL,
    reseller_discount_pct numeric(7,4) DEFAULT 0 NOT NULL,
    distributor_discount_pct numeric(7,4) DEFAULT 0 NOT NULL,
    partner_discount_pct numeric(7,4) DEFAULT 0 NOT NULL,
    vip_discount_pct numeric(7,4) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    default_msrp_pct_sale_out numeric(7,4) DEFAULT 0.65 NOT NULL,
    import_tax_pct numeric(7,4) GENERATED ALWAYS AS (global_import_tax_pct) STORED,
    default_margin_pct numeric(7,4) DEFAULT 0.3500 NOT NULL,
    msrp_pct_sale_out numeric(7,4) GENERATED ALWAYS AS (default_msrp_pct_sale_out) STORED,
    discount_reseller_pct numeric(5,2) DEFAULT 0.00 NOT NULL,
    discount_distributor_pct numeric(5,2) DEFAULT 0.00 NOT NULL,
    discount_partner_pct numeric(5,2) DEFAULT 0.00 NOT NULL,
    discount_vip_pct numeric(5,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "CostSettings_discount_distributor_pct_check" CHECK (((discount_distributor_pct >= (0)::numeric) AND (discount_distributor_pct <= (100)::numeric))),
    CONSTRAINT "CostSettings_discount_partner_pct_check" CHECK (((discount_partner_pct >= (0)::numeric) AND (discount_partner_pct <= (100)::numeric))),
    CONSTRAINT "CostSettings_discount_reseller_pct_check" CHECK (((discount_reseller_pct >= (0)::numeric) AND (discount_reseller_pct <= (100)::numeric))),
    CONSTRAINT "CostSettings_discount_vip_pct_check" CHECK (((discount_vip_pct >= (0)::numeric) AND (discount_vip_pct <= (100)::numeric)))
);


--
-- Name: DirectoryContacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."DirectoryContacts" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    customer_id uuid,
    phone text,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    contact_name text,
    contact_email text,
    contact_phone text,
    contact_title text,
    notes text,
    company_id uuid,
    contact_id_number text,
    contact_type public.contact_type,
    contact_primary_phone text,
    contact_cell_phone text,
    contact_alt_phone text,
    contact_street_address text,
    contact_street_address_2 text,
    contact_city text,
    contact_state text,
    contact_zip_code text,
    contact_country text
);


--
-- Name: DirectoryCustomers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."DirectoryCustomers" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    status text,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    customer_name text,
    customer_email text,
    customer_phone text,
    customer_status text DEFAULT 'active'::text NOT NULL,
    notes text,
    company_id uuid,
    identification_number text,
    customer_type_name text,
    website text,
    alt_phone text,
    primary_contact_id uuid,
    street_address_line_1 text,
    street_address_line_2 text,
    city text,
    state text,
    zip_code text,
    country text,
    billing_street_address_line_1 text,
    billing_street_address_line_2 text,
    billing_city text,
    billing_state text,
    billing_zip_code text,
    billing_country text
);


--
-- Name: COLUMN "DirectoryCustomers".customer_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."DirectoryCustomers".customer_phone IS 'Customer phone number (main contact phone)';


--
-- Name: COLUMN "DirectoryCustomers".identification_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."DirectoryCustomers".identification_number IS 'Customer identification number (tax ID, etc.)';


--
-- Name: COLUMN "DirectoryCustomers".customer_type_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."DirectoryCustomers".customer_type_name IS 'Customer type: contractor, architecture_studio, design_studio, end_user';


--
-- Name: COLUMN "DirectoryCustomers".alt_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."DirectoryCustomers".alt_phone IS 'Alternative phone number';


--
-- Name: COLUMN "DirectoryCustomers".primary_contact_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."DirectoryCustomers".primary_contact_id IS 'Primary contact person (FK to DirectoryContacts)';


--
-- Name: ImportTaxRules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ImportTaxRules" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    category_id uuid NOT NULL,
    import_tax_pct numeric(7,4) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: Manufacturers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Manufacturers" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    name text NOT NULL,
    code text,
    website text,
    notes text,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid
);


--
-- Name: ManufacturingOrders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ManufacturingOrders" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    sales_order_id uuid NOT NULL,
    manufacturing_order_no text,
    status public.manufacturing_order_status DEFAULT 'draft'::public.manufacturing_order_status NOT NULL,
    priority text DEFAULT 'normal'::text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    company_id uuid
);


--
-- Name: OrderList; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."OrderList" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    sales_order_id uuid NOT NULL,
    tracking_status public.sales_order_tracking_status DEFAULT 'pending_confirmation'::public.sales_order_tracking_status NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    company_id uuid
);


--
-- Name: TABLE "OrderList"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."OrderList" IS 'OrderList table - mirror of SalesOrders for tracking. tracking_status always mirrors SalesOrders.tracking_status.';


--
-- Name: COLUMN "OrderList".sales_order_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."OrderList".sales_order_id IS 'FK to SalesOrders (1:1 unique). OrderList always created with SalesOrder.';


--
-- Name: COLUMN "OrderList".tracking_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."OrderList".tracking_status IS 'Tracking status - always mirrors SalesOrders.tracking_status (via trigger).';


--
-- Name: OrganizationUserPermissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."OrganizationUserPermissions" (
    organization_user_id uuid NOT NULL,
    permission_code text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE "OrganizationUserPermissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."OrganizationUserPermissions" IS 'Junction table linking OrganizationUsers to Permissions';


--
-- Name: Organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Organizations" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    company_no_prefix text DEFAULT 'AP'::text NOT NULL,
    next_company_no integer DEFAULT 1001 NOT NULL,
    CONSTRAINT organizations_company_no_prefix_chk CHECK (((length(company_no_prefix) >= 1) AND (length(company_no_prefix) <= 10)))
);


--
-- Name: TABLE "Organizations"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."Organizations" IS 'Organizations table - base entity for multi-tenancy';


--
-- Name: Permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Permissions" (
    code text NOT NULL,
    module text NOT NULL,
    description text
);


--
-- Name: TABLE "Permissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."Permissions" IS 'RBAC Permissions - available permissions with module grouping';


--
-- Name: ProductTypeRoleRules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ProductTypeRoleRules" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    product_type_id uuid NOT NULL,
    role_code text NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL
);


--
-- Name: ProductTypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."ProductTypes" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: QuoteLineComponents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."QuoteLineComponents" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_line_id uuid NOT NULL,
    component_role text NOT NULL,
    kind text DEFAULT 'option'::text NOT NULL,
    source text DEFAULT 'configured_component'::text NOT NULL,
    catalog_item_id uuid,
    qty numeric(12,4) DEFAULT 1 NOT NULL,
    unit_cost_exw numeric(12,4),
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quotelinecomponents_component_role_check CHECK ((component_role = ANY (ARRAY['tube'::text, 'track'::text, 'bottom_bar'::text, 'bottom_channel'::text, 'hem_weight'::text, 'side_channel'::text, 'side_channels'::text, 'top_rail'::text, 'headbox'::text, 'bracket'::text, 'idler'::text, 'drive'::text, 'motor'::text, 'adapter'::text, 'chain'::text, 'chain_stop'::text, 'chain_tensioner'::text, 'wand'::text, 'end_cap'::text, 'filler'::text, 'tape'::text, 'consumable'::text, 'fastener'::text, 'accessory'::text, 'carrier'::text, 'belt'::text, 'belt_connector'::text, 'bearing'::text, 'hook'::text, 'brush'::text, 'hardware_color'::text, 'drive_type'::text, 'system_size'::text, 'cassette'::text, 'bottom_rail_type'::text, 'tube_type'::text, 'fabric'::text]))),
    CONSTRAINT quotelinecomponents_kind_check CHECK ((kind = ANY (ARRAY['option'::text, 'selection'::text, 'override'::text, 'accessory'::text])))
);


--
-- Name: QuoteLineCosts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."QuoteLineCosts" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_id uuid NOT NULL,
    quote_line_id uuid NOT NULL,
    quantity numeric DEFAULT 1 NOT NULL,
    cost_exw numeric DEFAULT 0 NOT NULL,
    material_cost numeric DEFAULT 0 NOT NULL,
    labor_pct numeric DEFAULT 0 NOT NULL,
    labor_cost numeric DEFAULT 0 NOT NULL,
    shipping_pct numeric DEFAULT 0 NOT NULL,
    shipping_cost numeric DEFAULT 0 NOT NULL,
    import_tax_pct numeric DEFAULT 0 NOT NULL,
    import_tax_cost numeric DEFAULT 0 NOT NULL,
    total_cost numeric DEFAULT 0 NOT NULL,
    pricing_version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: QuoteLines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."QuoteLines" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    company_id uuid,
    quote_id uuid NOT NULL,
    catalog_item_id uuid,
    category_id uuid,
    sku text,
    name text,
    manufacturer_id uuid,
    manufacturer text,
    pricing_basis public.pricing_basis,
    unit_of_measure text,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    width_m numeric(12,4),
    height_m numeric(12,4),
    is_roll boolean,
    roll_type text,
    collection_name text,
    variant_name text,
    roll_width_m numeric(12,4),
    fabric_pricing_mode text,
    drop_m numeric(12,4),
    sqm numeric(12,4),
    cost_exw numeric(12,4),
    labor_pct numeric(7,4),
    shipping_pct numeric(7,4),
    import_tax_pct numeric(7,4),
    default_margin_pct numeric(7,4),
    minimum_margin_pct numeric(7,4),
    discount_pct numeric(7,4),
    material_cost numeric(12,4),
    labor_cost numeric(12,4),
    shipping_cost numeric(12,4),
    import_tax_cost numeric(12,4),
    total_cost numeric(12,4),
    applied_margin_pct numeric(7,4),
    msrp numeric(12,4),
    net_price numeric(12,4),
    pricing_version integer DEFAULT 1 NOT NULL,
    pricing_locked boolean DEFAULT true NOT NULL,
    last_priced_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    collection_id uuid,
    variant_id uuid,
    product_type text,
    area text,
    "position" text,
    hardware_color text,
    cassette boolean DEFAULT false,
    side_channel boolean DEFAULT false,
    drive_type text,
    bom_template_id uuid,
    roll_cost_snapshot numeric,
    bom_cost_snapshot numeric,
    roll_msrp_snapshot numeric,
    bom_msrp_snapshot numeric,
    configured_product_id uuid
);


--
-- Name: COLUMN "QuoteLines".hardware_color; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".hardware_color IS 'Hardware color selected by user: white, black, silver, bronze, grey, beige. Used for BOM auto-select SKU resolution.';


--
-- Name: COLUMN "QuoteLines".cassette; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".cassette IS 'Whether cassette is enabled for this quote line. Used for BOM block_condition evaluation.';


--
-- Name: COLUMN "QuoteLines".side_channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".side_channel IS 'Whether side channel is enabled for this quote line. Used for BOM block_condition evaluation.';


--
-- Name: COLUMN "QuoteLines".drive_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".drive_type IS 'Drive type: manual or motor. Used for BOM block_condition evaluation and auto-select SKU resolution.';


--
-- Name: COLUMN "QuoteLines".bom_template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".bom_template_id IS 'Foreign key to BOMTemplates. Identifies which BOM template should be used for BOM generation.';


--
-- Name: COLUMN "QuoteLines".roll_cost_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".roll_cost_snapshot IS 'Snapshot del costo total del roll (material + import/shipping/labor si aplica) al momento de crear la QuoteLine.';


--
-- Name: COLUMN "QuoteLines".bom_cost_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".bom_cost_snapshot IS 'Snapshot del costo total del BOM al momento de crear la QuoteLine.';


--
-- Name: COLUMN "QuoteLines".roll_msrp_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".roll_msrp_snapshot IS 'Snapshot del MSRP del roll al momento de crear la QuoteLine.';


--
-- Name: COLUMN "QuoteLines".bom_msrp_snapshot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."QuoteLines".bom_msrp_snapshot IS 'Snapshot del MSRP del BOM al momento de crear la QuoteLine.';


--
-- Name: Quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Quotes" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_no text NOT NULL,
    status public.quote_status DEFAULT 'draft'::public.quote_status NOT NULL,
    tracking_status public.sales_order_tracking_status,
    customer_id uuid,
    contact_id uuid,
    created_by_user_id uuid,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    company_id uuid,
    created_by_portal_user_id uuid,
    currency text DEFAULT 'USD'::text NOT NULL,
    CONSTRAINT quotes_tracking_status_only_when_approved CHECK ((((status = 'approved'::public.quote_status) AND (tracking_status IS NOT NULL)) OR ((status <> 'approved'::public.quote_status) AND (tracking_status IS NULL))))
);


--
-- Name: TABLE "Quotes"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."Quotes" IS 'Quotes table - quotes are converted to SalesOrders when approved';


--
-- Name: COLUMN "Quotes".status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Quotes".status IS 'Status: draft, sent, approved, canceled';


--
-- Name: COLUMN "Quotes".tracking_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Quotes".tracking_status IS 'Tracking status. Only set when status=approved. NULL otherwise.';


--
-- Name: COLUMN "Quotes".customer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Quotes".customer_id IS 'FK to customer (nullable)';


--
-- Name: COLUMN "Quotes".contact_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."Quotes".contact_id IS 'FK to contact (nullable)';


--
-- Name: SaleOrderLines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."SaleOrderLines" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    sales_order_id uuid NOT NULL,
    quote_line_id uuid,
    catalog_item_id uuid,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    width_m numeric(12,4),
    height_m numeric(12,4),
    sqm numeric(12,4),
    unit_price numeric(12,4),
    line_total numeric(12,4),
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: SalesOrders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."SalesOrders" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    organization_id uuid NOT NULL,
    quote_id uuid NOT NULL,
    sales_order_no text NOT NULL,
    tracking_status public.sales_order_tracking_status DEFAULT 'pending_confirmation'::public.sales_order_tracking_status NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.sales_order_status DEFAULT 'draft'::public.sales_order_status NOT NULL,
    company_id uuid
);


--
-- Name: TABLE "SalesOrders"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public."SalesOrders" IS 'SalesOrders table - always created from approved Quotes via trigger';


--
-- Name: COLUMN "SalesOrders".quote_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."SalesOrders".quote_id IS 'FK to Quotes (1:1 unique). SalesOrder always created from Quote.';


--
-- Name: COLUMN "SalesOrders".tracking_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public."SalesOrders".tracking_status IS 'Tracking status - source of truth. Mirrored to OrderList.';


--
-- Name: stg_catalog_items_import_raw; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stg_catalog_items_import_raw (
    row_id bigint NOT NULL,
    id text,
    organization_id text,
    name text,
    sku text,
    unit_of_measure text,
    description text,
    category_id text,
    image_url text,
    measure_basis text,
    is_fabric text,
    collection_name text,
    variant_name text,
    roll_width text,
    fabric_pricing_mode text,
    color text,
    is_active text,
    created_at text,
    updated_at text,
    cost_exw text,
    manufacturer text,
    manufacturer_id text,
    is_roll text,
    roll_collection_id text,
    roll_type text,
    item_role text,
    product_type_id text,
    imported_at timestamp with time zone DEFAULT now() NOT NULL,
    import_batch_id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: stg_catalog_items_import_raw_row_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stg_catalog_items_import_raw_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stg_catalog_items_import_raw_row_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stg_catalog_items_import_raw_row_id_seq OWNED BY public.stg_catalog_items_import_raw.row_id;


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: messages_2026_02_17; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_02_17 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: messages_2026_02_18; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_02_18 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: messages_2026_02_19; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_02_19 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: messages_2026_02_20; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_02_20 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: messages_2026_02_21; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages_2026_02_21 (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: iceberg_namespaces; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_namespaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    catalog_id uuid NOT NULL
);


--
-- Name: iceberg_tables; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.iceberg_tables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    namespace_id uuid NOT NULL,
    bucket_name text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    location text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    remote_table_id text,
    shard_key text,
    shard_id text,
    catalog_id uuid NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb,
    level integer
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: prefixes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.prefixes (
    bucket_id text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    level integer GENERATED ALWAYS AS (storage.get_level(name)) STORED NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hooks; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.hooks (
    id bigint NOT NULL,
    hook_table_id integer NOT NULL,
    hook_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id bigint
);


--
-- Name: TABLE hooks; Type: COMMENT; Schema: supabase_functions; Owner: -
--

COMMENT ON TABLE supabase_functions.hooks IS 'Supabase Functions Hooks: Audit trail for triggered hooks.';


--
-- Name: hooks_id_seq; Type: SEQUENCE; Schema: supabase_functions; Owner: -
--

CREATE SEQUENCE supabase_functions.hooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hooks_id_seq; Type: SEQUENCE OWNED BY; Schema: supabase_functions; Owner: -
--

ALTER SEQUENCE supabase_functions.hooks_id_seq OWNED BY supabase_functions.hooks.id;


--
-- Name: migrations; Type: TABLE; Schema: supabase_functions; Owner: -
--

CREATE TABLE supabase_functions.migrations (
    version text NOT NULL,
    inserted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: messages_2026_02_17; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_02_17 FOR VALUES FROM ('2026-02-17 00:00:00') TO ('2026-02-18 00:00:00');


--
-- Name: messages_2026_02_18; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_02_18 FOR VALUES FROM ('2026-02-18 00:00:00') TO ('2026-02-19 00:00:00');


--
-- Name: messages_2026_02_19; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_02_19 FOR VALUES FROM ('2026-02-19 00:00:00') TO ('2026-02-20 00:00:00');


--
-- Name: messages_2026_02_20; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_02_20 FOR VALUES FROM ('2026-02-20 00:00:00') TO ('2026-02-21 00:00:00');


--
-- Name: messages_2026_02_21; Type: TABLE ATTACH; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages ATTACH PARTITION realtime.messages_2026_02_21 FOR VALUES FROM ('2026-02-21 00:00:00') TO ('2026-02-22 00:00:00');


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: stg_catalog_items_import_raw row_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stg_catalog_items_import_raw ALTER COLUMN row_id SET DEFAULT nextval('public.stg_catalog_items_import_raw_row_id_seq'::regclass);


--
-- Name: hooks id; Type: DEFAULT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks ALTER COLUMN id SET DEFAULT nextval('supabase_functions.hooks_id_seq'::regclass);


--
-- Data for Name: extensions; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at) FROM stdin;
d772ac08-32f3-4acc-a60b-52f71cb104e5	postgres_cdc_rls	{"region": "us-east-1", "db_host": "NZZcBLLjq3uH15B9FN6Macr+SFuefY59HG7PzXMcMoE=", "db_name": "sWBpZNdjggEPTQVlI52Zfw==", "db_port": "+enMDFi1J/3IrrquHHwUmA==", "db_user": "uxbEq/zz8DXVD53TOI1zmw==", "slot_name": "supabase_realtime_replication_slot", "db_password": "sWBpZNdjggEPTQVlI52Zfw==", "publication": "supabase_realtime", "ssl_enforced": false, "poll_interval_ms": 100, "poll_max_changes": 100, "poll_max_record_bytes": 1048576}	realtime-dev	2026-02-18 05:21:30	2026-02-18 05:21:30
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.schema_migrations (version, inserted_at) FROM stdin;
20210706140551	2026-02-03 17:06:47
20220329161857	2026-02-03 17:06:47
20220410212326	2026-02-03 17:06:47
20220506102948	2026-02-03 17:06:47
20220527210857	2026-02-03 17:06:47
20220815211129	2026-02-03 17:06:47
20220815215024	2026-02-03 17:06:47
20220818141501	2026-02-03 17:06:47
20221018173709	2026-02-03 17:06:47
20221102172703	2026-02-03 17:06:47
20221223010058	2026-02-03 17:06:47
20230110180046	2026-02-03 17:06:47
20230810220907	2026-02-03 17:06:47
20230810220924	2026-02-03 17:06:47
20231024094642	2026-02-03 17:06:47
20240306114423	2026-02-03 17:06:47
20240418082835	2026-02-03 17:06:47
20240625211759	2026-02-03 17:06:47
20240704172020	2026-02-03 17:06:47
20240902173232	2026-02-03 17:06:47
20241106103258	2026-02-03 17:06:47
20250424203323	2026-02-03 17:06:47
20250613072131	2026-02-03 17:06:47
20250711044927	2026-02-03 17:06:47
20250811121559	2026-02-03 17:06:47
20250926223044	2026-02-03 17:06:47
20251204170944	2026-02-03 17:06:47
\.


--
-- Data for Name: tenants; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.tenants (id, name, external_id, jwt_secret, max_concurrent_users, inserted_at, updated_at, max_events_per_second, postgres_cdc_default, max_bytes_per_second, max_channels_per_client, max_joins_per_second, suspend, jwt_jwks, notify_private_alpha, private_only, migrations_ran, broadcast_adapter, max_presence_events_per_second, max_payload_size_in_kb) FROM stdin;
1414007e-7bb5-4401-be08-7152b9666f6f	realtime-dev	realtime-dev	iNjicxc4+llvc9wovDvqymwfnj9teWMlyOIbJ8Fh6j2WNU8CIJ2ZgjR6MUIKqSmeDmvpsKLsZ9jgXJmQPpwL8w==	200	2026-02-18 05:21:30	2026-02-18 05:21:30	100	postgres_cdc_rls	100000	100	100	f	{"keys": [{"k": "c3VwZXItc2VjcmV0LWp3dC10b2tlbi13aXRoLWF0LWxlYXN0LTMyLWNoYXJhY3RlcnMtbG9uZw", "kty": "oct"}]}	f	f	65	gen_rpc	1000	3000
\.


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: BOMComponents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."BOMComponents" (id, organization_id, bom_template_id, component_item_id, component_role, qty_type, qty_value, qty_delta_mm, uom, waste_pct, auto_select, sku_resolution_rule, depends_on_role, cut_axis, cut_delta_mm, sort_order, deleted, archived, created_at, updated_at, component_mode, is_required, type_per_unit, component_scope, slot_id, qty_spacing_mm, qty_min, parent_component_id, component_sub_role, metadata) FROM stdin;
\.


--
-- Data for Name: BOMInstanceLines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."BOMInstanceLines" (id, bom_instance_id, bom_component_id, resolved_part_id, part_role, qty, uom, cut_length_mm, cut_width_mm, cut_height_mm, unit_cost_exw, total_cost_exw, created_at, organization_id, deleted, archived) FROM stdin;
834d5918-e784-49b3-8bd4-99fb0ed28be9	bdbea67d-3cf8-42b6-8eb3-d99568cd7fed	\N	8b77fc3f-428e-4f75-8240-d442ae9ac9a6	tube	3.0000	m	\N	\N	\N	\N	\N	2026-02-03 17:21:47.471678+00	39d507f3-49a0-48fa-861b-b1cef4a000ce	f	f
\.


--
-- Data for Name: BOMInstances; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."BOMInstances" (id, organization_id, quote_line_id, bom_template_id, deleted, created_at, updated_at, configured_product_id, archived) FROM stdin;
bdbea67d-3cf8-42b6-8eb3-d99568cd7fed	39d507f3-49a0-48fa-861b-b1cef4a000ce	2e4d58d8-3089-4d84-a62d-535f02459f68	3f5d16c6-e415-4759-b1db-bc0e5e42f053	t	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	8949c7c1-b510-405c-8fd4-2b6de6ecc9c6	f
fc920fef-ec0e-45c7-8fd2-a6a63e4bcccd	39d507f3-49a0-48fa-861b-b1cef4a000ce	2e4d58d8-3089-4d84-a62d-535f02459f68	3f5d16c6-e415-4759-b1db-bc0e5e42f053	f	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	\N	f
\.


--
-- Data for Name: BOMTemplateSlots; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."BOMTemplateSlots" (id, organization_id, bom_template_id, item_role, required, catalog_item_id, qty, notes, created_at, updated_at, selection_mode, fixed_catalog_item_id, slot_sku, deleted, archived) FROM stdin;
\.


--
-- Data for Name: BOMTemplates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."BOMTemplates" (id, organization_id, product_type_id, code, name, archived, created_at, updated_at, is_active, hardware_color, sort_order, description, metadata, deleted) FROM stdin;
3f5d16c6-e415-4759-b1db-bc0e5e42f053	39d507f3-49a0-48fa-861b-b1cef4a000ce	fd5ac3f2-6277-4441-8aa9-4b4005b82183	TMP_TEST3	Template Test 3	f	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	t	\N	0	\N	{}	f
\.


--
-- Data for Name: CatalogCategories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogCategories" (id, organization_id, name, sort_order, parent_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: CatalogItemComponents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemComponents" (id, organization_id, parent_item_id, child_item_id, child_role, qty, uom, required, notes, sort_order, deleted, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: CatalogItemConversions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemConversions" (catalog_item_id, organization_id, cost_exw_input, unit_of_measure_input, roll_width_input, cost_exw_per_m, cost_exw_per_m2, computed_at, cost_exw_per_ea) FROM stdin;
\.


--
-- Data for Name: CatalogItemProductTypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemProductTypes" (id, organization_id, catalog_item_id, product_type_id, created_at, catalog_item_sku, catalog_item_name) FROM stdin;
\.


--
-- Data for Name: CatalogItemRoles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemRoles" (role_code, label, description, default_category_id, sort_order, active, created_at, updated_at, role_name, role_description, is_active) FROM stdin;
\.


--
-- Data for Name: CatalogItemRollSpecs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemRollSpecs" (catalog_item_id, organization_id, can_rotate, is_weldable, raw_material, openness_factor_pct, weight_g_m2, weight_kg_m2, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: CatalogItemSupply; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemSupply" (catalog_item_id, organization_id, supply_type, supply_origin, lead_time_min_days, lead_time_max_days, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: CatalogItems; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItems" (id, organization_id, name, sku, unit_of_measure, description, category_id, image_url, measure_basis, collection_name, variant_name, roll_width, color, is_active, created_at, updated_at, cost_exw, manufacturer, manufacturer_id, is_roll, roll_collection_id, roll_type, item_role, roll_pricing_mode, units_per_purchase_unit, purchase_unit, roll_width_value, roll_width_uom, roll_width_m, roll_length_value, roll_length_uom, roll_length_m) FROM stdin;
8eeb5d18-3b52-4e2d-89ad-f0cf91b31c7f	39d507f3-49a0-48fa-861b-b1cef4a000ce	Fabric	FAB_TEST3	m2	\N	\N	\N	area	\N	\N	2.0000	\N	t	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	\N	\N	\N	t	\N	fabric	\N	per_square_meter	1.0000	each	\N	\N	2.0	\N	\N	\N
8b77fc3f-428e-4f75-8240-d442ae9ac9a6	39d507f3-49a0-48fa-861b-b1cef4a000ce	Tube	TUBE_TEST3	m	\N	\N	\N	linear	\N	\N	\N	\N	t	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	\N	\N	\N	f	\N	\N	\N	\N	1.0000	each	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: CatalogItemsMSRP; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogItemsMSRP" (catalog_item_id, organization_id, category_id, cost_exw, import_tax_cost, shipping_cost, total_cost, sku, name, collection_name, variant_name, updated_at, unit_of_measure, shipping_pct, import_tax_pct, minimum_margin_pct, msrp_pct_sale_out, dealer_price, msrp) FROM stdin;
8eeb5d18-3b52-4e2d-89ad-f0cf91b31c7f	39d507f3-49a0-48fa-861b-b1cef4a000ce	\N	0.0000	0.0000	0.0000	0.0000	FAB_TEST3	Fabric	\N	\N	2026-02-03 17:21:47.471678+00	m2	0.0000	0.0000	0.0000	0.0000	0.000000	0.000000
8b77fc3f-428e-4f75-8240-d442ae9ac9a6	39d507f3-49a0-48fa-861b-b1cef4a000ce	\N	0.0000	0.0000	0.0000	0.0000	TUBE_TEST3	Tube	\N	\N	2026-02-03 17:21:47.471678+00	m	0.0000	0.0000	0.0000	0.0000	0.000000	0.000000
\.


--
-- Data for Name: CatalogRoleCategoryMap; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CatalogRoleCategoryMap" (organization_id, role_code, target_category_id, notes, updated_at) FROM stdin;
\.


--
-- Data for Name: CategoryMargins; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CategoryMargins" (id, organization_id, category_id, msrp_pct_sale_in, is_active, created_at, updated_at, msrp_pct_sale_out) FROM stdin;
\.


--
-- Data for Name: Companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Companies" (id, organization_id, company_name, company_email, company_phone, status, deleted, created_at, updated_at, company_no, customer_type, identification_number, website, alt_phone, primary_contact_id, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_same_as_location, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country, notes) FROM stdin;
2bcedbfc-dcb0-4a4c-83fa-bb5a350ba3fa	39d507f3-49a0-48fa-861b-b1cef4a000ce	Test Company	\N	\N	active	f	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	1002	reseller	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: CompanyPortalUsers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CompanyPortalUsers" (id, user_id, status, invited_by_user_id, invited_at, accepted_at, deleted, created_at, updated_at, organization_id, portal_user_email, portal_user_name, company_id, role, must_change_password, temp_password_set_at) FROM stdin;
\.


--
-- Data for Name: ConfiguredProducts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."ConfiguredProducts" (id, organization_id, quote_id, bom_template_id, product_type_id, width_mm, height_mm, quantity, hardware_color, bom_total, labor_pct, accessories_total, total_msrp, config_snapshot, metadata, created_at, updated_at, deleted, roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_width, roll_msrp_total, roll_plus_bom_total, bottom_bar_item_id, bottom_bar_sku, headbox_item_id, headbox_sku, side_channel_item_id, side_channel_sku, bottom_channel_item_id, bottom_channel_sku, motor_item_id, motor_sku, drive_item_id, drive_sku, tube_item_id, tube_sku, operating_type, roll_total_cost, bom_total_cost, labor_amount) FROM stdin;
8949c7c1-b510-405c-8fd4-2b6de6ecc9c6	39d507f3-49a0-48fa-861b-b1cef4a000ce	58f9c5a1-ea07-4978-b6db-3afd0e9f1a3a	3f5d16c6-e415-4759-b1db-bc0e5e42f053	fd5ac3f2-6277-4441-8aa9-4b4005b82183	1000.0000	1500.0000	2.0000	\N	0.0000	10.00	0.0000	0.0000	{}	{}	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	f	8eeb5d18-3b52-4e2d-89ad-f0cf91b31c7f	\N	\N	\N	2.0000	0.0000	0.0000	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0.0000	0.0000	0.0000
\.


--
-- Data for Name: CostSettings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."CostSettings" (organization_id, labor_pct, shipping_pct, global_import_tax_pct, minimum_margin_pct, reseller_discount_pct, distributor_discount_pct, partner_discount_pct, vip_discount_pct, created_at, updated_at, is_active, default_msrp_pct_sale_out, default_margin_pct, discount_reseller_pct, discount_distributor_pct, discount_partner_pct, discount_vip_pct) FROM stdin;
\.


--
-- Data for Name: DirectoryContacts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."DirectoryContacts" (id, organization_id, customer_id, phone, deleted, created_at, updated_at, contact_name, contact_email, contact_phone, contact_title, notes, company_id, contact_id_number, contact_type, contact_primary_phone, contact_cell_phone, contact_alt_phone, contact_street_address, contact_street_address_2, contact_city, contact_state, contact_zip_code, contact_country) FROM stdin;
\.


--
-- Data for Name: DirectoryCustomers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."DirectoryCustomers" (id, organization_id, status, deleted, created_at, updated_at, customer_name, customer_email, customer_phone, customer_status, notes, company_id, identification_number, customer_type_name, website, alt_phone, primary_contact_id, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country) FROM stdin;
\.


--
-- Data for Name: ImportTaxRules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."ImportTaxRules" (id, organization_id, category_id, import_tax_pct, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: Manufacturers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Manufacturers" (id, organization_id, name, code, website, notes, deleted, archived, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: ManufacturingOrders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."ManufacturingOrders" (id, organization_id, sales_order_id, manufacturing_order_no, status, priority, deleted, created_at, updated_at, company_id) FROM stdin;
\.


--
-- Data for Name: OrderList; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."OrderList" (id, organization_id, sales_order_id, tracking_status, deleted, created_at, updated_at, company_id) FROM stdin;
\.


--
-- Data for Name: OrganizationUserPermissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."OrganizationUserPermissions" (organization_user_id, permission_code, created_at) FROM stdin;
\.


--
-- Data for Name: OrganizationUsers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."OrganizationUsers" (id, organization_id, user_id, user_email, user_name, role, status, invited_by_user_id, invited_at, accepted_at, deleted, created_at, updated_at, must_change_password, temp_password_set_at) FROM stdin;
\.


--
-- Data for Name: Organizations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Organizations" (id, name, created_at, updated_at, deleted, company_no_prefix, next_company_no) FROM stdin;
5876fd37-11fc-4bad-8e4e-b745908282b6	Tmp Org 2	2026-02-03 17:18:04.428141+00	2026-02-03 17:18:04.428141+00	f	AP	1001
b621886e-0e77-4f0b-8ba4-d00395ce3837	Tmp Org 3	2026-02-03 17:18:20.387858+00	2026-02-03 17:18:20.387858+00	f	AP	1001
39d507f3-49a0-48fa-861b-b1cef4a000ce	Tmp Org	2026-02-03 17:17:42.471197+00	2026-02-03 17:21:47.471678+00	f	AP	1002
\.


--
-- Data for Name: Permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Permissions" (code, module, description) FROM stdin;
\.


--
-- Data for Name: ProductTypeRoleRules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."ProductTypeRoleRules" (id, organization_id, product_type_id, role_code, is_required, active, notes, created_at, updated_at, deleted, archived) FROM stdin;
\.


--
-- Data for Name: ProductTypes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."ProductTypes" (id, organization_id, code, name, sort_order, created_at, updated_at) FROM stdin;
fd5ac3f2-6277-4441-8aa9-4b4005b82183	39d507f3-49a0-48fa-861b-b1cef4a000ce	roller_shade_test3	Roller Shade Test 3	0	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00
\.


--
-- Data for Name: QuoteLineComponents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."QuoteLineComponents" (id, organization_id, quote_line_id, component_role, kind, source, catalog_item_id, qty, unit_cost_exw, payload, deleted, archived, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: QuoteLineCosts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."QuoteLineCosts" (id, organization_id, quote_id, quote_line_id, quantity, cost_exw, material_cost, labor_pct, labor_cost, shipping_pct, shipping_cost, import_tax_pct, import_tax_cost, total_cost, pricing_version, created_at) FROM stdin;
\.


--
-- Data for Name: QuoteLines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."QuoteLines" (id, organization_id, company_id, quote_id, catalog_item_id, category_id, sku, name, manufacturer_id, manufacturer, pricing_basis, unit_of_measure, quantity, width_m, height_m, is_roll, roll_type, collection_name, variant_name, roll_width_m, fabric_pricing_mode, drop_m, sqm, cost_exw, labor_pct, shipping_pct, import_tax_pct, default_margin_pct, minimum_margin_pct, discount_pct, material_cost, labor_cost, shipping_cost, import_tax_cost, total_cost, applied_margin_pct, msrp, net_price, pricing_version, pricing_locked, last_priced_at, created_at, updated_at, collection_id, variant_id, product_type, area, "position", hardware_color, cassette, side_channel, drive_type, bom_template_id, roll_cost_snapshot, bom_cost_snapshot, roll_msrp_snapshot, bom_msrp_snapshot, configured_product_id) FROM stdin;
2e4d58d8-3089-4d84-a62d-535f02459f68	39d507f3-49a0-48fa-861b-b1cef4a000ce	2bcedbfc-dcb0-4a4c-83fa-bb5a350ba3fa	58f9c5a1-ea07-4978-b6db-3afd0e9f1a3a	\N	\N	\N	\N	\N	\N	\N	\N	1.0000	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1	t	\N	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	\N	\N	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: Quotes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Quotes" (id, organization_id, quote_no, status, tracking_status, customer_id, contact_id, created_by_user_id, deleted, created_at, updated_at, company_id, created_by_portal_user_id, currency) FROM stdin;
58f9c5a1-ea07-4978-b6db-3afd0e9f1a3a	39d507f3-49a0-48fa-861b-b1cef4a000ce	Q_TEST_1c9d1b7e	draft	\N	\N	\N	\N	f	2026-02-03 17:21:47.471678+00	2026-02-03 17:21:47.471678+00	2bcedbfc-dcb0-4a4c-83fa-bb5a350ba3fa	\N	USD
\.


--
-- Data for Name: SaleOrderLines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."SaleOrderLines" (id, organization_id, sales_order_id, quote_line_id, catalog_item_id, quantity, width_m, height_m, sqm, unit_price, line_total, deleted, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: SalesOrders; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."SalesOrders" (id, organization_id, quote_id, sales_order_no, tracking_status, deleted, created_at, updated_at, status, company_id) FROM stdin;
\.


--
-- Data for Name: stg_catalog_items_import_raw; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stg_catalog_items_import_raw (row_id, id, organization_id, name, sku, unit_of_measure, description, category_id, image_url, measure_basis, is_fabric, collection_name, variant_name, roll_width, fabric_pricing_mode, color, is_active, created_at, updated_at, cost_exw, manufacturer, manufacturer_id, is_roll, roll_collection_id, roll_type, item_role, product_type_id, imported_at, import_batch_id) FROM stdin;
\.


--
-- Data for Name: messages_2026_02_17; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_02_17 (topic, extension, payload, event, private, updated_at, inserted_at, id) FROM stdin;
\.


--
-- Data for Name: messages_2026_02_18; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_02_18 (topic, extension, payload, event, private, updated_at, inserted_at, id) FROM stdin;
\.


--
-- Data for Name: messages_2026_02_19; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_02_19 (topic, extension, payload, event, private, updated_at, inserted_at, id) FROM stdin;
\.


--
-- Data for Name: messages_2026_02_20; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_02_20 (topic, extension, payload, event, private, updated_at, inserted_at, id) FROM stdin;
\.


--
-- Data for Name: messages_2026_02_21; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.messages_2026_02_21 (topic, extension, payload, event, private, updated_at, inserted_at, id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2026-02-03 17:06:48
20211116045059	2026-02-03 17:06:48
20211116050929	2026-02-03 17:06:48
20211116051442	2026-02-03 17:06:48
20211116212300	2026-02-03 17:06:48
20211116213355	2026-02-03 17:06:48
20211116213934	2026-02-03 17:06:48
20211116214523	2026-02-03 17:06:48
20211122062447	2026-02-03 17:06:48
20211124070109	2026-02-03 17:06:48
20211202204204	2026-02-03 17:06:48
20211202204605	2026-02-03 17:06:48
20211210212804	2026-02-03 17:06:48
20211228014915	2026-02-03 17:06:48
20220107221237	2026-02-03 17:06:48
20220228202821	2026-02-03 17:06:48
20220312004840	2026-02-03 17:06:48
20220603231003	2026-02-03 17:06:48
20220603232444	2026-02-03 17:06:48
20220615214548	2026-02-03 17:06:48
20220712093339	2026-02-03 17:06:48
20220908172859	2026-02-03 17:06:48
20220916233421	2026-02-03 17:06:48
20230119133233	2026-02-03 17:06:48
20230128025114	2026-02-03 17:06:48
20230128025212	2026-02-03 17:06:48
20230227211149	2026-02-03 17:06:48
20230228184745	2026-02-03 17:06:48
20230308225145	2026-02-03 17:06:48
20230328144023	2026-02-03 17:06:48
20231018144023	2026-02-03 17:06:48
20231204144023	2026-02-03 17:06:48
20231204144024	2026-02-03 17:06:48
20231204144025	2026-02-03 17:06:48
20240108234812	2026-02-03 17:06:48
20240109165339	2026-02-03 17:06:48
20240227174441	2026-02-03 17:06:48
20240311171622	2026-02-03 17:06:48
20240321100241	2026-02-03 17:06:48
20240401105812	2026-02-03 17:06:48
20240418121054	2026-02-03 17:06:48
20240523004032	2026-02-03 17:06:48
20240618124746	2026-02-03 17:06:48
20240801235015	2026-02-03 17:06:48
20240805133720	2026-02-03 17:06:48
20240827160934	2026-02-03 17:06:48
20240919163303	2026-02-03 17:06:48
20240919163305	2026-02-03 17:06:48
20241019105805	2026-02-03 17:06:48
20241030150047	2026-02-03 17:06:48
20241108114728	2026-02-03 17:06:48
20241121104152	2026-02-03 17:06:48
20241130184212	2026-02-03 17:06:48
20241220035512	2026-02-03 17:06:48
20241220123912	2026-02-03 17:06:48
20241224161212	2026-02-03 17:06:48
20250107150512	2026-02-03 17:06:48
20250110162412	2026-02-03 17:06:48
20250123174212	2026-02-03 17:06:48
20250128220012	2026-02-03 17:06:48
20250506224012	2026-02-03 17:06:48
20250523164012	2026-02-03 17:06:48
20250714121412	2026-02-03 17:06:48
20250905041441	2026-02-03 17:06:48
20251103001201	2026-02-03 17:06:48
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: iceberg_namespaces; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.iceberg_namespaces (id, bucket_name, name, created_at, updated_at, metadata, catalog_id) FROM stdin;
\.


--
-- Data for Name: iceberg_tables; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.iceberg_tables (id, namespace_id, bucket_name, name, location, created_at, updated_at, remote_table_id, shard_key, shard_id, catalog_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-02-03 17:06:49.658996
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-02-03 17:06:49.66017
2	storage-schema	5c7968fd083fcea04050c1b7f6253c9771b99011	2026-02-03 17:06:49.660741
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-02-03 17:06:49.664128
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-02-03 17:06:49.666129
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-02-03 17:06:49.666538
6	change-column-name-in-get-size	f93f62afdf6613ee5e7e815b30d02dc990201044	2026-02-03 17:06:49.668221
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-02-03 17:06:49.668939
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-02-03 17:06:49.669308
9	fix-search-function	3a0af29f42e35a4d101c259ed955b67e1bee6825	2026-02-03 17:06:49.669728
10	search-files-search-function	68dc14822daad0ffac3746a502234f486182ef6e	2026-02-03 17:06:49.670348
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-02-03 17:06:49.671284
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-02-03 17:06:49.671999
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-02-03 17:06:49.672414
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-02-03 17:06:49.67282
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-02-03 17:06:49.677162
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-02-03 17:06:49.677682
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-02-03 17:06:49.678087
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-02-03 17:06:49.678574
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-02-03 17:06:49.679418
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-02-03 17:06:49.679847
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-02-03 17:06:49.680777
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-02-03 17:06:49.683358
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-02-03 17:06:49.685198
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-02-03 17:06:49.685783
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-02-03 17:06:49.686267
26	objects-prefixes	ef3f7871121cdc47a65308e6702519e853422ae2	2026-02-03 17:06:49.686865
27	search-v2	33b8f2a7ae53105f028e13e9fcda9dc4f356b4a2	2026-02-03 17:06:49.689603
28	object-bucket-name-sorting	ba85ec41b62c6a30a3f136788227ee47f311c436	2026-02-03 17:06:49.691047
29	create-prefixes	a7b1a22c0dc3ab630e3055bfec7ce7d2045c5b7b	2026-02-03 17:06:49.69191
30	update-object-levels	6c6f6cc9430d570f26284a24cf7b210599032db7	2026-02-03 17:06:49.692528
31	objects-level-index	33f1fef7ec7fea08bb892222f4f0f5d79bab5eb8	2026-02-03 17:06:49.693219
32	backward-compatible-index-on-objects	2d51eeb437a96868b36fcdfb1ddefdf13bef1647	2026-02-03 17:06:49.694172
33	backward-compatible-index-on-prefixes	fe473390e1b8c407434c0e470655945b110507bf	2026-02-03 17:06:49.694939
34	optimize-search-function-v1	82b0e469a00e8ebce495e29bfa70a0797f7ebd2c	2026-02-03 17:06:49.695102
35	add-insert-trigger-prefixes	63bb9fd05deb3dc5e9fa66c83e82b152f0caf589	2026-02-03 17:06:49.696405
36	optimise-existing-functions	81cf92eb0c36612865a18016a38496c530443899	2026-02-03 17:06:49.696776
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-02-03 17:06:49.698439
38	iceberg-catalog-flag-on-buckets	19a8bd89d5dfa69af7f222a46c726b7c41e462c5	2026-02-03 17:06:49.699025
39	add-search-v2-sort-support	39cf7d1e6bf515f4b02e41237aba845a7b492853	2026-02-03 17:06:49.702213
40	fix-prefix-race-conditions-optimized	fd02297e1c67df25a9fc110bf8c8a9af7fb06d1f	2026-02-03 17:06:49.702881
41	add-object-level-update-trigger	44c22478bf01744b2129efc480cd2edc9a7d60e9	2026-02-03 17:06:49.704746
42	rollback-prefix-triggers	f2ab4f526ab7f979541082992593938c05ee4b47	2026-02-03 17:06:49.705723
43	fix-object-level	ab837ad8f1c7d00cc0b7310e989a23388ff29fc6	2026-02-03 17:06:49.70645
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-02-03 17:06:49.706939
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-02-03 17:06:49.70739
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-02-03 17:06:49.709131
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-02-03 17:06:49.709561
48	iceberg-catalog-ids	2666dff93346e5d04e0a878416be1d5fec345d6f	2026-02-03 17:06:49.710333
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-02-03 17:06:49.717065
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata, level) FROM stdin;
\.


--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.prefixes (bucket_id, name, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.hooks (id, hook_table_id, hook_name, created_at, request_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.migrations (version, inserted_at) FROM stdin;
initial	2026-02-03 17:06:37.584267+00
20210809183423_update_grants	2026-02-03 17:06:37.584267+00
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: stg_catalog_items_import_raw_row_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.stg_catalog_items_import_raw_row_id_seq', 1, false);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: -
--

SELECT pg_catalog.setval('supabase_functions.hooks_id_seq', 1, false);


--
-- Name: extensions extensions_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: BOMComponents BOMComponents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMComponents"
    ADD CONSTRAINT "BOMComponents_pkey" PRIMARY KEY (id);


--
-- Name: BOMTemplateSlots BOMTemplateSlots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_pkey" PRIMARY KEY (id);


--
-- Name: BOMTemplates BOMTemplates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_pkey" PRIMARY KEY (id);


--
-- Name: BOMTemplates BOMTemplates_unique_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplates"
    ADD CONSTRAINT "BOMTemplates_unique_code" UNIQUE (organization_id, code);


--
-- Name: BOMInstanceLines BomInstanceLines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstanceLines"
    ADD CONSTRAINT "BomInstanceLines_pkey" PRIMARY KEY (id);


--
-- Name: BOMInstances BomInstances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstances"
    ADD CONSTRAINT "BomInstances_pkey" PRIMARY KEY (id);


--
-- Name: CatalogCategories CatalogCategories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogCategories"
    ADD CONSTRAINT "CatalogCategories_pkey" PRIMARY KEY (id);


--
-- Name: CatalogItemConversions CatalogItemConversions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemConversions"
    ADD CONSTRAINT "CatalogItemConversions_pkey" PRIMARY KEY (catalog_item_id);


--
-- Name: CatalogItemProductTypes CatalogItemProductTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemProductTypes"
    ADD CONSTRAINT "CatalogItemProductTypes_pkey" PRIMARY KEY (id);


--
-- Name: CatalogItemRoles CatalogItemRoles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemRoles"
    ADD CONSTRAINT "CatalogItemRoles_pkey" PRIMARY KEY (role_code);


--
-- Name: CatalogItemRollSpecs CatalogItemRollSpecs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemRollSpecs"
    ADD CONSTRAINT "CatalogItemRollSpecs_pkey" PRIMARY KEY (catalog_item_id);


--
-- Name: CatalogItemSupply CatalogItemSupply_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemSupply"
    ADD CONSTRAINT "CatalogItemSupply_pkey" PRIMARY KEY (catalog_item_id);


--
-- Name: CatalogItemsMSRP CatalogItemsMSRP_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT "CatalogItemsMSRP_pkey" PRIMARY KEY (catalog_item_id);


--
-- Name: CatalogItems CatalogItems_organization_id_sku_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItems"
    ADD CONSTRAINT "CatalogItems_organization_id_sku_key" UNIQUE (organization_id, sku);


--
-- Name: CatalogItems CatalogItems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItems"
    ADD CONSTRAINT "CatalogItems_pkey" PRIMARY KEY (id);


--
-- Name: CatalogRoleCategoryMap CatalogRoleCategoryMap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_pkey" PRIMARY KEY (organization_id, role_code);


--
-- Name: CategoryMargins CategoryMargins_organization_id_category_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CategoryMargins"
    ADD CONSTRAINT "CategoryMargins_organization_id_category_id_key" UNIQUE (organization_id, category_id);


--
-- Name: CategoryMargins CategoryMargins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CategoryMargins"
    ADD CONSTRAINT "CategoryMargins_pkey" PRIMARY KEY (id);


--
-- Name: Companies Companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Companies"
    ADD CONSTRAINT "Companies_pkey" PRIMARY KEY (id);


--
-- Name: CostSettings CostSettings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CostSettings"
    ADD CONSTRAINT "CostSettings_pkey" PRIMARY KEY (organization_id);


--
-- Name: CompanyPortalUsers CustomerPortalUsers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_pkey" PRIMARY KEY (id);


--
-- Name: DirectoryContacts DirectoryContacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_pkey" PRIMARY KEY (id);


--
-- Name: DirectoryCustomers DirectoryCustomers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_pkey" PRIMARY KEY (id);


--
-- Name: ImportTaxRules ImportTaxRules_organization_id_category_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_organization_id_category_id_key" UNIQUE (organization_id, category_id);


--
-- Name: ImportTaxRules ImportTaxRules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ImportTaxRules"
    ADD CONSTRAINT "ImportTaxRules_pkey" PRIMARY KEY (id);


--
-- Name: Manufacturers Manufacturers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Manufacturers"
    ADD CONSTRAINT "Manufacturers_pkey" PRIMARY KEY (id);


--
-- Name: ManufacturingOrders ManufacturingOrders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_pkey" PRIMARY KEY (id);


--
-- Name: OrderList OrderList_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrderList"
    ADD CONSTRAINT "OrderList_pkey" PRIMARY KEY (id);


--
-- Name: OrganizationUserPermissions OrganizationUserPermissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_pkey" PRIMARY KEY (organization_user_id, permission_code);


--
-- Name: OrganizationUsers OrganizationUsers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_pkey" PRIMARY KEY (id);


--
-- Name: Organizations Organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Organizations"
    ADD CONSTRAINT "Organizations_pkey" PRIMARY KEY (id);


--
-- Name: Permissions Permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Permissions"
    ADD CONSTRAINT "Permissions_pkey" PRIMARY KEY (code);


--
-- Name: ProductTypeRoleRules ProductTypeRoleRules_organization_id_product_type_id_role_c_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_organization_id_product_type_id_role_c_key" UNIQUE (organization_id, product_type_id, role_code);


--
-- Name: ProductTypeRoleRules ProductTypeRoleRules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_pkey" PRIMARY KEY (id);


--
-- Name: ProductTypes ProductTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypes"
    ADD CONSTRAINT "ProductTypes_pkey" PRIMARY KEY (id);


--
-- Name: QuoteLineComponents QuoteLineComponents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLineComponents"
    ADD CONSTRAINT "QuoteLineComponents_pkey" PRIMARY KEY (id);


--
-- Name: QuoteLineCosts QuoteLineCosts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLineCosts"
    ADD CONSTRAINT "QuoteLineCosts_pkey" PRIMARY KEY (id);


--
-- Name: QuoteLines QuoteLines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLines"
    ADD CONSTRAINT "QuoteLines_pkey" PRIMARY KEY (id);


--
-- Name: Quotes Quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Quotes"
    ADD CONSTRAINT "Quotes_pkey" PRIMARY KEY (id);


--
-- Name: SaleOrderLines SaleOrderLines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SaleOrderLines"
    ADD CONSTRAINT "SaleOrderLines_pkey" PRIMARY KEY (id);


--
-- Name: SalesOrders SalesOrders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SalesOrders"
    ADD CONSTRAINT "SalesOrders_pkey" PRIMARY KEY (id);


--
-- Name: CatalogItemComponents catalogitemcomponents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemComponents"
    ADD CONSTRAINT catalogitemcomponents_pkey PRIMARY KEY (id);


--
-- Name: CatalogItemsMSRP catalogitemsmsrp_org_item_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT catalogitemsmsrp_org_item_unique UNIQUE (organization_id, catalog_item_id);


--
-- Name: CategoryMargins categorymargins_org_category_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CategoryMargins"
    ADD CONSTRAINT categorymargins_org_category_unique UNIQUE (organization_id, category_id);


--
-- Name: Companies companies_org_company_no_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Companies"
    ADD CONSTRAINT companies_org_company_no_uniq UNIQUE (organization_id, company_no);


--
-- Name: ConfiguredProducts configuredproducts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_pkey PRIMARY KEY (id);


--
-- Name: ImportTaxRules importtaxrules_org_category_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ImportTaxRules"
    ADD CONSTRAINT importtaxrules_org_category_unique UNIQUE (organization_id, category_id);


--
-- Name: OrganizationUsers organizationusers_org_email_uq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUsers"
    ADD CONSTRAINT organizationusers_org_email_uq UNIQUE (organization_id, user_email);


--
-- Name: ProductTypes producttypes_unique_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypes"
    ADD CONSTRAINT producttypes_unique_code UNIQUE (organization_id, code);


--
-- Name: ProductTypes producttypes_unique_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypes"
    ADD CONSTRAINT producttypes_unique_name UNIQUE (organization_id, name);


--
-- Name: stg_catalog_items_import_raw stg_catalog_items_import_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stg_catalog_items_import_raw
    ADD CONSTRAINT stg_catalog_items_import_raw_pkey PRIMARY KEY (row_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_02_17 messages_2026_02_17_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_02_17
    ADD CONSTRAINT messages_2026_02_17_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_02_18 messages_2026_02_18_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_02_18
    ADD CONSTRAINT messages_2026_02_18_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_02_19 messages_2026_02_19_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_02_19
    ADD CONSTRAINT messages_2026_02_19_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_02_20 messages_2026_02_20_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_02_20
    ADD CONSTRAINT messages_2026_02_20_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: messages_2026_02_21 messages_2026_02_21_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages_2026_02_21
    ADD CONSTRAINT messages_2026_02_21_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: iceberg_namespaces iceberg_namespaces_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_pkey PRIMARY KEY (id);


--
-- Name: iceberg_tables iceberg_tables_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: prefixes prefixes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT prefixes_pkey PRIMARY KEY (bucket_id, level, name);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: hooks hooks_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.hooks
    ADD CONSTRAINT hooks_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: supabase_functions; Owner: -
--

ALTER TABLE ONLY supabase_functions.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (version);


--
-- Name: extensions_tenant_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE INDEX extensions_tenant_external_id_index ON _realtime.extensions USING btree (tenant_external_id);


--
-- Name: extensions_tenant_external_id_type_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX extensions_tenant_external_id_type_index ON _realtime.extensions USING btree (tenant_external_id, type);


--
-- Name: tenants_external_id_index; Type: INDEX; Schema: _realtime; Owner: -
--

CREATE UNIQUE INDEX tenants_external_id_index ON _realtime.tenants USING btree (external_id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: bomcomponents_unique_slot_override; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bomcomponents_unique_slot_override ON public."BOMComponents" USING btree (organization_id, bom_template_id, slot_id) WHERE (slot_id IS NOT NULL);


--
-- Name: bominstancelines_instance_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bominstancelines_instance_idx ON public."BOMInstanceLines" USING btree (bom_instance_id);


--
-- Name: bominstancelines_org_deleted_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bominstancelines_org_deleted_idx ON public."BOMInstanceLines" USING btree (organization_id, deleted) WHERE (deleted = false);


--
-- Name: bominstances_one_per_quoteline_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bominstances_one_per_quoteline_uq ON public."BOMInstances" USING btree (quote_line_id) WHERE (COALESCE(deleted, false) = false);


--
-- Name: bominstances_unique_quote_line; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bominstances_unique_quote_line ON public."BOMInstances" USING btree (organization_id, quote_line_id) WHERE (deleted = false);


--
-- Name: bomtemplateslots_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bomtemplateslots_role_idx ON public."BOMTemplateSlots" USING btree (item_role);


--
-- Name: bomtemplateslots_template_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bomtemplateslots_template_idx ON public."BOMTemplateSlots" USING btree (bom_template_id);


--
-- Name: catalog_item_roll_specs_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalog_item_roll_specs_org_idx ON public."CatalogItemRollSpecs" USING btree (organization_id);


--
-- Name: catalog_item_supply_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalog_item_supply_org_idx ON public."CatalogItemSupply" USING btree (organization_id);


--
-- Name: catalogcategories_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogcategories_org_idx ON public."CatalogCategories" USING btree (organization_id);


--
-- Name: catalogcategories_org_parent_lowername_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogcategories_org_parent_lowername_uidx ON public."CatalogCategories" USING btree (organization_id, parent_id, lower(name));


--
-- Name: catalogcategories_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogcategories_parent_idx ON public."CatalogCategories" USING btree (organization_id, parent_id);


--
-- Name: catalogcategories_unique_siblings; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogcategories_unique_siblings ON public."CatalogCategories" USING btree (organization_id, parent_id, lower(name));


--
-- Name: catalogitemcomponents_unique_parent_child; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogitemcomponents_unique_parent_child ON public."CatalogItemComponents" USING btree (organization_id, parent_item_id, child_item_id) WHERE (deleted = false);


--
-- Name: catalogitemproducttypes_by_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitemproducttypes_by_item ON public."CatalogItemProductTypes" USING btree (organization_id, catalog_item_id);


--
-- Name: catalogitemproducttypes_by_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitemproducttypes_by_type ON public."CatalogItemProductTypes" USING btree (organization_id, product_type_id);


--
-- Name: catalogitemproducttypes_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogitemproducttypes_unique ON public."CatalogItemProductTypes" USING btree (organization_id, catalog_item_id, product_type_id);


--
-- Name: catalogitemroles_role_code_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogitemroles_role_code_uniq ON public."CatalogItemRoles" USING btree (role_code);


--
-- Name: catalogitems_category_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitems_category_idx ON public."CatalogItems" USING btree (organization_id, category_id);


--
-- Name: catalogitems_manufacturer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitems_manufacturer_id_idx ON public."CatalogItems" USING btree (organization_id, manufacturer_id);


--
-- Name: catalogitems_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitems_org_idx ON public."CatalogItems" USING btree (organization_id);


--
-- Name: catalogitems_org_roll_collection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogitems_org_roll_collection_idx ON public."CatalogItems" USING btree (organization_id, roll_collection_id);


--
-- Name: catalogitemsmsrp_catalog_item_id_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX catalogitemsmsrp_catalog_item_id_uq ON public."CatalogItemsMSRP" USING btree (catalog_item_id);


--
-- Name: companies_org_company_no_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX companies_org_company_no_unique ON public."Companies" USING btree (organization_id, company_no) WHERE (company_no IS NOT NULL);


--
-- Name: INDEX companies_org_company_no_unique; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.companies_org_company_no_unique IS 'Ensure unique company_no per organization (only when company_no is set)';


--
-- Name: companyportal_company_email_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX companyportal_company_email_uniq ON public."CompanyPortalUsers" USING btree (company_id, lower(portal_user_email)) WHERE (deleted = false);


--
-- Name: companyportalusers_company_email_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX companyportalusers_company_email_uniq ON public."CompanyPortalUsers" USING btree (company_id, portal_user_email);


--
-- Name: companyportalusers_org_email_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX companyportalusers_org_email_unique ON public."CompanyPortalUsers" USING btree (organization_id, lower(portal_user_email)) WHERE (deleted = false);


--
-- Name: idx_bomcomponents_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bomcomponents_role ON public."BOMComponents" USING btree (organization_id, component_role) WHERE ((deleted = false) AND (archived = false));


--
-- Name: idx_bomcomponents_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bomcomponents_template ON public."BOMComponents" USING btree (organization_id, bom_template_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: idx_bominstancelines_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bominstancelines_instance ON public."BOMInstanceLines" USING btree (bom_instance_id);


--
-- Name: idx_bominstancelines_instance_resolved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bominstancelines_instance_resolved ON public."BOMInstanceLines" USING btree (bom_instance_id, resolved_part_id) WHERE ((deleted = false) AND (resolved_part_id IS NOT NULL));


--
-- Name: idx_bominstancelines_resolved_part; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bominstancelines_resolved_part ON public."BOMInstanceLines" USING btree (resolved_part_id) WHERE ((deleted = false) AND (resolved_part_id IS NOT NULL));


--
-- Name: idx_catalogitemcomponents_child_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemcomponents_child_role ON public."CatalogItemComponents" USING btree (organization_id, child_role) WHERE (deleted = false);


--
-- Name: idx_catalogitemcomponents_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemcomponents_parent ON public."CatalogItemComponents" USING btree (organization_id, parent_item_id) WHERE (deleted = false);


--
-- Name: idx_catalogitemconversions_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemconversions_org ON public."CatalogItemConversions" USING btree (organization_id);


--
-- Name: idx_catalogitems_org_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitems_org_role ON public."CatalogItems" USING btree (organization_id, item_role) WHERE (is_active = true);


--
-- Name: idx_catalogitems_org_role_color; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitems_org_role_color ON public."CatalogItems" USING btree (organization_id, item_role, color) WHERE ((is_active = true) AND (is_roll = false));


--
-- Name: idx_catalogitems_roll_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitems_roll_lookup ON public."CatalogItems" USING btree (organization_id, collection_name, variant_name) WHERE ((is_active = true) AND (is_roll = true));


--
-- Name: idx_catalogitemsmsrp_cat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemsmsrp_cat ON public."CatalogItemsMSRP" USING btree (category_id);


--
-- Name: idx_catalogitemsmsrp_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemsmsrp_org ON public."CatalogItemsMSRP" USING btree (organization_id);


--
-- Name: idx_catalogitemsmsrp_org_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogitemsmsrp_org_item ON public."CatalogItemsMSRP" USING btree (organization_id, catalog_item_id);


--
-- Name: idx_companies_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companies_deleted ON public."Companies" USING btree (deleted) WHERE (deleted = false);


--
-- Name: idx_companies_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companies_org ON public."Companies" USING btree (organization_id);


--
-- Name: idx_companies_org_company_no; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companies_org_company_no ON public."Companies" USING btree (organization_id, company_no);


--
-- Name: idx_companyportalusers_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companyportalusers_company ON public."CompanyPortalUsers" USING btree (company_id);


--
-- Name: idx_companyportalusers_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companyportalusers_role ON public."CompanyPortalUsers" USING btree (role) WHERE (deleted = false);


--
-- Name: idx_configuredproducts_config_snapshot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_configuredproducts_config_snapshot ON public."ConfiguredProducts" USING gin (config_snapshot);


--
-- Name: idx_configuredproducts_organization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_configuredproducts_organization ON public."ConfiguredProducts" USING btree (organization_id) WHERE (deleted = false);


--
-- Name: idx_configuredproducts_product_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_configuredproducts_product_type ON public."ConfiguredProducts" USING btree (product_type_id) WHERE (deleted = false);


--
-- Name: idx_configuredproducts_quote; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_configuredproducts_quote ON public."ConfiguredProducts" USING btree (quote_id) WHERE (deleted = false);


--
-- Name: idx_configuredproducts_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_configuredproducts_template ON public."ConfiguredProducts" USING btree (bom_template_id) WHERE (deleted = false);


--
-- Name: idx_dircontacts_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircontacts_company ON public."DirectoryContacts" USING btree (company_id);


--
-- Name: idx_dircontacts_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircontacts_org ON public."DirectoryContacts" USING btree (organization_id) WHERE (organization_id IS NOT NULL);


--
-- Name: idx_dircustomers_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircustomers_company ON public."DirectoryCustomers" USING btree (company_id);


--
-- Name: idx_dircustomers_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircustomers_country ON public."DirectoryCustomers" USING btree (country) WHERE (country IS NOT NULL);


--
-- Name: idx_dircustomers_customer_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircustomers_customer_type ON public."DirectoryCustomers" USING btree (customer_type_name) WHERE (customer_type_name IS NOT NULL);


--
-- Name: idx_dircustomers_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircustomers_org ON public."DirectoryCustomers" USING btree (organization_id) WHERE (organization_id IS NOT NULL);


--
-- Name: idx_dircustomers_primary_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dircustomers_primary_contact ON public."DirectoryCustomers" USING btree (primary_contact_id) WHERE (primary_contact_id IS NOT NULL);


--
-- Name: idx_directorycontacts_contact_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycontacts_contact_type ON public."DirectoryContacts" USING btree (contact_type);


--
-- Name: idx_directorycontacts_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycontacts_customer ON public."DirectoryContacts" USING btree (customer_id);


--
-- Name: idx_directorycontacts_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycontacts_org ON public."DirectoryContacts" USING btree (organization_id);


--
-- Name: idx_directorycustomers_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycustomers_company_id ON public."DirectoryCustomers" USING btree (company_id);


--
-- Name: idx_directorycustomers_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycustomers_org ON public."DirectoryCustomers" USING btree (organization_id);


--
-- Name: idx_directorycustomers_org_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_directorycustomers_org_company ON public."DirectoryCustomers" USING btree (organization_id, company_id);


--
-- Name: idx_mo_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mo_company ON public."ManufacturingOrders" USING btree (company_id);


--
-- Name: idx_mo_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mo_org ON public."ManufacturingOrders" USING btree (organization_id);


--
-- Name: idx_mo_so; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mo_so ON public."ManufacturingOrders" USING btree (sales_order_id);


--
-- Name: idx_order_list_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_list_organization_id ON public."OrderList" USING btree (organization_id) WHERE (deleted = false);


--
-- Name: idx_order_list_sales_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_list_sales_order_id ON public."OrderList" USING btree (sales_order_id) WHERE (deleted = false);


--
-- Name: idx_order_list_tracking_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_list_tracking_status ON public."OrderList" USING btree (tracking_status) WHERE (deleted = false);


--
-- Name: idx_orderlist_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orderlist_company ON public."OrderList" USING btree (company_id);


--
-- Name: idx_org_user_permissions_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_user_permissions_code ON public."OrganizationUserPermissions" USING btree (permission_code);


--
-- Name: idx_org_user_permissions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_user_permissions_user_id ON public."OrganizationUserPermissions" USING btree (organization_user_id);


--
-- Name: idx_organization_users_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organization_users_organization_id ON public."OrganizationUsers" USING btree (organization_id) WHERE (deleted = false);


--
-- Name: idx_organization_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organization_users_status ON public."OrganizationUsers" USING btree (status) WHERE (deleted = false);


--
-- Name: idx_organization_users_user_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organization_users_user_email ON public."OrganizationUsers" USING btree (lower(user_email)) WHERE (deleted = false);


--
-- Name: idx_organization_users_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organization_users_user_id ON public."OrganizationUsers" USING btree (user_id) WHERE ((user_id IS NOT NULL) AND (deleted = false));


--
-- Name: idx_organizations_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_organizations_created_at ON public."Organizations" USING btree (created_at);


--
-- Name: idx_permissions_module; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_permissions_module ON public."Permissions" USING btree (module);


--
-- Name: idx_portalusers_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_portalusers_org ON public."CompanyPortalUsers" USING btree (organization_id);


--
-- Name: idx_portalusers_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_portalusers_user ON public."CompanyPortalUsers" USING btree (user_id);


--
-- Name: idx_qlc_org_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qlc_org_id ON public."QuoteLineComponents" USING btree (organization_id);


--
-- Name: idx_qlc_quote_line_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qlc_quote_line_id ON public."QuoteLineComponents" USING btree (quote_line_id);


--
-- Name: idx_qlc_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qlc_role ON public."QuoteLineComponents" USING btree (component_role);


--
-- Name: idx_quote_lines_bom_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quote_lines_bom_template_id ON public."QuoteLines" USING btree (bom_template_id) WHERE (bom_template_id IS NOT NULL);


--
-- Name: idx_quote_lines_collection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quote_lines_collection_id ON public."QuoteLines" USING btree (collection_id) WHERE (collection_id IS NOT NULL);


--
-- Name: idx_quote_lines_product_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quote_lines_product_type ON public."QuoteLines" USING btree (product_type) WHERE (product_type IS NOT NULL);


--
-- Name: idx_quote_lines_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quote_lines_variant_id ON public."QuoteLines" USING btree (variant_id) WHERE (variant_id IS NOT NULL);


--
-- Name: idx_quotelines_catalog_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_catalog_item_id ON public."QuoteLines" USING btree (catalog_item_id);


--
-- Name: idx_quotelines_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_category_id ON public."QuoteLines" USING btree (category_id);


--
-- Name: idx_quotelines_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_company_id ON public."QuoteLines" USING btree (company_id);


--
-- Name: idx_quotelines_configured_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_configured_product_id ON public."QuoteLines" USING btree (configured_product_id);


--
-- Name: idx_quotelines_org_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_org_id ON public."QuoteLines" USING btree (organization_id);


--
-- Name: idx_quotelines_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotelines_quote_id ON public."QuoteLines" USING btree (quote_id);


--
-- Name: idx_quotes_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_company ON public."Quotes" USING btree (company_id);


--
-- Name: idx_quotes_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_created_by ON public."Quotes" USING btree (created_by_user_id) WHERE (deleted = false);


--
-- Name: idx_quotes_created_by_portal_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_created_by_portal_user ON public."Quotes" USING btree (created_by_portal_user_id) WHERE ((created_by_portal_user_id IS NOT NULL) AND (deleted = false));


--
-- Name: idx_quotes_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_customer_id ON public."Quotes" USING btree (customer_id) WHERE ((customer_id IS NOT NULL) AND (deleted = false));


--
-- Name: idx_quotes_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_organization_id ON public."Quotes" USING btree (organization_id) WHERE (deleted = false);


--
-- Name: idx_quotes_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_status ON public."Quotes" USING btree (status) WHERE (deleted = false);


--
-- Name: idx_quotes_tracking_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_tracking_status ON public."Quotes" USING btree (tracking_status) WHERE ((deleted = false) AND (tracking_status IS NOT NULL));


--
-- Name: idx_saleorderlines_so; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_saleorderlines_so ON public."SaleOrderLines" USING btree (sales_order_id);


--
-- Name: idx_sales_orders_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_orders_organization_id ON public."SalesOrders" USING btree (organization_id) WHERE (deleted = false);


--
-- Name: idx_sales_orders_quote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_orders_quote_id ON public."SalesOrders" USING btree (quote_id) WHERE (deleted = false);


--
-- Name: idx_sales_orders_tracking_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_orders_tracking_status ON public."SalesOrders" USING btree (tracking_status) WHERE (deleted = false);


--
-- Name: idx_salesorders_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_salesorders_company ON public."SalesOrders" USING btree (company_id);


--
-- Name: importtaxrules_org_category_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX importtaxrules_org_category_uniq ON public."ImportTaxRules" USING btree (organization_id, category_id);


--
-- Name: ix_bomcomponents_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_item ON public."BOMComponents" USING btree (organization_id, component_item_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_org_role_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_org_role_active ON public."BOMComponents" USING btree (organization_id, component_role) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_org_slot_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_org_slot_active ON public."BOMComponents" USING btree (organization_id, slot_id) WHERE ((deleted = false) AND (archived = false) AND (slot_id IS NOT NULL));


--
-- Name: ix_bomcomponents_org_template_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_org_template_active ON public."BOMComponents" USING btree (organization_id, bom_template_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_parent ON public."BOMComponents" USING btree (organization_id, parent_component_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_role ON public."BOMComponents" USING btree (organization_id, component_role) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_template ON public."BOMComponents" USING btree (organization_id, bom_template_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_template_tree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_template_tree ON public."BOMComponents" USING btree (organization_id, bom_template_id, parent_component_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_bomcomponents_tree; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_bomcomponents_tree ON public."BOMComponents" USING btree (organization_id, bom_template_id, parent_component_id) WHERE ((deleted = false) AND (archived = false));


--
-- Name: ix_catalogitemcomponents_parent_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_catalogitemcomponents_parent_role ON public."CatalogItemComponents" USING btree (organization_id, parent_item_id, child_role);


--
-- Name: manufacturers_org_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX manufacturers_org_idx ON public."Manufacturers" USING btree (organization_id);


--
-- Name: manufacturers_org_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX manufacturers_org_name_unique ON public."Manufacturers" USING btree (organization_id, lower(name));


--
-- Name: orderlist_unique_so; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX orderlist_unique_so ON public."OrderList" USING btree (sales_order_id) WHERE (deleted = false);


--
-- Name: org_users_unique_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX org_users_unique_email ON public."OrganizationUsers" USING btree (organization_id, lower(user_email)) WHERE (deleted = false);


--
-- Name: organizationusers_org_email_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizationusers_org_email_uniq ON public."OrganizationUsers" USING btree (organization_id, user_email);


--
-- Name: organizationusers_org_email_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizationusers_org_email_unique ON public."OrganizationUsers" USING btree (organization_id, lower(user_email)) WHERE (deleted = false);


--
-- Name: INDEX organizationusers_org_email_unique; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.organizationusers_org_email_unique IS 'Ensures unique email addresses per organization for active (non-deleted) records. Case-insensitive comparison.';


--
-- Name: organizationusers_org_user_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX organizationusers_org_user_unique ON public."OrganizationUsers" USING btree (organization_id, user_id) WHERE (deleted = false);


--
-- Name: orgusers_org_email_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX orgusers_org_email_uniq ON public."OrganizationUsers" USING btree (organization_id, lower(user_email)) WHERE (deleted = false);


--
-- Name: product_type_role_rules_org_pt_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_type_role_rules_org_pt_idx ON public."ProductTypeRoleRules" USING btree (organization_id, product_type_id);


--
-- Name: product_type_role_rules_org_role_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_type_role_rules_org_role_idx ON public."ProductTypeRoleRules" USING btree (organization_id, role_code);


--
-- Name: quotes_org_quote_no_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quotes_org_quote_no_unique ON public."Quotes" USING btree (organization_id, quote_no) WHERE (deleted = false);


--
-- Name: quotes_unique_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX quotes_unique_no ON public."Quotes" USING btree (organization_id, quote_no) WHERE (deleted = false);


--
-- Name: sales_orders_org_so_no_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX sales_orders_org_so_no_unique ON public."SalesOrders" USING btree (organization_id, sales_order_no) WHERE (deleted = false);


--
-- Name: so_unique_quote; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX so_unique_quote ON public."SalesOrders" USING btree (quote_id) WHERE (deleted = false);


--
-- Name: uq_bomcomponents_template_slot_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_bomcomponents_template_slot_active ON public."BOMComponents" USING btree (organization_id, bom_template_id, slot_id) WHERE ((deleted = false) AND (archived = false) AND (slot_id IS NOT NULL));


--
-- Name: uq_catalogitemcomponents_parent_child_role; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_catalogitemcomponents_parent_child_role ON public."CatalogItemComponents" USING btree (organization_id, parent_item_id, child_item_id, child_role);


--
-- Name: uq_companies_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_companies_org_name ON public."Companies" USING btree (organization_id, lower(company_name)) WHERE (deleted = false);


--
-- Name: uq_orguserpermissions_orguser_perm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_orguserpermissions_orguser_perm ON public."OrganizationUserPermissions" USING btree (organization_user_id, permission_code);


--
-- Name: ux_bomcomponents_no_duplicate_child_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_bomcomponents_no_duplicate_child_sku ON public."BOMComponents" USING btree (organization_id, bom_template_id, parent_component_id, component_item_id) WHERE ((parent_component_id IS NOT NULL) AND (deleted = false) AND (archived = false));


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_02_17_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_02_17_inserted_at_topic_idx ON realtime.messages_2026_02_17 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_02_18_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_02_18_inserted_at_topic_idx ON realtime.messages_2026_02_18 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_02_19_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_02_19_inserted_at_topic_idx ON realtime.messages_2026_02_19 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_02_20_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_02_20_inserted_at_topic_idx ON realtime.messages_2026_02_20 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: messages_2026_02_21_inserted_at_topic_idx; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_2026_02_21_inserted_at_topic_idx ON realtime.messages_2026_02_21 USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_key ON realtime.subscription USING btree (subscription_id, entity, filters);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_iceberg_namespaces_bucket_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_namespaces_bucket_id ON storage.iceberg_namespaces USING btree (catalog_id, name);


--
-- Name: idx_iceberg_tables_location; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_location ON storage.iceberg_tables USING btree (location);


--
-- Name: idx_iceberg_tables_namespace_id; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_iceberg_tables_namespace_id ON storage.iceberg_tables USING btree (catalog_id, namespace_id, name);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_name_bucket_level_unique; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_name_bucket_level_unique ON storage.objects USING btree (name COLLATE "C", bucket_id, level);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_lower_name ON storage.objects USING btree ((path_tokens[level]), lower(name) text_pattern_ops, bucket_id, level);


--
-- Name: idx_prefixes_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_prefixes_lower_name ON storage.prefixes USING btree (bucket_id, level, ((string_to_array(name, '/'::text))[level]), lower(name) text_pattern_ops);


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: objects_bucket_id_level_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_bucket_id_level_idx ON storage.objects USING btree (bucket_id, level, name COLLATE "C");


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: supabase_functions_hooks_h_table_id_h_name_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_h_table_id_h_name_idx ON supabase_functions.hooks USING btree (hook_table_id, hook_name);


--
-- Name: supabase_functions_hooks_request_id_idx; Type: INDEX; Schema: supabase_functions; Owner: -
--

CREATE INDEX supabase_functions_hooks_request_id_idx ON supabase_functions.hooks USING btree (request_id);


--
-- Name: messages_2026_02_17_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_02_17_inserted_at_topic_idx;


--
-- Name: messages_2026_02_17_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_02_17_pkey;


--
-- Name: messages_2026_02_18_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_02_18_inserted_at_topic_idx;


--
-- Name: messages_2026_02_18_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_02_18_pkey;


--
-- Name: messages_2026_02_19_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_02_19_inserted_at_topic_idx;


--
-- Name: messages_2026_02_19_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_02_19_pkey;


--
-- Name: messages_2026_02_20_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_02_20_inserted_at_topic_idx;


--
-- Name: messages_2026_02_20_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_02_20_pkey;


--
-- Name: messages_2026_02_21_inserted_at_topic_idx; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_inserted_at_topic_index ATTACH PARTITION realtime.messages_2026_02_21_inserted_at_topic_idx;


--
-- Name: messages_2026_02_21_pkey; Type: INDEX ATTACH; Schema: realtime; Owner: -
--

ALTER INDEX realtime.messages_pkey ATTACH PARTITION realtime.messages_2026_02_21_pkey;


--
-- Name: CatalogItems catalog_items_recompute_msrp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catalog_items_recompute_msrp AFTER UPDATE OF cost_exw ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.trg_catalog_items_recompute_msrp();


--
-- Name: CatalogItems catalogitems_validate_roll_pricing_mode; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catalogitems_validate_roll_pricing_mode BEFORE INSERT OR UPDATE OF is_roll, roll_pricing_mode, roll_width, measure_basis ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.trg_catalogitems_validate_roll_pricing_mode();


--
-- Name: CatalogItems catalogitems_write_conversions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catalogitems_write_conversions AFTER INSERT OR UPDATE OF cost_exw, unit_of_measure, roll_width, roll_width_value, roll_width_uom, roll_width_m, is_roll, units_per_purchase_unit ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.trg_catalogitems_write_conversions();


--
-- Name: CatalogItemRoles trg_catalog_item_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalog_item_roles_updated_at BEFORE UPDATE ON public."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItemRollSpecs trg_catalog_item_roll_specs_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalog_item_roll_specs_updated_at BEFORE UPDATE ON public."CatalogItemRollSpecs" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItemSupply trg_catalog_item_supply_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalog_item_supply_updated_at BEFORE UPDATE ON public."CatalogItemSupply" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItemComponents trg_catalogitemcomponents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitemcomponents_updated_at BEFORE UPDATE ON public."CatalogItemComponents" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItemRoles trg_catalogitemroles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitemroles_updated_at BEFORE UPDATE ON public."CatalogItemRoles" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItems trg_catalogitems_sync_collection_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitems_sync_collection_name BEFORE INSERT OR UPDATE OF roll_collection_id ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.sync_catalogitem_collection_name_from_roll_collection();


--
-- Name: CatalogItems trg_catalogitems_sync_manufacturer; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitems_sync_manufacturer BEFORE INSERT OR UPDATE OF manufacturer, organization_id ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.sync_catalogitems_manufacturer();


--
-- Name: CatalogItems trg_catalogitems_sync_roll_dimensions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitems_sync_roll_dimensions BEFORE INSERT OR UPDATE ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.catalogitems_sync_roll_dimensions();


--
-- Name: CatalogItemsMSRP trg_catalogitemsmsrp_guard_not_null; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitemsmsrp_guard_not_null BEFORE INSERT OR UPDATE ON public."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION public.catalogitemsmsrp_guard_not_null();


--
-- Name: CatalogItemsMSRP trg_catalogitemsmsrp_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_catalogitemsmsrp_updated_at BEFORE UPDATE ON public."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CategoryMargins trg_categorymargins_recompute_itemsmsrp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_categorymargins_recompute_itemsmsrp AFTER INSERT OR UPDATE OF msrp_pct_sale_in, msrp_pct_sale_out, is_active ON public."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION public._trg_categorymargins_recompute_itemsmsrp();


--
-- Name: CategoryMargins trg_categorymargins_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_categorymargins_updated_at BEFORE UPDATE ON public."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: Companies trg_companies_set_company_no; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_companies_set_company_no BEFORE INSERT ON public."Companies" FOR EACH ROW EXECUTE FUNCTION public.set_company_no();


--
-- Name: TRIGGER trg_companies_set_company_no ON "Companies"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER trg_companies_set_company_no ON public."Companies" IS 'Auto-assigns company_no on insert using next_company_no() function. Only sets if company_no is null/empty.';


--
-- Name: Companies trg_companies_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_companies_updated_at BEFORE UPDATE ON public."Companies" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CompanyPortalUsers trg_companyportalusers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_companyportalusers_updated_at BEFORE UPDATE ON public."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ConfiguredProducts trg_configuredproducts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_configuredproducts_updated_at BEFORE UPDATE ON public."ConfiguredProducts" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CostSettings trg_costsettings_recompute_itemsmsrp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_costsettings_recompute_itemsmsrp AFTER UPDATE OF shipping_pct, global_import_tax_pct, minimum_margin_pct, default_msrp_pct_sale_out ON public."CostSettings" FOR EACH ROW EXECUTE FUNCTION public._trg_costsettings_recompute_itemsmsrp();


--
-- Name: CostSettings trg_costsettings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_costsettings_updated_at BEFORE UPDATE ON public."CostSettings" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CompanyPortalUsers trg_customerportalusers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customerportalusers_updated_at BEFORE UPDATE ON public."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: DirectoryContacts trg_dircontacts_set_company; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_dircontacts_set_company BEFORE INSERT ON public."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION public.tg_set_company_id_from_portal_user();


--
-- Name: DirectoryCustomers trg_dircustomers_set_company; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_dircustomers_set_company BEFORE INSERT ON public."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION public.tg_set_company_id_from_portal_user();


--
-- Name: DirectoryContacts trg_directorycontacts_fill_org_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_directorycontacts_fill_org_id BEFORE INSERT OR UPDATE OF company_id, organization_id ON public."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION public.directorycontacts_fill_org_id();


--
-- Name: DirectoryContacts trg_directorycontacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_directorycontacts_updated_at BEFORE UPDATE ON public."DirectoryContacts" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: DirectoryCustomers trg_directorycustomers_set_company; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_directorycustomers_set_company BEFORE INSERT ON public."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION public.tg_set_company_id_from_portal_user();


--
-- Name: DirectoryCustomers trg_directorycustomers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_directorycustomers_updated_at BEFORE UPDATE ON public."DirectoryCustomers" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItems trg_enforce_active_item_role; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_active_item_role BEFORE INSERT OR UPDATE OF item_role ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.enforce_active_item_role();


--
-- Name: CatalogItemsMSRP trg_fill_msrp_item_identity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fill_msrp_item_identity BEFORE INSERT OR UPDATE OF catalog_item_id, sku, name, collection_name, variant_name ON public."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION public.fill_msrp_item_identity();


--
-- Name: CatalogItemsMSRP trg_fill_msrp_sku_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fill_msrp_sku_name BEFORE INSERT OR UPDATE OF catalog_item_id, sku, name ON public."CatalogItemsMSRP" FOR EACH ROW EXECUTE FUNCTION public.fill_msrp_sku_name();


--
-- Name: ImportTaxRules trg_importtaxrules_recompute_itemsmsrp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_importtaxrules_recompute_itemsmsrp AFTER INSERT OR UPDATE OF import_tax_pct, is_active ON public."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION public._trg_importtaxrules_recompute_itemsmsrp();


--
-- Name: ImportTaxRules trg_importtaxrules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_importtaxrules_updated_at BEFORE UPDATE ON public."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ManufacturingOrders trg_manufacturingorders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_manufacturingorders_updated_at BEFORE UPDATE ON public."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ManufacturingOrders trg_mo_company_match; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mo_company_match BEFORE INSERT OR UPDATE ON public."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION public.enforce_mo_company_matches_salesorder();


--
-- Name: ManufacturingOrders trg_mo_company_match_so; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mo_company_match_so BEFORE INSERT OR UPDATE ON public."ManufacturingOrders" FOR EACH ROW EXECUTE FUNCTION public.enforce_mo_company_matches_salesorder();


--
-- Name: OrderList trg_orderlist_company_match_so; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_orderlist_company_match_so BEFORE INSERT OR UPDATE ON public."OrderList" FOR EACH ROW EXECUTE FUNCTION public.enforce_orderlist_company_matches_salesorder();


--
-- Name: Organizations trg_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON public."Organizations" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CompanyPortalUsers trg_portalusers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_portalusers_updated_at BEFORE UPDATE ON public."CompanyPortalUsers" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ProductTypes trg_producttypes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_producttypes_set_updated_at BEFORE UPDATE ON public."ProductTypes" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: Quotes trg_quote_approved; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_approved AFTER UPDATE OF status ON public."Quotes" FOR EACH ROW EXECUTE FUNCTION public.on_quote_approved_create_sales_order();


--
-- Name: Quotes trg_quote_approved_to_sales_order; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_approved_to_sales_order BEFORE UPDATE ON public."Quotes" FOR EACH ROW WHEN ((old.status IS DISTINCT FROM new.status)) EXECUTE FUNCTION public.handle_quote_approved();


--
-- Name: TRIGGER trg_quote_approved_to_sales_order ON "Quotes"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER trg_quote_approved_to_sales_order ON public."Quotes" IS 'Trigger: Automatically creates SalesOrder and OrderList when Quote is approved. Sets Quote.tracking_status.';


--
-- Name: QuoteLineComponents trg_quote_line_components_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_line_components_updated_at BEFORE UPDATE ON public."QuoteLineComponents" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: QuoteLines trg_quote_lines_generate_bom_instance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_lines_generate_bom_instance AFTER INSERT ON public."QuoteLines" FOR EACH ROW EXECUTE FUNCTION public.trg_quote_lines_generate_bom_instance_fn();


--
-- Name: QuoteLines trg_quote_lines_set_company_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_lines_set_company_id BEFORE INSERT OR UPDATE OF quote_id, organization_id, company_id ON public."QuoteLines" FOR EACH ROW EXECUTE FUNCTION public.quote_lines_set_company_id();


--
-- Name: QuoteLines trg_quote_lines_validate_company; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quote_lines_validate_company BEFORE INSERT OR UPDATE OF quote_id, organization_id, company_id ON public."QuoteLines" FOR EACH ROW EXECUTE FUNCTION public.quote_lines_validate_company();


--
-- Name: Quotes trg_quotes_set_company; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quotes_set_company BEFORE INSERT ON public."Quotes" FOR EACH ROW EXECUTE FUNCTION public.tg_set_company_id_from_portal_user();


--
-- Name: Quotes trg_quotes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quotes_updated_at BEFORE UPDATE ON public."Quotes" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: CatalogItems trg_recompute_msrp_on_catalog_item_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recompute_msrp_on_catalog_item_change AFTER INSERT OR UPDATE OF cost_exw, category_id ON public."CatalogItems" FOR EACH ROW WHEN ((new.organization_id IS NOT NULL)) EXECUTE FUNCTION public.trig_recompute_msrp_on_catalog_item_change();


--
-- Name: CategoryMargins trg_recompute_msrp_on_category_margin_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recompute_msrp_on_category_margin_change AFTER INSERT OR DELETE OR UPDATE ON public."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION public.trig_recompute_msrp_on_category_margin_change();


--
-- Name: CostSettings trg_recompute_msrp_on_cost_settings_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recompute_msrp_on_cost_settings_change AFTER INSERT OR UPDATE OF shipping_pct, global_import_tax_pct ON public."CostSettings" FOR EACH ROW EXECUTE FUNCTION public.trig_recompute_msrp_on_cost_settings_change();


--
-- Name: ImportTaxRules trg_recompute_msrp_on_import_tax_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recompute_msrp_on_import_tax_change AFTER INSERT OR DELETE OR UPDATE ON public."ImportTaxRules" FOR EACH ROW EXECUTE FUNCTION public.trig_recompute_msrp_on_import_tax_change();


--
-- Name: SalesOrders trg_salesorder_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_salesorder_status AFTER UPDATE OF tracking_status ON public."SalesOrders" FOR EACH ROW EXECUTE FUNCTION public.on_sales_order_status_mirror();


--
-- Name: SalesOrders trg_salesorders_company_match_quote; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_salesorders_company_match_quote BEFORE INSERT OR UPDATE ON public."SalesOrders" FOR EACH ROW EXECUTE FUNCTION public.enforce_salesorders_company_matches_quote();


--
-- Name: SalesOrders trg_salesorders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_salesorders_updated_at BEFORE UPDATE ON public."SalesOrders" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: QuoteLines trg_set_quote_line_company_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_quote_line_company_id BEFORE INSERT OR UPDATE OF quote_id, organization_id, company_id ON public."QuoteLines" FOR EACH ROW EXECUTE FUNCTION public.set_quote_line_company_id();


--
-- Name: ProductTypeRoleRules trg_set_updated_at_product_type_role_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at_product_type_role_rules BEFORE UPDATE ON public."ProductTypeRoleRules" FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_product_type_role_rules();


--
-- Name: BOMTemplateSlots trg_sync_bom_template_slot_sku; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_bom_template_slot_sku BEFORE INSERT OR UPDATE OF catalog_item_id, fixed_catalog_item_id ON public."BOMTemplateSlots" FOR EACH ROW EXECUTE FUNCTION public.sync_bom_template_slot_sku();


--
-- Name: CatalogItems trg_sync_catalogitems_to_msrp_safe; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_catalogitems_to_msrp_safe AFTER INSERT OR UPDATE OF sku, name, collection_name, variant_name, unit_of_measure, category_id, cost_exw ON public."CatalogItems" FOR EACH ROW EXECUTE FUNCTION public.sync_catalogitems_to_msrp_safe();


--
-- Name: SalesOrders trg_sync_order_list_tracking; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_order_list_tracking AFTER UPDATE OF tracking_status ON public."SalesOrders" FOR EACH ROW WHEN ((old.tracking_status IS DISTINCT FROM new.tracking_status)) EXECUTE FUNCTION public.sync_order_list_tracking_status();


--
-- Name: TRIGGER trg_sync_order_list_tracking ON "SalesOrders"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER trg_sync_order_list_tracking ON public."SalesOrders" IS 'Trigger: Automatically syncs OrderList.tracking_status when SalesOrder.tracking_status changes.';


--
-- Name: CategoryMargins trig_catmargins_msrp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trig_catmargins_msrp AFTER INSERT OR UPDATE OF msrp_pct_sale_in, msrp_pct_sale_out ON public."CategoryMargins" FOR EACH ROW EXECUTE FUNCTION public.trig_catmargins_msrp();


--
-- Name: OrderList update_order_list_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_order_list_updated_at BEFORE UPDATE ON public."OrderList" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: OrganizationUsers update_organization_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_organization_users_updated_at BEFORE UPDATE ON public."OrganizationUsers" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: Quotes update_quotes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_quotes_updated_at BEFORE UPDATE ON public."Quotes" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: SalesOrders update_sales_orders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_sales_orders_updated_at BEFORE UPDATE ON public."SalesOrders" FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: objects objects_delete_delete_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects objects_insert_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();


--
-- Name: objects objects_update_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();


--
-- Name: prefixes prefixes_create_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();


--
-- Name: prefixes prefixes_delete_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: extensions extensions_tenant_external_id_fkey; Type: FK CONSTRAINT; Schema: _realtime; Owner: -
--

ALTER TABLE ONLY _realtime.extensions
    ADD CONSTRAINT extensions_tenant_external_id_fkey FOREIGN KEY (tenant_external_id) REFERENCES _realtime.tenants(external_id) ON DELETE CASCADE;


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: BOMComponents BOMComponents_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMComponents"
    ADD CONSTRAINT "BOMComponents_slot_id_fkey" FOREIGN KEY (slot_id) REFERENCES public."BOMTemplateSlots"(id) ON DELETE SET NULL;


--
-- Name: BOMTemplateSlots BOMTemplateSlots_bom_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_bom_template_id_fkey" FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE CASCADE;


--
-- Name: BOMTemplateSlots BOMTemplateSlots_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_catalog_item_id_fkey" FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id);


--
-- Name: BOMTemplateSlots BOMTemplateSlots_fixed_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplateSlots"
    ADD CONSTRAINT "BOMTemplateSlots_fixed_catalog_item_id_fkey" FOREIGN KEY (fixed_catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE SET NULL;


--
-- Name: CatalogItemConversions CatalogItemConversions_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemConversions"
    ADD CONSTRAINT "CatalogItemConversions_catalog_item_id_fkey" FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemRollSpecs CatalogItemRollSpecs_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemRollSpecs"
    ADD CONSTRAINT "CatalogItemRollSpecs_catalog_item_id_fkey" FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemSupply CatalogItemSupply_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemSupply"
    ADD CONSTRAINT "CatalogItemSupply_catalog_item_id_fkey" FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemsMSRP CatalogItemsMSRP_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT "CatalogItemsMSRP_catalog_item_id_fkey" FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItems CatalogItems_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItems"
    ADD CONSTRAINT "CatalogItems_category_id_fkey" FOREIGN KEY (category_id) REFERENCES public."CatalogCategories"(id) ON DELETE SET NULL;


--
-- Name: CatalogRoleCategoryMap CatalogRoleCategoryMap_role_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_role_code_fkey" FOREIGN KEY (role_code) REFERENCES public."CatalogItemRoles"(role_code) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CatalogRoleCategoryMap CatalogRoleCategoryMap_target_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogRoleCategoryMap"
    ADD CONSTRAINT "CatalogRoleCategoryMap_target_category_id_fkey" FOREIGN KEY (target_category_id) REFERENCES public."CatalogCategories"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Companies Companies_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Companies"
    ADD CONSTRAINT "Companies_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: CompanyPortalUsers CompanyPortalUsers_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CompanyPortalUsers"
    ADD CONSTRAINT "CompanyPortalUsers_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public."Companies"(id);


--
-- Name: CompanyPortalUsers CustomerPortalUsers_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_invited_by_user_id_fkey" FOREIGN KEY (invited_by_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: CompanyPortalUsers CustomerPortalUsers_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: CompanyPortalUsers CustomerPortalUsers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CompanyPortalUsers"
    ADD CONSTRAINT "CustomerPortalUsers_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: DirectoryContacts DirectoryContacts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE RESTRICT;


--
-- Name: DirectoryContacts DirectoryContacts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES public."DirectoryCustomers"(id) ON DELETE SET NULL;


--
-- Name: DirectoryContacts DirectoryContacts_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryContacts"
    ADD CONSTRAINT "DirectoryContacts_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: DirectoryCustomers DirectoryCustomers_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE RESTRICT;


--
-- Name: DirectoryCustomers DirectoryCustomers_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: DirectoryCustomers DirectoryCustomers_primary_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryCustomers"
    ADD CONSTRAINT "DirectoryCustomers_primary_contact_id_fkey" FOREIGN KEY (primary_contact_id) REFERENCES public."DirectoryContacts"(id) ON DELETE SET NULL;


--
-- Name: ManufacturingOrders ManufacturingOrders_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: ManufacturingOrders ManufacturingOrders_sales_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ManufacturingOrders"
    ADD CONSTRAINT "ManufacturingOrders_sales_order_id_fkey" FOREIGN KEY (sales_order_id) REFERENCES public."SalesOrders"(id) ON DELETE RESTRICT;


--
-- Name: OrderList OrderList_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrderList"
    ADD CONSTRAINT "OrderList_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: OrderList OrderList_sales_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrderList"
    ADD CONSTRAINT "OrderList_sales_order_id_fkey" FOREIGN KEY (sales_order_id) REFERENCES public."SalesOrders"(id) ON DELETE CASCADE;


--
-- Name: OrganizationUserPermissions OrganizationUserPermissions_organization_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_organization_user_id_fkey" FOREIGN KEY (organization_user_id) REFERENCES public."OrganizationUsers"(id) ON DELETE CASCADE;


--
-- Name: OrganizationUserPermissions OrganizationUserPermissions_permission_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUserPermissions"
    ADD CONSTRAINT "OrganizationUserPermissions_permission_code_fkey" FOREIGN KEY (permission_code) REFERENCES public."Permissions"(code) ON DELETE CASCADE;


--
-- Name: OrganizationUsers OrganizationUsers_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_invited_by_user_id_fkey" FOREIGN KEY (invited_by_user_id) REFERENCES auth.users(id);


--
-- Name: OrganizationUsers OrganizationUsers_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: OrganizationUsers OrganizationUsers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrganizationUsers"
    ADD CONSTRAINT "OrganizationUsers_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: ProductTypeRoleRules ProductTypeRoleRules_product_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypeRoleRules"
    ADD CONSTRAINT "ProductTypeRoleRules_product_type_id_fkey" FOREIGN KEY (product_type_id) REFERENCES public."ProductTypes"(id) ON DELETE CASCADE;


--
-- Name: ProductTypes ProductTypes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ProductTypes"
    ADD CONSTRAINT "ProductTypes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: Quotes Quotes_created_by_portal_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Quotes"
    ADD CONSTRAINT "Quotes_created_by_portal_user_id_fkey" FOREIGN KEY (created_by_portal_user_id) REFERENCES public."CompanyPortalUsers"(id) ON DELETE SET NULL;


--
-- Name: Quotes Quotes_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Quotes"
    ADD CONSTRAINT "Quotes_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id);


--
-- Name: Quotes Quotes_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Quotes"
    ADD CONSTRAINT "Quotes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: SalesOrders SalesOrders_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SalesOrders"
    ADD CONSTRAINT "SalesOrders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: SalesOrders SalesOrders_quote_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SalesOrders"
    ADD CONSTRAINT "SalesOrders_quote_id_fkey" FOREIGN KEY (quote_id) REFERENCES public."Quotes"(id) ON DELETE RESTRICT;


--
-- Name: BOMInstanceLines bil_component_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstanceLines"
    ADD CONSTRAINT bil_component_fk FOREIGN KEY (bom_component_id) REFERENCES public."BOMComponents"(id) ON DELETE SET NULL;


--
-- Name: BOMInstanceLines bil_part_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstanceLines"
    ADD CONSTRAINT bil_part_fk FOREIGN KEY (resolved_part_id) REFERENCES public."CatalogItems"(id) ON DELETE RESTRICT;


--
-- Name: BOMComponents bomcomponents_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMComponents"
    ADD CONSTRAINT bomcomponents_item_fk FOREIGN KEY (component_item_id) REFERENCES public."CatalogItems"(id) ON DELETE RESTRICT;


--
-- Name: BOMComponents bomcomponents_slot_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMComponents"
    ADD CONSTRAINT bomcomponents_slot_fk FOREIGN KEY (slot_id) REFERENCES public."BOMTemplateSlots"(id) ON DELETE SET NULL;


--
-- Name: BOMComponents bomcomponents_template_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMComponents"
    ADD CONSTRAINT bomcomponents_template_fk FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE CASCADE;


--
-- Name: BOMInstanceLines bominstancelines_instance_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstanceLines"
    ADD CONSTRAINT bominstancelines_instance_fk FOREIGN KEY (bom_instance_id) REFERENCES public."BOMInstances"(id) ON DELETE CASCADE;


--
-- Name: BOMInstanceLines bominstancelines_organization_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstanceLines"
    ADD CONSTRAINT bominstancelines_organization_fk FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: BOMInstances bominstances_quote_line_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstances"
    ADD CONSTRAINT bominstances_quote_line_fk FOREIGN KEY (quote_line_id) REFERENCES public."QuoteLines"(id) ON DELETE CASCADE;


--
-- Name: BOMInstances bominstances_template_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMInstances"
    ADD CONSTRAINT bominstances_template_fk FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE RESTRICT;


--
-- Name: BOMTemplates bomtemplates_product_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."BOMTemplates"
    ADD CONSTRAINT bomtemplates_product_type_fk FOREIGN KEY (product_type_id) REFERENCES public."ProductTypes"(id) ON DELETE RESTRICT;


--
-- Name: CatalogCategories catalogcategories_parent_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogCategories"
    ADD CONSTRAINT catalogcategories_parent_fk FOREIGN KEY (parent_id) REFERENCES public."CatalogCategories"(id) ON DELETE SET NULL;


--
-- Name: CatalogItemComponents catalogitemcomponents_child_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemComponents"
    ADD CONSTRAINT catalogitemcomponents_child_fk FOREIGN KEY (child_item_id) REFERENCES public."CatalogItems"(id) ON DELETE RESTRICT;


--
-- Name: CatalogItemComponents catalogitemcomponents_parent_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemComponents"
    ADD CONSTRAINT catalogitemcomponents_parent_fk FOREIGN KEY (parent_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemProductTypes catalogitemproducttypes_catalog_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemProductTypes"
    ADD CONSTRAINT catalogitemproducttypes_catalog_item_fk FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemProductTypes catalogitemproducttypes_product_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemProductTypes"
    ADD CONSTRAINT catalogitemproducttypes_product_type_fk FOREIGN KEY (product_type_id) REFERENCES public."ProductTypes"(id) ON DELETE CASCADE;


--
-- Name: CatalogItems catalogitems_item_role_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItems"
    ADD CONSTRAINT catalogitems_item_role_fk FOREIGN KEY (item_role) REFERENCES public."CatalogItemRoles"(role_code) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: CatalogItems catalogitems_manufacturer_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItems"
    ADD CONSTRAINT catalogitems_manufacturer_fk FOREIGN KEY (manufacturer_id) REFERENCES public."Manufacturers"(id) ON DELETE SET NULL;


--
-- Name: CatalogItemsMSRP catalogitemsmsrp_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT catalogitemsmsrp_catalog_item_id_fkey FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE CASCADE;


--
-- Name: CatalogItemsMSRP catalogitemsmsrp_org_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT catalogitemsmsrp_org_fk FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id);


--
-- Name: CatalogItemsMSRP catalogitemsmsrp_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."CatalogItemsMSRP"
    ADD CONSTRAINT catalogitemsmsrp_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE CASCADE;


--
-- Name: Companies companies_primary_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Companies"
    ADD CONSTRAINT companies_primary_contact_id_fkey FOREIGN KEY (primary_contact_id) REFERENCES public."DirectoryContacts"(id) ON DELETE SET NULL;


--
-- Name: ConfiguredProducts configuredproducts_bom_template_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_bom_template_fkey FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE RESTRICT;


--
-- Name: ConfiguredProducts configuredproducts_organization_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_organization_fkey FOREIGN KEY (organization_id) REFERENCES public."Organizations"(id) ON DELETE RESTRICT;


--
-- Name: ConfiguredProducts configuredproducts_product_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_product_type_fkey FOREIGN KEY (product_type_id) REFERENCES public."ProductTypes"(id) ON DELETE RESTRICT;


--
-- Name: ConfiguredProducts configuredproducts_quote_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_quote_fkey FOREIGN KEY (quote_id) REFERENCES public."Quotes"(id) ON DELETE SET NULL;


--
-- Name: ConfiguredProducts configuredproducts_roll_item_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ConfiguredProducts"
    ADD CONSTRAINT configuredproducts_roll_item_fkey FOREIGN KEY (roll_catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE SET NULL;


--
-- Name: DirectoryCustomers directorycustomers_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."DirectoryCustomers"
    ADD CONSTRAINT directorycustomers_company_id_fkey FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE SET NULL;


--
-- Name: ManufacturingOrders fk_manufacturingorders_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."ManufacturingOrders"
    ADD CONSTRAINT fk_manufacturingorders_company FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE SET NULL;


--
-- Name: OrderList fk_orderlist_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."OrderList"
    ADD CONSTRAINT fk_orderlist_company FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE SET NULL;


--
-- Name: QuoteLines fk_quote_lines_bom_template; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLines"
    ADD CONSTRAINT fk_quote_lines_bom_template FOREIGN KEY (bom_template_id) REFERENCES public."BOMTemplates"(id) ON DELETE SET NULL;


--
-- Name: Quotes fk_quotes_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Quotes"
    ADD CONSTRAINT fk_quotes_company FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE SET NULL;


--
-- Name: SalesOrders fk_salesorders_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SalesOrders"
    ADD CONSTRAINT fk_salesorders_company FOREIGN KEY (company_id) REFERENCES public."Companies"(id) ON DELETE SET NULL;


--
-- Name: QuoteLineComponents qlc_item_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLineComponents"
    ADD CONSTRAINT qlc_item_fk FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE RESTRICT;


--
-- Name: QuoteLineComponents qlc_quote_line_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLineComponents"
    ADD CONSTRAINT qlc_quote_line_fk FOREIGN KEY (quote_line_id) REFERENCES public."QuoteLines"(id) ON DELETE CASCADE;


--
-- Name: QuoteLines quotelines_configured_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLines"
    ADD CONSTRAINT quotelines_configured_product_id_fkey FOREIGN KEY (configured_product_id) REFERENCES public."ConfiguredProducts"(id) ON DELETE SET NULL;


--
-- Name: QuoteLines quotelines_quote_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."QuoteLines"
    ADD CONSTRAINT quotelines_quote_fk FOREIGN KEY (quote_id) REFERENCES public."Quotes"(id) ON DELETE CASCADE;


--
-- Name: SaleOrderLines saleorderlines_so_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."SaleOrderLines"
    ADD CONSTRAINT saleorderlines_so_fk FOREIGN KEY (sales_order_id) REFERENCES public."SalesOrders"(id) ON DELETE CASCADE;


--
-- Name: iceberg_namespaces iceberg_namespaces_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_namespaces
    ADD CONSTRAINT iceberg_namespaces_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_catalog_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES storage.buckets_analytics(id) ON DELETE CASCADE;


--
-- Name: iceberg_tables iceberg_tables_namespace_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.iceberg_tables
    ADD CONSTRAINT iceberg_tables_namespace_id_fkey FOREIGN KEY (namespace_id) REFERENCES storage.iceberg_namespaces(id) ON DELETE CASCADE;


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: prefixes prefixes_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT "prefixes_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: Permissions Authenticated users can read permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read permissions" ON public."Permissions" FOR SELECT TO authenticated USING (true);


--
-- Name: CatalogItemComponents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."CatalogItemComponents" ENABLE ROW LEVEL SECURITY;

--
-- Name: CatalogItemRollSpecs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."CatalogItemRollSpecs" ENABLE ROW LEVEL SECURITY;

--
-- Name: CatalogItemSupply; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."CatalogItemSupply" ENABLE ROW LEVEL SECURITY;

--
-- Name: Companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."Companies" ENABLE ROW LEVEL SECURITY;

--
-- Name: CompanyPortalUsers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."CompanyPortalUsers" ENABLE ROW LEVEL SECURITY;

--
-- Name: ConfiguredProducts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."ConfiguredProducts" ENABLE ROW LEVEL SECURITY;

--
-- Name: DirectoryContacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."DirectoryContacts" ENABLE ROW LEVEL SECURITY;

--
-- Name: DirectoryCustomers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."DirectoryCustomers" ENABLE ROW LEVEL SECURITY;

--
-- Name: ManufacturingOrders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."ManufacturingOrders" ENABLE ROW LEVEL SECURITY;

--
-- Name: OrderList; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."OrderList" ENABLE ROW LEVEL SECURITY;

--
-- Name: OrganizationUserPermissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."OrganizationUserPermissions" ENABLE ROW LEVEL SECURITY;

--
-- Name: OrganizationUsers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."OrganizationUsers" ENABLE ROW LEVEL SECURITY;

--
-- Name: Organizations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."Organizations" ENABLE ROW LEVEL SECURITY;

--
-- Name: OrganizationUserPermissions Owners and admins can manage permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owners and admins can manage permissions" ON public."OrganizationUserPermissions" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.id = "OrganizationUserPermissions".organization_user_id) AND (EXISTS ( SELECT 1
           FROM public."OrganizationUsers" ou2
          WHERE ((ou2.organization_id = ou.organization_id) AND (ou2.user_id = auth.uid()) AND (ou2.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])) AND (ou2.deleted = false) AND (ou2.status = 'active'::public.org_user_status))))))));


--
-- Name: Organizations Owners can insert organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owners can insert organizations" ON public."Organizations" FOR INSERT WITH CHECK (true);


--
-- Name: Organizations Owners can update own organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owners can update own organizations" ON public."Organizations" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".organization_id = "Organizations".id) AND ("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".role = 'owner'::public.org_role) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status)))));


--
-- Name: Permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."Permissions" ENABLE ROW LEVEL SECURITY;

--
-- Name: QuoteLineComponents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."QuoteLineComponents" ENABLE ROW LEVEL SECURITY;

--
-- Name: QuoteLines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."QuoteLines" ENABLE ROW LEVEL SECURITY;

--
-- Name: Quotes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."Quotes" ENABLE ROW LEVEL SECURITY;

--
-- Name: SalesOrders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."SalesOrders" ENABLE ROW LEVEL SECURITY;

--
-- Name: OrderList Users can insert own organization order list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own organization order list" ON public."OrderList" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "OrderList".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))));


--
-- Name: Quotes Users can insert own organization quotes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own organization quotes" ON public."Quotes" FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "Quotes".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (created_by_user_id = auth.uid())));


--
-- Name: SalesOrders Users can insert own organization sales orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own organization sales orders" ON public."SalesOrders" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "SalesOrders".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))));


--
-- Name: OrderList Users can read own organization order list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own organization order list" ON public."OrderList" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "OrderList".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: OrganizationUserPermissions Users can read own organization permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own organization permissions" ON public."OrganizationUserPermissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.id = "OrganizationUserPermissions".organization_user_id) AND (EXISTS ( SELECT 1
           FROM public."OrganizationUsers" ou2
          WHERE ((ou2.organization_id = ou.organization_id) AND (ou2.user_id = auth.uid()) AND (ou2.deleted = false) AND (ou2.status = 'active'::public.org_user_status))))))));


--
-- Name: Quotes Users can read own organization quotes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own organization quotes" ON public."Quotes" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "Quotes".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: SalesOrders Users can read own organization sales orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own organization sales orders" ON public."SalesOrders" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "SalesOrders".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: Organizations Users can read own organizations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own organizations" ON public."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".organization_id = "Organizations".id) AND ("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status)))));


--
-- Name: OrderList Users can update own organization order list; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own organization order list" ON public."OrderList" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "OrderList".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: Quotes Users can update own organization quotes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own organization quotes" ON public."Quotes" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "Quotes".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: SalesOrders Users can update own organization sales orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own organization sales orders" ON public."SalesOrders" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "SalesOrders".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))) AND (deleted = false)));


--
-- Name: CatalogItemComponents catalogitemcomponents_select_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catalogitemcomponents_select_own_org ON public."CatalogItemComponents" FOR SELECT TO authenticated USING ((public.is_org_user_superadmin(organization_id) OR public.is_org_user_member(organization_id)));


--
-- Name: CatalogItemComponents catalogitemcomponents_write_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catalogitemcomponents_write_own_org ON public."CatalogItemComponents" TO authenticated USING ((public.is_org_user_superadmin(organization_id) OR public.is_org_user_member(organization_id))) WITH CHECK ((public.is_org_user_superadmin(organization_id) OR public.is_org_user_member(organization_id)));


--
-- Name: Companies companies_insert_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companies_insert_own_org ON public."Companies" FOR INSERT WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: Companies companies_select_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companies_select_own_org ON public."Companies" FOR SELECT USING ((public.is_org_member(organization_id) AND (deleted = false)));


--
-- Name: Companies companies_update_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companies_update_own_org ON public."Companies" FOR UPDATE USING (public.is_org_owner_or_admin(organization_id)) WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: CompanyPortalUsers companyportalusers_insert_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companyportalusers_insert_own_org ON public."CompanyPortalUsers" FOR INSERT WITH CHECK (public.is_company_owner_or_admin(company_id));


--
-- Name: CompanyPortalUsers companyportalusers_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companyportalusers_select ON public."CompanyPortalUsers" FOR SELECT USING (((deleted = false) AND (((user_id IS NOT NULL) AND (user_id = auth.uid())) OR ((user_id IS NULL) AND (portal_user_email IS NOT NULL) AND (public.current_auth_email() IS NOT NULL) AND (lower(TRIM(BOTH FROM portal_user_email)) = public.current_auth_email())) OR ((organization_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "CompanyPortalUsers".organization_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = ANY (ARRAY['active'::public.org_user_status, 'invited'::public.org_user_status])))))))));


--
-- Name: CompanyPortalUsers companyportalusers_select_stable; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companyportalusers_select_stable ON public."CompanyPortalUsers" FOR SELECT USING (((deleted = false) AND public.can_read_company_portal_user(id)));


--
-- Name: POLICY companyportalusers_select_stable ON "CompanyPortalUsers"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY companyportalusers_select_stable ON public."CompanyPortalUsers" IS 'Read portal users if self or internal org member.';


--
-- Name: CompanyPortalUsers companyportalusers_update_own_org; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companyportalusers_update_own_org ON public."CompanyPortalUsers" FOR UPDATE USING (public.is_company_owner_or_admin(company_id));


--
-- Name: CompanyPortalUsers companyportalusers_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companyportalusers_update_self ON public."CompanyPortalUsers" FOR UPDATE USING (public.is_portal_user_self(id)) WITH CHECK (public.is_portal_user_self(id));


--
-- Name: POLICY companyportalusers_update_self ON "CompanyPortalUsers"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY companyportalusers_update_self ON public."CompanyPortalUsers" IS 'Portal user can update only their own record (e.g. link user_id).';


--
-- Name: ConfiguredProducts configuredproducts_org_members_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY configuredproducts_org_members_insert ON public."ConfiguredProducts" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "ConfiguredProducts".organization_id) AND (ou.user_id = auth.uid()) AND (ou.status = 'active'::public.org_user_status) AND (ou.deleted = false)))));


--
-- Name: ConfiguredProducts configuredproducts_org_members_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY configuredproducts_org_members_select ON public."ConfiguredProducts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "ConfiguredProducts".organization_id) AND (ou.user_id = auth.uid()) AND (ou.status = 'active'::public.org_user_status) AND (ou.deleted = false)))));


--
-- Name: ConfiguredProducts configuredproducts_org_members_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY configuredproducts_org_members_update ON public."ConfiguredProducts" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "ConfiguredProducts".organization_id) AND (ou.user_id = auth.uid()) AND (ou.status = 'active'::public.org_user_status) AND (ou.deleted = false))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.organization_id = "ConfiguredProducts".organization_id) AND (ou.user_id = auth.uid()) AND (ou.status = 'active'::public.org_user_status) AND (ou.deleted = false)))));


--
-- Name: CatalogItemRollSpecs delete_catalog_item_roll_specs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delete_catalog_item_roll_specs ON public."CatalogItemRollSpecs" FOR DELETE USING (public.is_org_owner_or_admin(organization_id));


--
-- Name: CatalogItemSupply delete_catalog_item_supply; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delete_catalog_item_supply ON public."CatalogItemSupply" FOR DELETE USING (public.is_org_owner_or_admin(organization_id));


--
-- Name: DirectoryContacts dir_contacts_write_owner_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dir_contacts_write_owner_admin ON public."DirectoryContacts" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: DirectoryCustomers dir_customers_write_owner_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dir_customers_write_owner_admin ON public."DirectoryCustomers" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: DirectoryContacts dircontacts_select_correct; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dircontacts_select_correct ON public."DirectoryContacts" FOR SELECT USING (((deleted = false) AND (((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id)))));


--
-- Name: DirectoryContacts dircontacts_write_correct; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dircontacts_write_correct ON public."DirectoryContacts" USING (((((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id))) AND (deleted = false))) WITH CHECK ((((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id))));


--
-- Name: DirectoryCustomers dircustomers_select_correct; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dircustomers_select_correct ON public."DirectoryCustomers" FOR SELECT USING (((deleted = false) AND (((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id)))));


--
-- Name: DirectoryCustomers dircustomers_write_correct; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dircustomers_write_correct ON public."DirectoryCustomers" USING (((((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id))) AND (deleted = false))) WITH CHECK ((((organization_id IS NOT NULL) AND public.is_org_user_superadmin(organization_id)) OR ((company_id IS NOT NULL) AND public.is_company_portal_user(company_id)) OR ((organization_id IS NOT NULL) AND public.is_org_user_member(organization_id))));


--
-- Name: CatalogItemRollSpecs insert_catalog_item_roll_specs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY insert_catalog_item_roll_specs ON public."CatalogItemRollSpecs" FOR INSERT WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: CatalogItemSupply insert_catalog_item_supply; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY insert_catalog_item_supply ON public."CatalogItemSupply" FOR INSERT WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: ManufacturingOrders mo_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mo_select ON public."ManufacturingOrders" FOR SELECT USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status))))));


--
-- Name: ManufacturingOrders mo_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mo_write ON public."ManufacturingOrders" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: OrderList orderlist_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orderlist_access ON public."OrderList" USING ((organization_id IN ( SELECT "OrganizationUsers".organization_id
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status))))) WITH CHECK (true);


--
-- Name: Organizations org_member_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY org_member_select ON public."Organizations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".organization_id = "OrganizationUsers".id) AND ("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status)))));


--
-- Name: Organizations organizations_select_portal_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organizations_select_portal_users ON public."Organizations" FOR SELECT USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public."CompanyPortalUsers" cpu
  WHERE ((cpu.organization_id = "Organizations".id) AND (cpu.deleted = false) AND (cpu.status = ANY (ARRAY['active'::public.portal_user_status, 'invited'::public.portal_user_status])) AND (((cpu.user_id IS NOT NULL) AND (cpu.user_id = auth.uid())) OR ((cpu.user_id IS NULL) AND (cpu.portal_user_email IS NOT NULL) AND (public.current_auth_email() IS NOT NULL) AND (lower(TRIM(BOTH FROM cpu.portal_user_email)) = public.current_auth_email()))))))));


--
-- Name: OrganizationUserPermissions orguserperms_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orguserperms_delete_admin ON public."OrganizationUserPermissions" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" target_ou
  WHERE ((target_ou.id = "OrganizationUserPermissions".organization_user_id) AND (target_ou.deleted = false) AND public.is_org_user_superadmin(target_ou.organization_id)))));


--
-- Name: POLICY orguserperms_delete_admin ON "OrganizationUserPermissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY orguserperms_delete_admin ON public."OrganizationUserPermissions" IS 'Superadmin/Admin can delete permissions for users in their organization. Uses non-recursive helper function.';


--
-- Name: OrganizationUserPermissions orguserperms_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orguserperms_insert_admin ON public."OrganizationUserPermissions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" target_ou
  WHERE ((target_ou.id = "OrganizationUserPermissions".organization_user_id) AND (target_ou.deleted = false) AND public.is_org_user_superadmin(target_ou.organization_id)))));


--
-- Name: POLICY orguserperms_insert_admin ON "OrganizationUserPermissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY orguserperms_insert_admin ON public."OrganizationUserPermissions" IS 'Superadmin/Admin can insert permissions for users in their organization. Uses non-recursive helper function.';


--
-- Name: OrganizationUserPermissions orguserperms_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orguserperms_select_own ON public."OrganizationUserPermissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.id = "OrganizationUserPermissions".organization_user_id) AND (ou.user_id = auth.uid()) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status)))));


--
-- Name: POLICY orguserperms_select_own ON "OrganizationUserPermissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY orguserperms_select_own ON public."OrganizationUserPermissions" IS 'Users can read their own permissions via organization_user_id. This is safe because OrganizationUsers has non-recursive select policy.';


--
-- Name: OrganizationUserPermissions orguserperms_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orguserperms_update_admin ON public."OrganizationUserPermissions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" target_ou
  WHERE ((target_ou.id = "OrganizationUserPermissions".organization_user_id) AND (target_ou.deleted = false) AND public.is_org_user_superadmin(target_ou.organization_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" target_ou
  WHERE ((target_ou.id = "OrganizationUserPermissions".organization_user_id) AND (target_ou.deleted = false) AND public.is_org_user_superadmin(target_ou.organization_id)))));


--
-- Name: POLICY orguserperms_update_admin ON "OrganizationUserPermissions"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY orguserperms_update_admin ON public."OrganizationUserPermissions" IS 'Superadmin/Admin can update permissions for users in their organization. Uses non-recursive helper function.';


--
-- Name: OrganizationUsers orgusers_select_by_org_for_superadmin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orgusers_select_by_org_for_superadmin ON public."OrganizationUsers" FOR SELECT USING (((deleted = false) AND (public.is_org_user_superadmin(organization_id) = true)));


--
-- Name: OrganizationUsers orgusers_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orgusers_select_own ON public."OrganizationUsers" FOR SELECT USING (((user_id = auth.uid()) AND (deleted = false)));


--
-- Name: OrganizationUsers orgusers_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orgusers_select_self ON public."OrganizationUsers" FOR SELECT USING (((deleted = false) AND (user_id = auth.uid())));


--
-- Name: OrganizationUsers orgusers_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY orgusers_update_own ON public."OrganizationUsers" FOR UPDATE USING (((user_id = auth.uid()) AND (deleted = false))) WITH CHECK (((user_id = auth.uid()) AND (deleted = false)));


--
-- Name: DirectoryContacts portal_select_contacts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY portal_select_contacts ON public."DirectoryContacts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."CompanyPortalUsers" cpu
  WHERE ((cpu.company_id = "DirectoryContacts".company_id) AND (cpu.user_id = auth.uid()) AND (cpu.deleted = false) AND (cpu.status = 'active'::public.portal_user_status)))));


--
-- Name: DirectoryCustomers portal_select_customers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY portal_select_customers ON public."DirectoryCustomers" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public."CompanyPortalUsers" cpu
  WHERE ((cpu.user_id = auth.uid()) AND (cpu.company_id = "DirectoryCustomers".company_id) AND (cpu.deleted = false) AND (cpu.status = 'active'::public.portal_user_status)))));


--
-- Name: CompanyPortalUsers portal_users_write_owner_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY portal_users_write_owner_admin ON public."CompanyPortalUsers" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: QuoteLineComponents qlc_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY qlc_delete ON public."QuoteLineComponents" FOR DELETE USING (public.is_org_user_member(organization_id));


--
-- Name: QuoteLineComponents qlc_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY qlc_insert ON public."QuoteLineComponents" FOR INSERT WITH CHECK (public.is_org_user_member(organization_id));


--
-- Name: QuoteLineComponents qlc_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY qlc_select ON public."QuoteLineComponents" FOR SELECT USING (public.is_org_user_member(organization_id));


--
-- Name: QuoteLineComponents qlc_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY qlc_update ON public."QuoteLineComponents" FOR UPDATE USING (public.is_org_user_member(organization_id)) WITH CHECK (public.is_org_user_member(organization_id));


--
-- Name: QuoteLines quotelines_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotelines_delete ON public."QuoteLines" FOR DELETE USING (public.is_org_user_member(organization_id));


--
-- Name: QuoteLines quotelines_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotelines_insert ON public."QuoteLines" FOR INSERT WITH CHECK ((public.is_org_user_member(organization_id) AND (EXISTS ( SELECT 1
   FROM public."Quotes" q
  WHERE ((q.id = "QuoteLines".quote_id) AND (q.organization_id = "QuoteLines".organization_id) AND (q.deleted = false))))));


--
-- Name: QuoteLines quotelines_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotelines_select ON public."QuoteLines" FOR SELECT USING (public.is_org_user_member(organization_id));


--
-- Name: QuoteLines quotelines_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotelines_update ON public."QuoteLines" FOR UPDATE USING (public.is_org_user_member(organization_id)) WITH CHECK (public.is_org_user_member(organization_id));


--
-- Name: Quotes quotes_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_access ON public."Quotes" USING ((organization_id IN ( SELECT "OrganizationUsers".organization_id
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status))))) WITH CHECK (true);


--
-- Name: Quotes quotes_portal_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_portal_insert ON public."Quotes" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.get_current_portal_user() p(id, organization_id, company_id, portal_user_role, status)
  WHERE ((p.company_id = "Quotes".company_id) AND (p.portal_user_role = ANY (ARRAY['member'::text, 'member_manager'::text])) AND ("Quotes".created_by_portal_user_id = p.id)))));


--
-- Name: Quotes quotes_portal_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_portal_select ON public."Quotes" FOR SELECT USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public.get_current_portal_user() p(id, organization_id, company_id, portal_user_role, status)
  WHERE ((p.company_id = "Quotes".company_id) AND ((p.portal_user_role = 'member_manager'::text) OR ((p.portal_user_role = 'member'::text) AND ("Quotes".created_by_portal_user_id = p.id))))))));


--
-- Name: Quotes quotes_portal_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_portal_update ON public."Quotes" FOR UPDATE USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public.get_current_portal_user() p(id, organization_id, company_id, portal_user_role, status)
  WHERE ((p.company_id = "Quotes".company_id) AND ((p.portal_user_role = 'member_manager'::text) OR ((p.portal_user_role = 'member'::text) AND ("Quotes".created_by_portal_user_id = p.id) AND ("Quotes".status = 'draft'::public.quote_status)))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.get_current_portal_user() p(id, organization_id, company_id, portal_user_role, status)
  WHERE ((p.company_id = "Quotes".company_id) AND ((p.portal_user_role = 'member_manager'::text) OR ((p.portal_user_role = 'member'::text) AND ("Quotes".created_by_portal_user_id = p.id) AND ("Quotes".status = 'draft'::public.quote_status)))))));


--
-- Name: Quotes quotes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_select ON public."Quotes" FOR SELECT USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status))))));


--
-- Name: Quotes quotes_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_write ON public."Quotes" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: SalesOrders salesorders_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY salesorders_select ON public."SalesOrders" FOR SELECT USING (((deleted = false) AND (EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status))))));


--
-- Name: SalesOrders salesorders_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY salesorders_write ON public."SalesOrders" USING ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public."OrganizationUsers" ou
  WHERE ((ou.user_id = auth.uid()) AND (ou.organization_id = ou.organization_id) AND (ou.deleted = false) AND (ou.status = 'active'::public.org_user_status) AND (ou.role = ANY (ARRAY['owner'::public.org_role, 'admin'::public.org_role]))))));


--
-- Name: CatalogItemRollSpecs select_catalog_item_roll_specs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY select_catalog_item_roll_specs ON public."CatalogItemRollSpecs" FOR SELECT USING (public.is_org_user_member(organization_id));


--
-- Name: CatalogItemSupply select_catalog_item_supply; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY select_catalog_item_supply ON public."CatalogItemSupply" FOR SELECT USING (public.is_org_user_member(organization_id));


--
-- Name: SalesOrders so_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY so_access ON public."SalesOrders" USING ((organization_id IN ( SELECT "OrganizationUsers".organization_id
   FROM public."OrganizationUsers"
  WHERE (("OrganizationUsers".user_id = auth.uid()) AND ("OrganizationUsers".deleted = false) AND ("OrganizationUsers".status = 'active'::public.org_user_status))))) WITH CHECK (true);


--
-- Name: CatalogItemRollSpecs update_catalog_item_roll_specs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY update_catalog_item_roll_specs ON public."CatalogItemRollSpecs" FOR UPDATE USING (public.is_org_owner_or_admin(organization_id)) WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: CatalogItemSupply update_catalog_item_supply; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY update_catalog_item_supply ON public."CatalogItemSupply" FOR UPDATE USING (public.is_org_owner_or_admin(organization_id)) WITH CHECK (public.is_org_owner_or_admin(organization_id));


--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_namespaces; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_namespaces ENABLE ROW LEVEL SECURITY;

--
-- Name: iceberg_tables; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.iceberg_tables ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: prefixes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.prefixes ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict 5G05meZYAc8oVX3r7JpYVEa20msRpp4GT7QgLLweqPaeaf3ykuhZAQn4KTa1bkS

