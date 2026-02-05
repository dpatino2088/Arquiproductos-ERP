-- Create missing table QuoteLineComponents (referenced by pricing functions and frontend).
-- v7 dump references QuoteLineComponents but does not create it, causing:
--   relation "public"."QuoteLineComponents" does not exist

CREATE TABLE IF NOT EXISTS public."QuoteLineComponents" (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  organization_id uuid NOT NULL,
  quote_line_id uuid NOT NULL,

  -- What this row represents
  component_role text NOT NULL,
  kind text DEFAULT 'option'::text NOT NULL, -- option | selection | override | accessory
  source text DEFAULT 'configured_component'::text NOT NULL,

  -- Optional link to catalog item (for selections/accessories)
  catalog_item_id uuid,

  -- Pricing inputs
  qty numeric(12,4) DEFAULT 1 NOT NULL,
  unit_cost_exw numeric(12,4),

  -- Flexible payload (options, additional info)
  payload jsonb DEFAULT '{}'::jsonb NOT NULL,

  deleted boolean DEFAULT false NOT NULL,
  archived boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,

  CONSTRAINT "QuoteLineComponents_pkey" PRIMARY KEY (id),
  CONSTRAINT "quotelinecomponents_kind_check" CHECK (
    kind = ANY (ARRAY['option'::text, 'selection'::text, 'override'::text, 'accessory'::text])
  ),
  CONSTRAINT "quotelinecomponents_component_role_check" CHECK (
    component_role = ANY (ARRAY[
      -- BOM roles
      'tube','track','bottom_bar','bottom_channel','hem_weight','side_channel','side_channels',
      'top_rail','headbox','bracket','idler','drive','motor','adapter','chain','chain_stop',
      'chain_tensioner','wand','end_cap','filler','tape','consumable','fastener','accessory',
      'carrier','belt','belt_connector','bearing','hook','brush',
      -- Config options
      'hardware_color','drive_type','system_size','cassette','bottom_rail_type','tube_type',
      -- Fabric selection
      'fabric'
    ])
  )
);

ALTER TABLE public."QuoteLineComponents" OWNER TO postgres;

-- Foreign keys (match older dumps)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'qlc_quote_line_fk'
  ) THEN
    ALTER TABLE ONLY public."QuoteLineComponents"
      ADD CONSTRAINT qlc_quote_line_fk
      FOREIGN KEY (quote_line_id) REFERENCES public."QuoteLines"(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'qlc_item_fk'
  ) THEN
    ALTER TABLE ONLY public."QuoteLineComponents"
      ADD CONSTRAINT qlc_item_fk
      FOREIGN KEY (catalog_item_id) REFERENCES public."CatalogItems"(id) ON DELETE RESTRICT;
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_qlc_org_id ON public."QuoteLineComponents"(organization_id);
CREATE INDEX IF NOT EXISTS idx_qlc_quote_line_id ON public."QuoteLineComponents"(quote_line_id);
CREATE INDEX IF NOT EXISTS idx_qlc_role ON public."QuoteLineComponents"(component_role);

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_quote_line_components_updated_at ON public."QuoteLineComponents";
CREATE TRIGGER trg_quote_line_components_updated_at
BEFORE UPDATE ON public."QuoteLineComponents"
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- RLS + policies (internal org members)
ALTER TABLE public."QuoteLineComponents" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS qlc_select ON public."QuoteLineComponents";
DROP POLICY IF EXISTS qlc_insert ON public."QuoteLineComponents";
DROP POLICY IF EXISTS qlc_update ON public."QuoteLineComponents";
DROP POLICY IF EXISTS qlc_delete ON public."QuoteLineComponents";

CREATE POLICY qlc_select
ON public."QuoteLineComponents"
FOR SELECT
USING (public.is_org_user_member(organization_id));

CREATE POLICY qlc_insert
ON public."QuoteLineComponents"
FOR INSERT
WITH CHECK (public.is_org_user_member(organization_id));

CREATE POLICY qlc_update
ON public."QuoteLineComponents"
FOR UPDATE
USING (public.is_org_user_member(organization_id))
WITH CHECK (public.is_org_user_member(organization_id));

CREATE POLICY qlc_delete
ON public."QuoteLineComponents"
FOR DELETE
USING (public.is_org_user_member(organization_id));

