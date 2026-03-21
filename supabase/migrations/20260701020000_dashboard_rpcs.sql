-- Dashboard Overview RPC: KPIs, station loads, alerts, urgency per MO
-- Also includes order_urgency_cache table for performance

CREATE TABLE IF NOT EXISTS public.order_urgency_cache (
  manufacturing_order_id uuid PRIMARY KEY REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  urgency varchar(20) NOT NULL DEFAULT 'on_track',
  progress_pct numeric(5,2) DEFAULT 0,
  due_date date,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.order_urgency_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "org read urgency cache" ON public.order_urgency_cache
  FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION public.get_dashboard_overview(p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
  v_kpis jsonb;
  v_alerts jsonb;
  v_station_loads jsonb;
  v_today date := current_date;
BEGIN
  -- KPIs
  SELECT jsonb_build_object(
    'active_orders', COALESCE(SUM(CASE WHEN mo.status NOT IN ('completed','delivered','cancelled') THEN 1 ELSE 0 END), 0),
    'completed_orders', COALESCE(SUM(CASE WHEN mo.status IN ('completed','delivered') THEN 1 ELSE 0 END), 0),
    'total_orders', COUNT(*),
    'critical_count', 0,
    'at_risk_count', 0,
    'on_track_count', 0
  ) INTO v_kpis
  FROM public."ManufacturingOrders" mo
  WHERE mo.organization_id = p_org_id
    AND mo.deleted = false
    AND mo.created_at >= (v_today - interval '90 days');

  -- Calculate urgency per active MO
  WITH mo_progress AS (
    SELECT
      mo.id AS mo_id,
      mo.manufacturing_order_no,
      mo.status AS mo_status,
      mo.planned_start_at,
      mo.planned_end_at,
      so.requested_delivery_date AS due_date,
      so.order_number AS so_number,
      COALESCE(
        ROUND(
          COUNT(CASE WHEN wot.status = 'completed' THEN 1 END)::numeric
          / NULLIF(COUNT(wot.id), 0) * 100, 0
        ), 0
      ) AS progress_pct,
      COUNT(wot.id) AS total_tasks,
      COUNT(CASE WHEN wot.status = 'completed' THEN 1 END) AS completed_tasks
    FROM public."ManufacturingOrders" mo
    LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
    LEFT JOIN public."WorkOrderTasks" wot ON wot.manufacturing_order_id = mo.id AND wot.deleted = false
    WHERE mo.organization_id = p_org_id
      AND mo.deleted = false
      AND mo.status NOT IN ('completed','delivered','cancelled')
    GROUP BY mo.id, mo.manufacturing_order_no, mo.status, mo.planned_start_at, mo.planned_end_at,
             so.requested_delivery_date, so.order_number
  ),
  urgency_calc AS (
    SELECT
      mp.*,
      CASE
        WHEN mp.due_date IS NOT NULL AND v_today > mp.due_date THEN 'critical'
        WHEN mp.due_date IS NOT NULL AND (mp.due_date - v_today) <= 2 AND mp.progress_pct < 50 THEN 'at_risk'
        WHEN mp.total_tasks > 0 AND mp.completed_tasks = mp.total_tasks THEN 'completed'
        WHEN mp.due_date IS NOT NULL AND (mp.due_date - v_today) <= 2 AND mp.progress_pct >= 50 THEN 'attention'
        ELSE 'on_track'
      END AS urgency
    FROM mo_progress mp
  )
  SELECT
    jsonb_agg(
      jsonb_build_object(
        'mo_id', uc.mo_id,
        'mo_number', uc.manufacturing_order_no,
        'so_number', uc.so_number,
        'urgency', uc.urgency,
        'progress_pct', uc.progress_pct,
        'due_date', uc.due_date,
        'mo_status', uc.mo_status
      ) ORDER BY
        CASE uc.urgency
          WHEN 'critical' THEN 1
          WHEN 'at_risk' THEN 2
          WHEN 'attention' THEN 3
          WHEN 'on_track' THEN 4
          ELSE 5
        END, uc.due_date NULLS LAST
    ) INTO v_alerts
  FROM urgency_calc uc
  WHERE uc.urgency IN ('critical','at_risk','attention');

  -- Update KPIs with urgency counts
  WITH urgency_counts AS (
    SELECT
      CASE
        WHEN due_date IS NOT NULL AND v_today > due_date THEN 'critical'
        WHEN due_date IS NOT NULL AND (due_date - v_today) <= 2 AND progress_pct < 50 THEN 'at_risk'
        ELSE 'on_track'
      END AS urgency,
      COUNT(*) AS cnt
    FROM (
      SELECT
        so.requested_delivery_date AS due_date,
        COALESCE(
          ROUND(
            COUNT(CASE WHEN wot.status = 'completed' THEN 1 END)::numeric
            / NULLIF(COUNT(wot.id), 0) * 100, 0
          ), 0
        ) AS progress_pct
      FROM public."ManufacturingOrders" mo
      LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
      LEFT JOIN public."WorkOrderTasks" wot ON wot.manufacturing_order_id = mo.id AND wot.deleted = false
      WHERE mo.organization_id = p_org_id
        AND mo.deleted = false
        AND mo.status NOT IN ('completed','delivered','cancelled')
      GROUP BY mo.id, so.requested_delivery_date
    ) sub
    GROUP BY 1
  )
  SELECT v_kpis
    || jsonb_build_object(
      'critical_count', COALESCE((SELECT cnt FROM urgency_counts WHERE urgency = 'critical'), 0),
      'at_risk_count', COALESCE((SELECT cnt FROM urgency_counts WHERE urgency = 'at_risk'), 0),
      'on_track_count', COALESCE((SELECT cnt FROM urgency_counts WHERE urgency = 'on_track'), 0)
    )
  INTO v_kpis;

  -- Station loads for today
  WITH day_loads AS (
    SELECT
      wc.id AS station_id,
      wc.name AS station_name,
      wc.code AS station_code,
      wc.capacity_hours_per_day,
      COALESCE(SUM(wot.estimated_duration_hours), 0) AS used_hours
    FROM public."WorkCenters" wc
    LEFT JOIN public."WorkOrderTasks" wot
      ON wot.work_center_id = wc.id
      AND wot.deleted = false
      AND wot.planned_start_at::date <= v_today
      AND wot.planned_end_at::date >= v_today
      AND wot.status NOT IN ('completed','cancelled')
    WHERE wc.organization_id = p_org_id
      AND wc.deleted = false
      AND wc.is_active = true
    GROUP BY wc.id, wc.name, wc.code, wc.capacity_hours_per_day
    ORDER BY wc.sequence
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'station_id', dl.station_id,
      'station_name', dl.station_name,
      'station_code', dl.station_code,
      'capacity', dl.capacity_hours_per_day,
      'used_hours', dl.used_hours,
      'utilization_pct', CASE WHEN dl.capacity_hours_per_day > 0
        THEN ROUND(dl.used_hours / dl.capacity_hours_per_day * 100, 0)
        ELSE 0 END,
      'level', CASE
        WHEN dl.used_hours <= 8 THEN 'ok'
        WHEN dl.used_hours <= 12 THEN 'warning'
        ELSE 'overload'
      END
    )
  ) INTO v_station_loads
  FROM day_loads dl;

  v_result := jsonb_build_object(
    'kpis', v_kpis,
    'alerts', COALESCE(v_alerts, '[]'::jsonb),
    'station_loads', COALESCE(v_station_loads, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;
