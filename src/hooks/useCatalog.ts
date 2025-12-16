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

// Hook para cargar CatalogCollections
export interface CatalogCollection {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  description?: string | null;
  active: boolean;
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useCatalogCollections() {
  const [collections, setCollections] = useState<CatalogCollection[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCollections() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCollections([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('CatalogCollections')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CatalogCollections:', queryError);
          }
          throw queryError;
        }

        setCollections(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading collections';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogCollections:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchCollections();
  }, [activeOrganizationId, refreshTrigger]);

  return { collections, loading, error, refetch };
}

// Hook para cargar CatalogVariants
export interface CatalogVariant {
  id: string;
  organization_id: string;
  collection_id: string;
  name: string;
  code?: string | null;
  color_name?: string | null;
  active: boolean;
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useCatalogVariants(collectionId?: string) {
  const [variants, setVariants] = useState<CatalogVariant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchVariants() {
      if (!activeOrganizationId) {
        setLoading(false);
        setVariants([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        let query = supabase
          .from('CatalogVariants')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (collectionId) {
          query = query.eq('collection_id', collectionId);
        }

        const { data, error: queryError } = await query;

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching CatalogVariants:', queryError);
          }
          throw queryError;
        }

        setVariants(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading variants';
        if (import.meta.env.DEV) {
          console.error('Error fetching CatalogVariants:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchVariants();
  }, [activeOrganizationId, collectionId, refreshTrigger]);

  return { variants, loading, error, refetch };
}

// Hook para cargar Manufacturers
export interface Manufacturer {
  id: string;
  organization_id: string;
  name: string;
  code?: string | null;
  notes?: string | null;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useManufacturers() {
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchManufacturers() {
      if (!activeOrganizationId) {
        setLoading(false);
        setManufacturers([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('Manufacturers')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Manufacturers:', queryError);
          }
          throw queryError;
        }

        setManufacturers(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading manufacturers';
        if (import.meta.env.DEV) {
          console.error('Error fetching Manufacturers:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchManufacturers();
  }, [activeOrganizationId, refreshTrigger]);

  return { manufacturers, loading, error, refetch };
}

// Hook para cargar Operating Drives desde CatalogItems
// Operating Drives son CatalogItems con item_type='component' o 'accessory'
// y metadata que indica que son operating drives
export interface OperatingDrive {
  id: string;
  name: string;
  code?: string;
  manufacturer?: string;
  system?: 'manual' | 'motorized';
  sku: string;
  metadata?: any;
}

export function useOperatingDrives() {
  const [drives, setDrives] = useState<OperatingDrive[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  useEffect(() => {
    async function fetchDrives() {
      if (!activeOrganizationId) {
        setLoading(false);
        setDrives([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Buscar CatalogItems que sean operating drives
        // Pueden ser item_type='component' o 'accessory' con metadata.operatingDrive=true
        // O podemos buscar por category o metadata específico
        // Nota: item_type puede no existir en el esquema actual, usar metadata como fallback
        let query = supabase
          .from('CatalogItems')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('active', true);
        
        // Intentar filtrar por item_type si existe, sino usar metadata
        // Por ahora, obtener todos los items activos y filtrar después
        const { data, error: queryError } = await query.order('name', { ascending: true });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.error('Error fetching Operating Drives:', queryError);
          }
          throw queryError;
        }

        // Filtrar y mapear items que sean operating drives
        // Por ahora, asumimos que todos los components/accessories pueden ser operating drives
        // O podemos usar metadata para identificar específicamente
        const operatingDrives: OperatingDrive[] = (data || [])
          .filter((item: any) => {
            // Filtrar por metadata si existe, o incluir todos los components/accessories
            const metadata = item.metadata || {};
            const itemType = item.item_type || metadata.item_type_inferred;
            return metadata.operatingDrive === true || 
                   metadata.category === 'Motors' || 
                   metadata.category === 'Controls' ||
                   itemType === 'component' ||
                   itemType === 'accessory'; // Incluir components y accessories
          })
          .map((item: any) => ({
            id: item.id,
            name: item.name,
            code: item.sku,
            manufacturer: item.metadata?.manufacturer || item.metadata?.category,
            system: item.metadata?.system,
            sku: item.sku,
            metadata: item.metadata,
          }));

        setDrives(operatingDrives);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading operating drives';
        if (import.meta.env.DEV) {
          console.error('Error fetching Operating Drives:', err);
        }
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchDrives();
  }, [activeOrganizationId]);

  return { drives, loading, error };
}

// ====================================================
// Manufacturers CRUD Hooks
// ====================================================

export function useManufacturersCRUD() {
  const { manufacturers, loading, error, refetch } = useManufacturers();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createManufacturer = async (data: Omit<Manufacturer, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('Manufacturers')
        .insert({ ...data, organization_id: activeOrganizationId })
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateManufacturer = async (id: string, data: Partial<Manufacturer>) => {
    setIsUpdating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('Manufacturers')
        .update(data)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteManufacturer = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('Manufacturers')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    manufacturers,
    loading,
    error,
    refetch,
    createManufacturer,
    updateManufacturer,
    deleteManufacturer,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// ItemCategories CRUD Hooks
// ====================================================

export interface ItemCategory {
  id: string;
  organization_id: string;
  parent_id?: string | null;
  name: string;
  code?: string | null;
  sort_order: number;
  deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at?: string | null;
}

export function useItemCategories() {
  const [categories, setCategories] = useState<ItemCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCategories() {
      if (!activeOrganizationId) {
        setLoading(false);
        setCategories([]);
        return;
      }

      try {
        setLoading(true);
        const { data, error: err } = await supabase
          .from('ItemCategories')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('sort_order', { ascending: true })
          .order('name', { ascending: true });

        if (err) throw err;
        setCategories(data || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error loading categories');
      } finally {
        setLoading(false);
      }
    }

    fetchCategories();
  }, [activeOrganizationId, refreshTrigger]);

  return { categories, loading, error, refetch };
}

export function useItemCategoriesCRUD() {
  const { categories, loading, error, refetch } = useItemCategories();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createCategory = async (data: Omit<ItemCategory, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('ItemCategories')
        .insert({ ...data, organization_id: activeOrganizationId })
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateCategory = async (id: string, data: Partial<ItemCategory>) => {
    setIsUpdating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('ItemCategories')
        .update(data)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCategory = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('ItemCategories')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    categories,
    loading,
    error,
    refetch,
    createCategory,
    updateCategory,
    deleteCategory,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// CatalogCollections CRUD Hooks
// ====================================================

export function useCatalogCollectionsCRUD() {
  const { collections, loading, error, refetch } = useCatalogCollections();
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createCollection = async (data: Omit<CatalogCollection, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('CatalogCollections')
        .insert({ ...data, organization_id: activeOrganizationId })
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateCollection = async (id: string, data: Partial<CatalogCollection>) => {
    setIsUpdating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('CatalogCollections')
        .update(data)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteCollection = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('CatalogCollections')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    collections,
    loading,
    error,
    refetch,
    createCollection,
    updateCollection,
    deleteCollection,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

// ====================================================
// CatalogVariants CRUD Hooks
// ====================================================

export function useCatalogVariantsCRUD(collectionId?: string) {
  const { variants, loading, error, refetch } = useCatalogVariants(collectionId);
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const createVariant = async (data: Omit<CatalogVariant, 'id' | 'organization_id' | 'created_at' | 'updated_at' | 'deleted' | 'archived'>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    if (!data.collection_id) throw new Error('Collection ID is required');
    setIsCreating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('CatalogVariants')
        .insert({ ...data, organization_id: activeOrganizationId })
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsCreating(false);
    }
  };

  const updateVariant = async (id: string, data: Partial<CatalogVariant>) => {
    setIsUpdating(true);
    try {
      const { data: result, error: err } = await supabase
        .from('CatalogVariants')
        .update(data)
        .eq('id', id)
        .select()
        .single();
      if (err) throw err;
      refetch();
      return result;
    } finally {
      setIsUpdating(false);
    }
  };

  const deleteVariant = async (id: string) => {
    setIsDeleting(true);
    try {
      const { error: err } = await supabase
        .from('CatalogVariants')
        .update({ deleted: true })
        .eq('id', id);
      if (err) throw err;
      refetch();
    } finally {
      setIsDeleting(false);
    }
  };

  return {
    variants,
    loading,
    error,
    refetch,
    createVariant,
    updateVariant,
    deleteVariant,
    isCreating,
    isUpdating,
    isDeleting,
  };
}

