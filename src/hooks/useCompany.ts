import { useEffect } from 'react';
import { useCompanyStore } from '../stores/company-store';
import { useAuth } from './useAuth';

export const useCompany = () => {
  const { user } = useAuth();
  const {
    currentCompany,
    currentCompanyUser,
    availableCompanies,
    isLoading,
    error,
    loadUserCompanies,
    switchCompany,
    clearCompanies,
  } = useCompanyStore();

  // Load companies when user is authenticated
  useEffect(() => {
    if (user?.id) {
      loadUserCompanies(user.id);
    } else {
      clearCompanies();
    }
  }, [user?.id, loadUserCompanies, clearCompanies]);

  return {
    currentCompany,
    currentCompanyUser,
    availableCompanies,
    isLoading,
    error,
    switchCompany,
    loadUserCompanies,
    canSwitchCompany: availableCompanies.length > 1,
  };
};

