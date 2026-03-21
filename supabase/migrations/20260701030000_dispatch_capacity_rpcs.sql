-- Dispatch Board RPC: tasks grouped by station, ordered by urgency
CREATE OR REPLACE FUNCTION public.get_dispatch_board(p_org_id uuid, p_days int DEFAULT 1)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
  v_end_date date := current_date + p_days;
  v_today date := current_date;
BEGIN
  WITH task_deps AS (
    SELECT
      td.work_order_task_id,
      bool_and(dep_task.status = 'completed') AS all_deps_completed
    FROM public."TaskDependencies" td
    JOIN public."WorkOrderTasks" dep_task ON dep_task.id = td.depends_on_task_id
    WHERE dep_task.deleted = false
    GROUP BY td.work_order_task_id
  ),
  tasks_with_urgency AS (
    SELECT
      wot.id AS task_id,
      wot.task_name,
      wot.work_center_id,
      wc.name AS station_name,
      wc.code AS station_code,
      wot.status AS task_status,
      wot.estimated_duration_hours,
      wot.planned_start_at,
      wot.planned_end_at,
      wot.manufacturing_order_id,
      mo.manufacturing_order_no AS mo_number,
      mo.product_name,
      mo.status AS mo_status,
      so.requested_delivery_date AS due_date,
      COALESCE(td.all_deps_completed, true) AS deps_ready,
      CASE
        WHEN so.requested_delivery_date IS NOT NULL AND v_today > so.requested_delivery_date THEN 'critical'
        WHEN so.requested_delivery_date IS NOT NULL AND (so.requested_delivery_date - v_today) <= 2 THEN 'at_risk'
        ELSE 'on_track'
      END AS urgency
    FROM public."WorkOrderTasks" wot
    JOIN public."WorkCenters" wc ON wc.id = wot.work_center_id
    JOIN public."ManufacturingOrders" mo ON mo.id = wot.manufacturing_order_id
    LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
    LEFT JOIN task_deps td ON td.work_order_task_id = wot.id
    WHERE wot.organization_id = p_org_id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
      AND mo.deleted = false
      AND mo.status NOT IN ('completed','delivered','cancelled')
      AND (
        wot.planned_start_at IS NULL
        OR wot.planned_start_at::date <= v_end_date
      )
  )
  SELECT jsonb_object_agg(
    station_group.station_id,
    station_group.tasks_arr
  ) INTO v_result
  FROM (
    SELECT
      twu.work_center_id AS station_id,
      jsonb_build_object(
        'station_name', MIN(twu.station_name),
        'station_code', MIN(twu.station_code),
        'tasks', jsonb_agg(
          jsonb_build_object(
            'task_id', twu.task_id,
            'task_name', twu.task_name,
            'task_status', twu.task_status,
            'hours', twu.estimated_duration_hours,
            'planned_start', twu.planned_start_at,
            'planned_end', twu.planned_end_at,
            'mo_id', twu.manufacturing_order_id,
            'mo_number', twu.mo_number,
            'product_name', twu.product_name,
            'due_date', twu.due_date,
            'urgency', twu.urgency,
            'deps_ready', twu.deps_ready
          ) ORDER BY
            CASE twu.urgency WHEN 'critical' THEN 1 WHEN 'at_risk' THEN 2 ELSE 3 END,
            twu.due_date NULLS LAST,
            twu.planned_start_at NULLS LAST
        )
      ) AS tasks_arr
    FROM tasks_with_urgency twu
    GROUP BY twu.work_center_id
  ) station_group;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;


