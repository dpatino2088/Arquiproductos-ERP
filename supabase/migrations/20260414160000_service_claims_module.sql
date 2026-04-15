-- ============================================================
-- Service Claims Module
-- Tables, enums, auto-numbering, RLS, storage bucket
-- ============================================================

-- 1. Enums
DO $$ BEGIN
  CREATE TYPE claim_status_enum AS ENUM ('draft','under_review','approved','in_progress','resolved','closed','rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE claim_type_enum AS ENUM ('defect','damage','wrong_size','wrong_color','missing_parts','other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE claim_priority_enum AS ENUM ('low','medium','high','urgent');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE claim_resolution_enum AS ENUM ('repair','replace','credit','none');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. ServiceClaims
CREATE TABLE IF NOT EXISTS public."ServiceClaims" (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_no      text,
  organization_id uuid NOT NULL,
  dealer_id     uuid REFERENCES public."Dealers"(id),
  sales_order_id uuid REFERENCES public."SalesOrders"(id),
  status        claim_status_enum NOT NULL DEFAULT 'draft',
  claim_type    claim_type_enum NOT NULL DEFAULT 'other',
  priority      claim_priority_enum NOT NULL DEFAULT 'medium',
  description   text,
  resolution_type claim_resolution_enum DEFAULT 'none',
  resolution_notes text,
  resolution_mo_id uuid REFERENCES public."ManufacturingOrders"(id),
  reported_by   uuid,
  assigned_to   uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz DEFAULT now(),
  resolved_at   timestamptz,
  deleted       boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_service_claims_org     ON public."ServiceClaims"(organization_id);
CREATE INDEX IF NOT EXISTS idx_service_claims_dealer  ON public."ServiceClaims"(dealer_id);
CREATE INDEX IF NOT EXISTS idx_service_claims_so      ON public."ServiceClaims"(sales_order_id);
CREATE INDEX IF NOT EXISTS idx_service_claims_status  ON public."ServiceClaims"(status);

-- 3. ServiceClaimLines
CREATE TABLE IF NOT EXISTS public."ServiceClaimLines" (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id              uuid NOT NULL REFERENCES public."ServiceClaims"(id) ON DELETE CASCADE,
  sale_order_line_id    uuid REFERENCES public."SaleOrderLines"(id),
  configured_product_id uuid REFERENCES public."ConfiguredProducts"(id),
  description           text,
  qty_affected          integer NOT NULL DEFAULT 1,
  claim_reason          text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  deleted               boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_service_claim_lines_claim ON public."ServiceClaimLines"(claim_id);
CREATE INDEX IF NOT EXISTS idx_service_claim_lines_sol   ON public."ServiceClaimLines"(sale_order_line_id);

-- 4. ServiceClaimAttachments
CREATE TABLE IF NOT EXISTS public."ServiceClaimAttachments" (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id        uuid NOT NULL REFERENCES public."ServiceClaims"(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  file_name       text NOT NULL,
  file_path       text NOT NULL,
  uploaded_by     uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  deleted         boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_service_claim_attachments_claim ON public."ServiceClaimAttachments"(claim_id);

-- 5. Auto-numbering: CLM-NNNNN-YYMMDD
CREATE OR REPLACE FUNCTION public.generate_claim_no()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_max_num int;
  v_date_suffix text;
BEGIN
  IF NEW.claim_no IS NOT NULL AND NEW.claim_no <> '' THEN
    RETURN NEW;
  END IF;

  v_date_suffix := to_char(CURRENT_DATE, 'YYMMDD');

  SELECT COALESCE(MAX(
    CASE
      WHEN claim_no ~ '^CLM-\d{5}'
        THEN (substring(claim_no from 5 for 5))::integer
      ELSE 0
    END
  ), 0) INTO v_max_num
  FROM public."ServiceClaims"
  WHERE organization_id = NEW.organization_id
    AND deleted = false;

  NEW.claim_no := 'CLM-' || LPAD((v_max_num + 1)::text, 5, '0') || '-' || v_date_suffix;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_generate_claim_number ON public."ServiceClaims";
CREATE TRIGGER trg_generate_claim_number
  BEFORE INSERT ON public."ServiceClaims"
  FOR EACH ROW EXECUTE FUNCTION public.generate_claim_no();

-- 6. Updated_at trigger
CREATE OR REPLACE FUNCTION public.service_claims_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_service_claims_updated_at ON public."ServiceClaims";
CREATE TRIGGER trg_service_claims_updated_at
  BEFORE UPDATE ON public."ServiceClaims"
  FOR EACH ROW EXECUTE FUNCTION public.service_claims_updated_at();

-- 7. RLS
ALTER TABLE public."ServiceClaims" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ServiceClaimLines" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ServiceClaimAttachments" ENABLE ROW LEVEL SECURITY;

-- ServiceClaims SELECT
DROP POLICY IF EXISTS "service_claims_select" ON public."ServiceClaims";
CREATE POLICY "service_claims_select"
  ON public."ServiceClaims" FOR SELECT TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      session_is_org_user(organization_id)
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  );

-- ServiceClaims INSERT
DROP POLICY IF EXISTS "service_claims_insert" ON public."ServiceClaims";
CREATE POLICY "service_claims_insert"
  ON public."ServiceClaims" FOR INSERT TO authenticated
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      session_is_org_user(organization_id)
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  );

-- ServiceClaims UPDATE
DROP POLICY IF EXISTS "service_claims_update" ON public."ServiceClaims";
CREATE POLICY "service_claims_update"
  ON public."ServiceClaims" FOR UPDATE TO authenticated
  USING (
    deleted IS NOT TRUE
    AND organization_id IS NOT NULL
    AND (
      session_is_org_user(organization_id)
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  )
  WITH CHECK (
    organization_id IS NOT NULL
    AND (
      session_is_org_user(organization_id)
      OR (session_is_dealer_user(organization_id) AND dealer_id = current_dealer_id())
      OR (dealer_id IS NOT NULL AND is_dealer_portal_user(dealer_id))
    )
  );

-- ServiceClaimLines SELECT
DROP POLICY IF EXISTS "service_claim_lines_select" ON public."ServiceClaimLines";
CREATE POLICY "service_claim_lines_select"
  ON public."ServiceClaimLines" FOR SELECT TO authenticated
  USING (
    deleted IS NOT TRUE
    AND EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id AND sc.deleted IS NOT TRUE
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimLines INSERT
DROP POLICY IF EXISTS "service_claim_lines_insert" ON public."ServiceClaimLines";
CREATE POLICY "service_claim_lines_insert"
  ON public."ServiceClaimLines" FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimLines UPDATE
DROP POLICY IF EXISTS "service_claim_lines_update" ON public."ServiceClaimLines";
CREATE POLICY "service_claim_lines_update"
  ON public."ServiceClaimLines" FOR UPDATE TO authenticated
  USING (
    deleted IS NOT TRUE
    AND EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id AND sc.deleted IS NOT TRUE
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimAttachments SELECT
DROP POLICY IF EXISTS "service_claim_attachments_select" ON public."ServiceClaimAttachments";
CREATE POLICY "service_claim_attachments_select"
  ON public."ServiceClaimAttachments" FOR SELECT TO authenticated
  USING (
    deleted IS NOT TRUE
    AND EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id AND sc.deleted IS NOT TRUE
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimAttachments INSERT
DROP POLICY IF EXISTS "service_claim_attachments_insert" ON public."ServiceClaimAttachments";
CREATE POLICY "service_claim_attachments_insert"
  ON public."ServiceClaimAttachments" FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimAttachments UPDATE
DROP POLICY IF EXISTS "service_claim_attachments_update" ON public."ServiceClaimAttachments";
CREATE POLICY "service_claim_attachments_update"
  ON public."ServiceClaimAttachments" FOR UPDATE TO authenticated
  USING (
    deleted IS NOT TRUE
    AND EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id AND sc.deleted IS NOT TRUE
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- ServiceClaimAttachments DELETE
DROP POLICY IF EXISTS "service_claim_attachments_delete" ON public."ServiceClaimAttachments";
CREATE POLICY "service_claim_attachments_delete"
  ON public."ServiceClaimAttachments" FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."ServiceClaims" sc
      WHERE sc.id = claim_id
      AND (
        session_is_org_user(sc.organization_id)
        OR (session_is_dealer_user(sc.organization_id) AND sc.dealer_id = current_dealer_id())
        OR (sc.dealer_id IS NOT NULL AND is_dealer_portal_user(sc.dealer_id))
      )
    )
  );

-- 8. Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
VALUES (
  'service-claim-attachments',
  'service-claim-attachments',
  true,
  10485760,
  ARRAY[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ],
  now(),
  now()
)
ON CONFLICT (name) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();

DROP POLICY IF EXISTS "service_claim_attachments_storage_select" ON storage.objects;
CREATE POLICY "service_claim_attachments_storage_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'service-claim-attachments');

DROP POLICY IF EXISTS "service_claim_attachments_storage_insert" ON storage.objects;
CREATE POLICY "service_claim_attachments_storage_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'service-claim-attachments');

DROP POLICY IF EXISTS "service_claim_attachments_storage_update" ON storage.objects;
CREATE POLICY "service_claim_attachments_storage_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'service-claim-attachments')
  WITH CHECK (bucket_id = 'service-claim-attachments');

DROP POLICY IF EXISTS "service_claim_attachments_storage_delete" ON storage.objects;
CREATE POLICY "service_claim_attachments_storage_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'service-claim-attachments');

-- 9. Timeline trigger for status changes
CREATE OR REPLACE FUNCTION public.service_claim_timeline_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public."ActivityTimeline" (entity_type, entity_id, action, description, user_name, metadata)
    VALUES (
      'service_claim',
      NEW.id,
      'status_changed',
      'Status changed from ' || OLD.status::text || ' to ' || NEW.status::text,
      COALESCE(current_setting('app.current_user_name', true), 'System'),
      jsonb_build_object('old_status', OLD.status::text, 'new_status', NEW.status::text)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_claim_timeline ON public."ServiceClaims";
CREATE TRIGGER trg_service_claim_timeline
  AFTER UPDATE ON public."ServiceClaims"
  FOR EACH ROW EXECUTE FUNCTION public.service_claim_timeline_trigger();
