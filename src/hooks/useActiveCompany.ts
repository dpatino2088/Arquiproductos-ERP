import { useActiveDealer } from './useActiveDealer';

/**
 * Alias for useActiveDealer (Company → Dealer rename).
 * Returns the same shape with legacy names for backward compatibility.
 */
export function useActiveCompany() {
  const {
    activeDealerId,
    activeDealer,
    setActiveDealerId,
    isLoading,
    hasDealers,
    dealers,
  } = useActiveDealer();

  return {
    activeCompanyId: activeDealerId,
    activeCompany: activeDealer,
    setActiveCompanyId: setActiveDealerId,
    isLoading,
    hasCompanies: hasDealers,
    companies: dealers,
  };
}
