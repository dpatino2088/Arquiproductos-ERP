-- Bottleneck Analyzer RPC
CREATE OR REPLACE FUNCTION public.analyze_bottleneck(p_org_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
  v_today date := current_date;
BEGIN
  WITH station_delays AS (
    SELECT
      wc.id AS station_id,
      wc.name AS station_name,
      wc.code AS station_code,
      wc.capacity_hours_per_day,
      AVG(
        CASE WHEN wot.completed_at IS NOT NULL AND wot.planned_end_at IS NOT NULL
          THEN EXTRACT(EPOCH FROM (wot.completed_at - wot.planned_end_at)) / 86400.0
          ELSE NULL
        END
      ) AS avg_delay_days,
      COUNT(CASE WHEN wot.completed_at IS NOT NULL THEN 1 END) AS completed_count
    FROM public."WorkCenters" wc
    LEFT JOIN (
      SELECT * FROM public."WorkOrderTasks"
      WHERE deleted = false AND status = 'completed'
      ORDER BY completed_at DESC
      LIMIT 100
    ) wot ON wot.work_center_id = wc.id
    WHERE wc.organization_id = p_org_id
      AND wc.deleted = false
      AND wc.is_active = true
    GROUP BY wc.id, wc.name, wc.code, wc.capacity_hours_per_day, wc.sequence
    ORDER BY wc.sequence
  ),
  load_48h AS (
    SELECT
      wot.work_center_id AS station_id,
      COALESCE(SUM(wot.estimated_duration_hours), 0) AS load_hours
    FROM public."WorkOrderTasks" wot
    WHERE wot.organization_id = p_org_id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
      AND wot.planned_start_at::date <= v_today + 2
      AND wot.planned_end_at::date >= v_today
    GROUP BY wot.work_center_id
  ),
  bottleneck AS (
    SELECT
      sd.station_id,
      sd.station_name,
      sd.station_code,
      ROUND(COALESCE(sd.avg_delay_days, 0)::numeric, 1) AS current_delay_days,
      ROUND(
        COALESCE(sd.avg_delay_days, 0)
        + GREATEST(0, COALESCE(l.load_hours, 0) - sd.capacity_hours_per_day * 2)
          / NULLIF(sd.capacity_hours_per_day, 0)
      , 1) AS projected_delay_48h,
      sd.completed_count,
      COALESCE(l.load_hours, 0) AS load_48h_hours,
      sd.capacity_hours_per_day
    FROM station_delays sd
    LEFT JOIN load_48h l ON l.station_id = sd.station_id
    ORDER BY COALESCE(sd.avg_delay_days, 0) DESC
  ),
  affected AS (
    SELECT
      b.station_id,
      jsonb_agg(DISTINCT jsonb_build_object(
        'mo_id', mo.id,
        'mo_number', mo.manufacturing_order_no
      )) AS affected_orders
    FROM bottleneck b
    JOIN public."WorkOrderTasks" wot
      ON wot.work_center_id = b.station_id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
    JOIN public."ManufacturingOrders" mo
      ON mo.id = wot.manufacturing_order_id
      AND mo.deleted = false
      AND mo.status NOT IN ('completed','delivered','cancelled')
    WHERE b.current_delay_days > 0
    GROUP BY b.station_id
  )
  SELECT jsonb_build_object(
    'bottleneck_station', (SELECT station_name FROM bottleneck LIMIT 1),
    'bottleneck_station_id', (SELECT station_id FROM bottleneck LIMIT 1),
    'current_delay_days', (SELECT current_delay_days FROM bottleneck LIMIT 1),
    'projected_delay_48h', (SELECT projected_delay_48h FROM bottleneck LIMIT 1),
    'recommendation', CASE
      WHEN (SELECT current_delay_days FROM bottleneck LIMIT 1) > 1
        THEN 'Consider redistributing tasks or adding capacity to ' || (SELECT station_name FROM bottleneck LIMIT 1)
      WHEN (SELECT projected_delay_48h FROM bottleneck LIMIT 1) > 0.5
        THEN 'Monitor ' || (SELECT station_name FROM bottleneck LIMIT 1) || ' closely - projected delay in 48h'
      ELSE 'All stations operating within tolerance'
    END,
    'affected_orders', COALESCE(
      (SELECT affected_orders FROM affected a WHERE a.station_id = (SELECT station_id FROM bottleneck LIMIT 1)),
      '[]'::jsonb
    ),
    'all_stations', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'station_id', b.station_id,
          'station_name', b.station_name,
          'current_delay_days', b.current_delay_days,
          'projected_delay_48h', b.projected_delay_48h,
          'load_48h_hours', b.load_48h_hours,
          'capacity_per_day', b.capacity_hours_per_day
        )
      ) FROM bottleneck b
    )
  ) INTO v_result;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;


