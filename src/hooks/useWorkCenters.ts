import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface WorkCenter {
  id: string;
  organization_id: string;
  code: string;
  name: string;
  description: string | null;
  sequence: number;
  routing_rule: Record<string, unknown>;
  is_active: boolean;
  capacity_hours_per_day: number;
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

export type WorkCenterInput = Pick<WorkCenter, 'code' | 'name' | 'sequence' | 'is_active'> & {
  description?: string | null;
  routing_rule?: Record<string, unknown>;
  capacity_hours_per_day?: number;
};

export function useWorkCenters() {
  const { activeOrganizationId } = useOrganizationContext();
  const [centers, setCenters] = useState<WorkCenter[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetch = useCallback(async () => {
    if (!activeOrganizationId) {
      setCenters([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('WorkCenters')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('sequence');
      if (err) throw new Error(err.message);
      setCenters(data ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error loading work centers');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => { fetch(); }, [fetch]);

  const upsert = useCallback(async (id: string | null, input: WorkCenterInput) => {
    if (!activeOrganizationId) throw new Error('No organization');
    if (id) {
      const { error: err } = await supabase
        .from('WorkCenters')
        .update({ ...input, updated_at: new Date().toISOString() })
        .eq('id', id)
        .eq('organization_id', activeOrganizationId);
      if (err) throw new Error(err.message);
    } else {
      const { error: err } = await supabase
        .from('WorkCenters')
        .insert({ ...input, organization_id: activeOrganizationId, routing_rule: input.routing_rule ?? {} });
      if (err) throw new Error(err.message);
    }
    await fetch();
  }, [activeOrganizationId, fetch]);

  const insertMany = useCallback(async (inputs: WorkCenterInput[]) => {
    if (!activeOrganizationId) throw new Error('No organization');
    if (inputs.length === 0) return;
    const rows = inputs.map((input) => ({
      ...input,
      organization_id: activeOrganizationId,
      routing_rule: input.routing_rule ?? {},
    }));
    const { error: err } = await supabase.from('WorkCenters').insert(rows);
    if (err) throw new Error(err.message);
    await fetch();
  }, [activeOrganizationId, fetch]);

  const remove = useCallback(async (id: string) => {
    if (!activeOrganizationId) return;
    const { error: err } = await supabase
      .from('WorkCenters')
      .update({ deleted: true })
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);
    if (err) throw new Error(err.message);
    await fetch();
  }, [activeOrganizationId, fetch]);

  return { centers, loading, error, upsert, insertMany, remove, refetch: fetch };
}
