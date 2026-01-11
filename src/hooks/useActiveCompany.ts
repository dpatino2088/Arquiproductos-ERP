import { useState, useEffect, useCallback } from 'react';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useCompanies } from './useCompanies';

/**
 * Hook para manejar el company activo
 * 
 * TODO: Este hook necesita un selector de company en la UI.
 * Por ahora, usa el primer company disponible o null.
 * 
 * IMPORTANTE: En el futuro, se debe agregar:
 * - Un selector de company en el Layout/Header
 * - Persistencia en localStorage (similar a activeOrganizationId)
 * - Context para compartir activeCompanyId globalmente
 */
export function useActiveCompany() {
  const { activeOrganizationId } = useOrganizationContext();
  const { companies, isLoading: companiesLoading } = useCompanies();
  const [activeCompanyId, setActiveCompanyId] = useState<string | null>(null);

  // Auto-seleccionar primer company si hay uno disponible
  useEffect(() => {
    if (!companiesLoading && companies.length > 0 && !activeCompanyId) {
      const firstCompany = companies[0];
      if (firstCompany) {
        setActiveCompanyId(firstCompany.id);
        if (import.meta.env.DEV) {
          console.log('[useActiveCompany] Auto-selected first company:', firstCompany.id, firstCompany.company_name);
        }
      }
    } else if (companies.length === 0 && activeCompanyId) {
      // Si no hay companies, limpiar selección
      setActiveCompanyId(null);
    }
  }, [companies, companiesLoading, activeCompanyId]);

  const activeCompany = companies.find(c => c.id === activeCompanyId) || null;

  return {
    activeCompanyId,
    activeCompany,
    setActiveCompanyId,
    isLoading: companiesLoading,
    hasCompanies: companies.length > 0,
    companies,
  };
}