-- What-If Simulator: test adding a virtual order without persisting
CREATE OR REPLACE FUNCTION public.simulate_add_order(
  p_org_id uuid,
  p_tasks jsonb,
  p_desired_start date,
  p_due_date date
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
  v_feasible boolean := true;
  v_suggested_start date := p_desired_start;
  v_projected_end date;
  v_total_hours numeric := 0;
  v_max_end date := p_desired_start;
BEGIN
  -- p_tasks format: [{"station_id":"uuid","hours":8,"task_name":"Cut"}, ...]

  -- Calculate total hours and check each station
  WITH virtual_tasks AS (
    SELECT
      (t->>'station_id')::uuid AS station_id,
      (t->>'hours')::numeric AS hours,
      t->>'task_name' AS task_name
    FROM jsonb_array_elements(p_tasks) t
  ),
  station_impact AS (
    SELECT
      vt.station_id,
      wc.name AS station_name,
      vt.hours AS new_hours,
      vt.task_name,
      wc.capacity_hours_per_day,
      COALESCE(SUM(
        CASE WHEN wot.planned_start_at::date <= p_desired_start + CEIL(vt.hours / wc.capacity_hours_per_day)::int
          AND wot.planned_end_at::date >= p_desired_start
        THEN wot.estimated_duration_hours
          / GREATEST(1, (wot.planned_end_at::date - wot.planned_start_at::date + 1))
        ELSE 0 END
      ), 0) AS existing_daily_load,
      p_desired_start + CEIL(vt.hours / NULLIF(wc.capacity_hours_per_day, 0))::int AS projected_task_end
    FROM virtual_tasks vt
    JOIN public."WorkCenters" wc ON wc.id = vt.station_id
    LEFT JOIN public."WorkOrderTasks" wot
      ON wot.work_center_id = vt.station_id
      AND wot.organization_id = p_org_id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
    GROUP BY vt.station_id, wc.name, vt.hours, vt.task_name, wc.capacity_hours_per_day
  )
  SELECT
    jsonb_build_object(
      'feasible', bool_and(
        si.existing_daily_load + si.new_hours / GREATEST(1, CEIL(si.new_hours / si.capacity_hours_per_day))
        <= si.capacity_hours_per_day * 1.2
      ),
      'suggested_start', p_desired_start,
      'projected_end', MAX(si.projected_task_end),
      'meets_deadline', MAX(si.projected_task_end) <= p_due_date,
      'station_impacts', jsonb_agg(
        jsonb_build_object(
          'station_id', si.station_id,
          'station_name', si.station_name,
          'task_name', si.task_name,
          'new_hours', si.new_hours,
          'existing_daily_load', ROUND(si.existing_daily_load::numeric, 1),
          'capacity_per_day', si.capacity_hours_per_day,
          'projected_utilization_pct', ROUND(
            (si.existing_daily_load + si.new_hours / GREATEST(1, CEIL(si.new_hours / si.capacity_hours_per_day)))
            / NULLIF(si.capacity_hours_per_day, 0) * 100, 0
          ),
          'overloaded', (si.existing_daily_load + si.new_hours / GREATEST(1, CEIL(si.new_hours / si.capacity_hours_per_day)))
            > si.capacity_hours_per_day
        )
      ),
      'affected_orders', '[]'::jsonb
    )
  INTO v_result
  FROM station_impact si;

  RETURN COALESCE(v_result, jsonb_build_object(
    'feasible', true,
    'suggested_start', p_desired_start,
    'projected_end', p_desired_start,
    'meets_deadline', true,
    'station_impacts', '[]'::jsonb,
    'affected_orders', '[]'::jsonb
  ));
END;
$$;
