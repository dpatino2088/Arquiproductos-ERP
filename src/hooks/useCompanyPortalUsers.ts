import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

/**
 * Portal User shape canónico para UI
 */
export interface CompanyPortalUser {
  id: string;
  company_id: string;
  company_name?: string | null; // Company name from Companies table
  user_id?: string | null;
  portal_user_email: string;
  portal_user_name?: string | null;
  portal_user_role?: 'member_manager' | 'member' | null; // Portal user role
  portal_user_status: 'draft' | 'invited' | 'active' | 'disabled';
  organization_id?: string | null;
  invited_at?: string | null;
  accepted_at?: string | null;
  deleted: boolean;
  created_at?: string;
  updated_at?: string;
  /** Raw DB columns (when select returns role/status instead of portal_user_*) */
  role?: string | null;
  status?: string | null;
  /** Optional display fields (from join or PortalUser compatibility) */
  contact_email?: string | null;
  contact_phone?: string | null;
  user_email?: string | null;
  user_name?: string | null;
  contact_id?: string | null;
  contact_name?: string | null;
  legacy?: {
    email?: string;
    status?: string;
  };
}

/**
 * Hook para gestionar CompanyPortalUsers con transición gradual a columnas explícitas
 * 
 * REGLA DE ORO:
 * - Leer: seleccionar explícitas + genéricas (safe select con fallback)
 * - Mostrar/editar: usar explícitas con fallback a genéricas
 * - Escribir (insert/update): SOLO columnas explícitas (nunca genéricas)
 * 
 * IMPORTANTE: CompanyPortalUsers pertenece a Companies (NO a Customers, NO a Organizations directamente)
 * Para filtrar por organization, se debe hacer join: Companies -> Organizations
 */
/**
 * Hook para gestionar CompanyPortalUsers
 * 
 * IMPORTANTE: Filtra por organization_id (via Companies join) Y opcionalmente por company_id
 * 
 * @param companyId - Opcional: si se proporciona, filtra solo por ese company_id específico
 */