-- Global Capacity RPC: hours per station per day
CREATE OR REPLACE FUNCTION public.get_global_capacity(
  p_org_id uuid,
  p_days int DEFAULT 7,
  p_from date DEFAULT current_date
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
  v_to date := p_from + p_days - 1;
BEGIN
  WITH date_series AS (
    SELECT d::date AS day_date
    FROM generate_series(p_from, v_to, '1 day'::interval) d
  ),
  station_day AS (
    SELECT
      wc.id AS station_id,
      wc.name AS station_name,
      wc.code AS station_code,
      ds.day_date,
      CASE EXTRACT(DOW FROM ds.day_date)
        WHEN 0 THEN 0
        WHEN 6 THEN 4
        ELSE wc.capacity_hours_per_day
      END AS capacity_hours,
      COALESCE(SUM(
        CASE WHEN wot.id IS NOT NULL
          AND wot.planned_start_at::date <= ds.day_date
          AND wot.planned_end_at::date >= ds.day_date
        THEN wot.estimated_duration_hours
          / GREATEST(1, (wot.planned_end_at::date - wot.planned_start_at::date + 1))
        ELSE 0 END
      ), 0) AS used_hours
    FROM public."WorkCenters" wc
    CROSS JOIN date_series ds
    LEFT JOIN public."WorkOrderTasks" wot
      ON wot.work_center_id = wc.id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
      AND wot.planned_start_at::date <= ds.day_date
      AND wot.planned_end_at::date >= ds.day_date
    WHERE wc.organization_id = p_org_id
      AND wc.deleted = false
      AND wc.is_active = true
    GROUP BY wc.id, wc.name, wc.code, wc.sequence, ds.day_date, wc.capacity_hours_per_day
    ORDER BY wc.sequence, ds.day_date
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'station_id', sd.station_id,
      'station_name', sd.station_name,
      'station_code', sd.station_code,
      'day', sd.day_date,
      'capacity_hours', sd.capacity_hours,
      'used_hours', ROUND(sd.used_hours::numeric, 1),
      'available_hours', GREATEST(0, sd.capacity_hours - sd.used_hours),
      'utilization_pct', CASE WHEN sd.capacity_hours > 0
        THEN ROUND(sd.used_hours / sd.capacity_hours * 100, 0)
        ELSE 0 END,
      'is_overloaded', sd.used_hours > sd.capacity_hours
    )
  ) INTO v_result
  FROM station_day sd;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;


-- Find Available Slot: next 14 days with available capacity for given hours
CREATE OR REPLACE FUNCTION public.find_available_slot(
  p_org_id uuid,
  p_station_id uuid,
  p_required_hours numeric
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH date_series AS (
    SELECT d::date AS day_date
    FROM generate_series(current_date, current_date + 13, '1 day'::interval) d
  ),
  day_load AS (
    SELECT
      ds.day_date,
      wc.capacity_hours_per_day,
      CASE EXTRACT(DOW FROM ds.day_date)
        WHEN 0 THEN 0
        WHEN 6 THEN 4
        ELSE wc.capacity_hours_per_day
      END AS capacity_hours,
      COALESCE(SUM(
        CASE WHEN wot.id IS NOT NULL
          AND wot.planned_start_at::date <= ds.day_date
          AND wot.planned_end_at::date >= ds.day_date
        THEN wot.estimated_duration_hours
          / GREATEST(1, (wot.planned_end_at::date - wot.planned_start_at::date + 1))
        ELSE 0 END
      ), 0) AS used_hours
    FROM public."WorkCenters" wc
    CROSS JOIN date_series ds
    LEFT JOIN public."WorkOrderTasks" wot
      ON wot.work_center_id = wc.id
      AND wot.deleted = false
      AND wot.status NOT IN ('completed','cancelled')
      AND wot.planned_start_at::date <= ds.day_date
      AND wot.planned_end_at::date >= ds.day_date
    WHERE wc.id = p_station_id
      AND wc.organization_id = p_org_id
    GROUP BY ds.day_date, wc.capacity_hours_per_day
    ORDER BY ds.day_date
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'date', dl.day_date,
      'available_hours', GREATEST(0, dl.capacity_hours - dl.used_hours),
      'capacity_hours', dl.capacity_hours,
      'used_hours', ROUND(dl.used_hours::numeric, 1),
      'utilization_after_pct', CASE WHEN dl.capacity_hours > 0
        THEN ROUND((dl.used_hours + p_required_hours) / dl.capacity_hours * 100, 0)
        ELSE 0 END,
      'fits', (dl.capacity_hours - dl.used_hours) >= p_required_hours
    )
  ) INTO v_result
  FROM day_load dl
  WHERE dl.capacity_hours > 0;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
