import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';

interface SubmoduleTab {
  id: string;
  label: string;
  href: string;
  icon?: React.ComponentType<{ className?: string }>;
  isActive?: boolean;
  onClick?: () => void;
}

interface Breadcrumb {
  label: string;
  href?: string;
}

interface SubmoduleNavState {
  title: string;
  tabs: SubmoduleTab[];
  breadcrumbs: Breadcrumb[];
}

interface SubmoduleNavContextType {
  title: string;
  tabs: SubmoduleTab[];
  breadcrumbs: Breadcrumb[];
  setSubmoduleNav: (title: string, tabs: SubmoduleTab[]) => void;
  setBreadcrumbs: (breadcrumbs: Breadcrumb[]) => void;
  clearSubmoduleNav: () => void;
  registerSubmodules: (title: string, tabs: Omit<SubmoduleTab, 'isActive' | 'onClick'>[]) => void;
}

const initialState: SubmoduleNavState = {
  title: '',
  tabs: [],
  breadcrumbs: []
};

const SubmoduleNavContext = createContext<SubmoduleNavContextType | undefined>(undefined);

export function SubmoduleNavProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<SubmoduleNavState>(initialState);

  const setSubmoduleNav = useCallback((title: string, tabs: SubmoduleTab[]) => {
    setState({ title, tabs, breadcrumbs: [] });
  }, []);

  const setBreadcrumbs = useCallback((breadcrumbs: Breadcrumb[]) => {
    setState(prev => ({ ...prev, breadcrumbs }));
  }, []);

  const clearSubmoduleNav = useCallback(() => {
    setState(initialState);
  }, []);

  const registerSubmodules = useCallback((title: string, tabs: Omit<SubmoduleTab, 'isActive' | 'onClick'>[]) => {
    const currentPath = window.location.pathname;
    const processedTabs = tabs.map(tab => ({
      ...tab,
      isActive: currentPath === tab.href,
      onClick: () => {
        window.history.pushState({}, '', tab.href);
        window.dispatchEvent(new PopStateEvent('popstate'));
      }
    }));
    setState({ title, tabs: processedTabs, breadcrumbs: [] });
  }, []);

  const value = {
    title: state.title,
    tabs: state.tabs,
    breadcrumbs: state.breadcrumbs,
    setSubmoduleNav,
    setBreadcrumbs,
    clearSubmoduleNav,
    registerSubmodules
  };

  return (
    <SubmoduleNavContext.Provider value={value}>
      {children}
    </SubmoduleNavContext.Provider>
  );
}

export function useSubmoduleNav() {
  const context = useContext(SubmoduleNavContext);
  if (context === undefined) {
    throw new Error('useSubmoduleNav must be used within a SubmoduleNavProvider');
  }
  return context;
}
