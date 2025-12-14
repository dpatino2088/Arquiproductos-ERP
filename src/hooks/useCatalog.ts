import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { CatalogItem } from '../types/catalog';

export function useCatalogItems() {
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchItems() {
      if (!activeOrganizationId) {
        setLoading(false);
        setItems([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('CatalogItems')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CatalogItems:', queryError);
          }
          throw queryError;
        }

        setItems(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading catalog items';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogItems:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchItems();
  }, [activeOrganizationId, refreshTrigger]);

  return { items, loading, error, refetch };
}

export function useCreateCatalogItem() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const createItem = async (itemData: Omit<CatalogItem, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .insert({
          ...itemData,
          organization_id: activeOrganizationId,
        })
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsCreating(false);
    }
  };

  return { createItem, isCreating };
}

export function useUpdateCatalogItem() {
  const [isUpdating, setIsUpdating] = useState(false);

  const updateItem = async (id: string, itemData: Partial<CatalogItem>) => {
    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .update(itemData)
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateItem, isUpdating };
}

export function useDeleteCatalogItem() {
  const [isDeleting, setIsDeleting] = useState(false);

  const deleteItem = async (id: string) => {
    setIsDeleting(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItems')
        .update({ deleted: true })
        .eq('id', id)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsDeleting(false);
    }
  };

  return { deleteItem, isDeleting };
}

