/**
 * Hook para cargar BOMTemplateSlots (PADRES) de un template
 * 
 * Este hook reemplaza useBOMComponents para el nuevo sistema PADRE-HIJO
 */

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface BOMTemplateSlot {
  id: string;
  organization_id: string;
  bom_template_id: string;
  item_role: string;
  required: boolean;
  catalog_item_id: string | null;
  qty: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
  // Join con CatalogItems
    catalog_item?: {
    id: string;
    sku: string;
    name: string;
    unit_of_measure?: string;
    item_role?: string;
    color?: string | null;
    cost_exw?: number | null;
  } | null;
}

export function useBOMTemplateSlots(bomTemplateId: string | null) {
  const [slots, setSlots] = useState<BOMTemplateSlot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    if (!bomTemplateId || !activeOrganizationId) {
      setSlots([]);
      setLoading(false);
      setError(null);
      return;
    }

    let isMounted = true;

    const fetchSlots = async () => {
      try {
        setLoading(true);
        setError(null);

        const { data, error: fetchError } = await supabase
          .from('BOMTemplateSlots')
          .select(`
            id,
            organization_id,
            bom_template_id,
            item_role,
            required,
            catalog_item_id,
            qty,
            notes,
            created_at,
            updated_at,
            catalog_item:catalog_item_id (
              id,
              sku,
              name,
              unit_of_measure,
              item_role,
              color,
              cost_exw
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('bom_template_id', bomTemplateId)
          .order('item_role', { ascending: true });

        if (fetchError) {
          console.error('[useBOMTemplateSlots] Error:', fetchError);
          throw new Error(fetchError.message);
        }

        if (isMounted) {
          setSlots(data || []);
        }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : String(err);
        console.error('[useBOMTemplateSlots] Error loading slots:', errorMsg);
        if (isMounted) {
          setError(errorMsg);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchSlots();

    return () => {
      isMounted = false;
    };
  }, [bomTemplateId, activeOrganizationId]);

  return { slots, loading, error };
}