export function useCompanyPortalUsers(companyId?: string | null) {
  const [users, setUsers] = useState<CompanyPortalUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  /**
   * Normalizar status a uno de: draft|invited|active|disabled
   */
  const normalizeStatus = useCallback((status: any): 'active' | 'disabled' => {
    const s = (status || '').toString().toLowerCase().trim();
    // Portal users only use 'active' or 'disabled'
    // Normalize legacy 'invited'/'draft' to 'active'
    if (s === 'active' || s === 'disabled') {
      return s;
    }
    // Legacy values: 'invited', 'draft', or anything else -> 'active'
    return 'active';
  }, []);

  /**
   * Safe select: intenta con explícitas + genéricas, fallback a solo explícitas si falla
   * IMPORTANTE: Filtra por organization_id via Companies join Y opcionalmente por company_id
   */
  const safeSelectPortalUsers = useCallback(async (orgId: string, filterCompanyId?: string | null) => {
    // Primera intento: explícitas + genéricas con join a Companies
    // IMPORTANT: Use 'role' column, not 'portal_user_role' (matches actual DB schema)
    const explicitAndGeneric = 'id, company_id, user_id, portal_user_email, portal_user_name, role, status, organization_id, email, invited_at, accepted_at, deleted, created_at, updated_at';
    
    try {
      // Intentar query con join a Companies para filtrar por organization_id y obtener company_name
      const { data, error: queryError } = await supabase
        .from('CompanyPortalUsers')
        .select(`
          ${explicitAndGeneric},
          Companies!CompanyPortalUsers_company_id_fkey (
            id,
            organization_id,
            company_name
          )
        `)
        .eq('Companies.organization_id', orgId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (queryError) {
        // Si falla por columna inexistente o por join, reintentar con filtro manual
        if (queryError.code === '42703' || queryError.message?.includes('does not exist') || queryError.message?.includes('column') || queryError.message?.includes('join')) {
          if (import.meta.env.DEV) {
            console.warn('[useCompanyPortalUsers] Generic columns or join failed, retrying with explicit columns only');
          }
          
          // Obtener companies de la org primero con company_name
          const { data: orgCompanies } = await supabase
            .from('Companies')
            .select('id, company_name')
            .eq('organization_id', orgId)
            .eq('deleted', false);

          let companyIds = (orgCompanies || []).map((c: { id: string }) => c.id);
          // Crear un mapa de company_id -> company_name para lookup
          const companyNameMap = new Map((orgCompanies || []).map((c: { id: string; company_name?: string }) => [c.id, c.company_name]));
          
          // Si se proporciona filterCompanyId, filtrar solo por ese company
          if (filterCompanyId) {
            if (!companyIds.includes(filterCompanyId)) {
              // Company no pertenece a esta organization
              if (import.meta.env.DEV) {
                console.warn('[useCompanyPortalUsers] Company', filterCompanyId, 'does not belong to organization', orgId);
              }
              return [];
            }
            companyIds = [filterCompanyId];
          }
          
          if (companyIds.length === 0) {
            return [];
          }

          // IMPORTANT: Use 'role' column, not 'portal_user_role' (matches actual DB schema)
          const explicitOnly = 'id, company_id, user_id, portal_user_email, portal_user_name, role, status, organization_id, invited_at, accepted_at, deleted, created_at, updated_at';
          
          if (import.meta.env.DEV) {
            console.log('[useCompanyPortalUsers] Fetching with explicit columns, including role');
          }
          const { data: retryData, error: retryError } = await supabase
            .from('CompanyPortalUsers')
            .select(explicitOnly)
            .in('company_id', companyIds)
            .eq('deleted', false)
            .order('created_at', { ascending: false });

          if (retryError) {
            throw retryError;
          }
          
          // Agregar company_name a cada row usando el mapa
          const dataWithCompanyName = (retryData || []).map((row: any) => ({
            ...row,
            Companies: {
              organization_id: orgId,
              company_name: companyNameMap.get(row.company_id) || null,
            },
          }));
          
          return dataWithCompanyName;
        }
        throw queryError;
      }
      // Si se proporciona filterCompanyId, filtrar los resultados
      let filteredData = data || [];
      if (filterCompanyId) {
        filteredData = filteredData.filter((row: any) => row.company_id === filterCompanyId);
      }
      
      return filteredData;
    } catch (err) {
      throw err;
    }
  }, []);

  /**
   * Mapear row a shape canónico CompanyPortalUser
   */
  const mapToPortalUser = useCallback((row: any): CompanyPortalUser => {
    const portal_user_email = (row.portal_user_email ?? row.email ?? '').toString().trim();
    const portal_user_status = normalizeStatus(row.portal_user_status ?? row.status ?? 'draft');

    return {
      id: row.id,
      company_id: row.company_id,
      company_name: row.Companies?.company_name || null, // Extract company_name from joined Companies
      user_id: row.user_id || null,
      portal_user_email,
      portal_user_name: row.portal_user_name || null,
      portal_user_role: (() => {
        // IMPORTANT: Use 'role' column from DB, not 'portal_user_role'
        const rawRole = row.role || row.portal_user_role; // Fallback for legacy data
        // Preserve exact role value from DB - don't normalize unless necessary
        if (rawRole === 'member_manager') {
          return 'member_manager' as const;
        }
        if (rawRole === 'member') {
          return 'member' as const;
        }
        // Only default to 'member' if role is truly empty/null/undefined
        if (!rawRole || rawRole === '' || rawRole === null) {
          return 'member' as const;
        }
        // For any other unexpected value, try to normalize
        const normalized = String(rawRole).toLowerCase().trim();
        if (normalized === 'member_manager' || normalized === 'manager') {
          return 'member_manager' as const;
        }
        // Default fallback
        return 'member' as const;
      })(),
      portal_user_status,
      organization_id: row.organization_id || (row.Companies?.organization_id || null),
      invited_at: row.invited_at || null,
      accepted_at: row.accepted_at || null,
      deleted: row.deleted || false,
      created_at: row.created_at || undefined,
      updated_at: row.updated_at || undefined,
      // Legacy raw solo si existen genéricas
      legacy: (row.email || row.status) ? {
        email: row.email || undefined,
        status: row.status || undefined,
      } : undefined,
    };
  }, [normalizeStatus]);

  /**
   * Fetch portal users (filtrados por organization via Companies)
   */
  const fetchUsers = useCallback(async () => {
    if (!activeOrganizationId) {
      setUsers([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);

      const data = await safeSelectPortalUsers(activeOrganizationId, companyId);
      const mapped = data.map(mapToPortalUser);
      
      // Warning si hay records sin company_id (solo en DEV)
      if (import.meta.env.DEV && mapped.length > 0) {
        const withoutCompanyId = mapped.filter((u: { company_id?: string }) => !u.company_id);
        if (withoutCompanyId.length > 0) {
          console.warn('[useCompanyPortalUsers] Found', withoutCompanyId.length, 'portal users without company_id:', withoutCompanyId.map((u: { id: string }) => u.id));
        }
      }

      if (import.meta.env.DEV) {
        console.log('[useCompanyPortalUsers] Fetched portal users:', {
          count: mapped.length,
          sample: mapped[0] ? {
            id: mapped[0].id,
            portal_user_name: mapped[0].portal_user_name,
            portal_user_role: mapped[0].portal_user_role,
            portal_user_status: mapped[0].portal_user_status,
          } : null,
        });
      }

      setUsers(mapped);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading portal users';
      console.error('[useCompanyPortalUsers] Error:', errorMessage, err);
      setError(errorMessage);
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeOrganizationId, companyId, safeSelectPortalUsers, mapToPortalUser]);

  /**
   * Refetch portal users
   */
  const refetch = useCallback(() => {
    if (import.meta.env.DEV) {
      console.log('[useCompanyPortalUsers] Refetching portal users...');
    }
    fetchUsers();
  }, [fetchUsers]);

  // Auto-fetch cuando cambia organization
  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  return {
    users,
    isLoading,
    error,
    fetchUsers,
    refetch,
  };
}
