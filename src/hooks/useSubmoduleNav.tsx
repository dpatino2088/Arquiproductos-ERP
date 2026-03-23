import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import { router } from '../lib/router';
import { canReadPath, usePermissions } from './usePermissions';

interface SubmoduleTab {
  id: string;
  label: string;
  href: string;
  icon?: React.ComponentType<{ className?: string }>;
  group?: string;
  matchPaths?: string[];
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

const SALES_LAST_PATHS_KEY = 'sales_submodule_last_paths';

function getSalesLastPaths(): Record<string, string> {
  try {
    const raw = sessionStorage.getItem(SALES_LAST_PATHS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, string>;
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch {
    return {};
  }
}

function setSalesLastPath(tabId: string, path: string): void {
  const prev = getSalesLastPaths();
  if (prev[tabId] === path) return;
  const next = { ...prev, [tabId]: path };
  sessionStorage.setItem(SALES_LAST_PATHS_KEY, JSON.stringify(next));
}

const SubmoduleNavContext = createContext<SubmoduleNavContextType | undefined>(undefined);

export function SubmoduleNavProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<SubmoduleNavState>(initialState);
  const { can, loading: permissionsLoading } = usePermissions();

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
    const visibleTabs = permissionsLoading
      ? tabs
      : tabs.filter((tab) => canReadPath(can, tab.href));
    
    // Extract the main module from the current path and from the tabs
    const currentModule = currentPath.split('/')[1];
    const tabsModule = visibleTabs[0]?.href.split('/')[1];
    
    // Only register if we're actually in the correct module
    // This prevents registering wrong submodules when navigating between modules
    if (!currentModule || !tabsModule) {
      // Invalid path or tabs, don't register
      return;
    }
    
    if (currentModule !== tabsModule) {
      // Don't register if the module doesn't match
      // This prevents Inventory tabs from showing in Manufacturing, etc.
      if (import.meta.env.DEV) {
        console.warn(`[useSubmoduleNav] Skipping registration: current module "${currentModule}" doesn't match tabs module "${tabsModule}"`);
      }
      return;
    }

    if (tabsModule === 'sales') {
      const matchingTab = visibleTabs.find(t => currentPath === t.href || currentPath.startsWith(t.href + '/'));
      if (matchingTab) setSalesLastPath(matchingTab.id, currentPath);
    }

    const tabMatchesPath = (tab: Omit<SubmoduleTab, 'isActive' | 'onClick'>, path: string) => {
      const paths = tab.matchPaths ?? [tab.href];
      return paths.some(p => path === p || path.startsWith(p + '/'));
    };

    const matchingTabs = visibleTabs.filter(tab => tabMatchesPath(tab, currentPath));
    const mostSpecificTab = matchingTabs.reduce((prev, current) => {
      const prevLen = Math.max(...(prev.matchPaths ?? [prev.href]).map(p => p.length));
      const curLen = Math.max(...(current.matchPaths ?? [current.href]).map(p => p.length));
      return curLen > prevLen ? current : prev;
    }, matchingTabs[0] || { href: '', id: '' });
    
    const processedTabs = visibleTabs.map(tab => ({
      ...tab,
      isActive: tab.id === mostSpecificTab.id && tabMatchesPath(tab, currentPath),
      onClick: () => { router.navigate(tab.href); },
    }));
    
    // Only update if tabs actually changed (compare by id and href)
    setState(prev => {
      // Check if tabs are the same
      const tabsChanged = 
        prev.tabs.length !== processedTabs.length ||
        prev.tabs.some((prevTab, index) => 
          prevTab.id !== processedTabs[index]?.id || 
          prevTab.href !== processedTabs[index]?.href
        );
      
      // Also check if we're switching modules
      const existingModule = prev.tabs[0]?.href.split('/')[1];
      const switchingModules = existingModule && existingModule !== currentModule;
      
      if (tabsChanged || switchingModules || prev.title !== title) {
        return { title, tabs: processedTabs, breadcrumbs: [] };
      }
      
      // If only active state changed, update just that
      const activeStateChanged = processedTabs.some((tab, index) => 
        tab.isActive !== prev.tabs[index]?.isActive
      );
      
      if (activeStateChanged) {
        return { ...prev, tabs: processedTabs };
      }
      
      // No changes needed
      return prev;
    });
  }, [can, permissionsLoading]);

  // Auto-update tab active states when route changes; persist Sales tab paths for "back to detail"
  React.useEffect(() => {
    const handleRouteChange = () => {
      const currentPath = window.location.pathname;
      
      if (state.tabs.length > 0) {
        const firstHref = state.tabs[0]?.href ?? '';
        if (firstHref.startsWith('/sales/')) {
          const matchingTab = state.tabs.find(
            tab => currentPath === tab.href || currentPath.startsWith(tab.href + '/')
          );
          if (matchingTab) setSalesLastPath(matchingTab.id, currentPath);
        }

        const matchPath = (tab: SubmoduleTab, path: string) => {
          const paths = tab.matchPaths ?? [tab.href];
          return paths.some(p => path === p || path.startsWith(p + '/'));
        };

        const matchingTabs = state.tabs.filter(tab => matchPath(tab, currentPath));
        const mostSpecificTab = matchingTabs.reduce((prev, current) => {
          const prevLen = Math.max(...(prev.matchPaths ?? [prev.href]).map(p => p.length));
          const curLen = Math.max(...(current.matchPaths ?? [current.href]).map(p => p.length));
          return curLen > prevLen ? current : prev;
        }, matchingTabs[0] || { href: '', id: '' });

        const updatedTabs = state.tabs.map(tab => ({
          ...tab,
          isActive: tab.id === mostSpecificTab.id && matchPath(tab, currentPath),
        }));
        
        // Only update if active state changed
        const hasChanged = updatedTabs.some((tab, index) => 
          tab.isActive !== state.tabs[index]?.isActive
        );
        
        if (hasChanged) {
          setState(prev => ({ ...prev, tabs: updatedTabs }));
        }
      }
    };

    // Listen for popstate events (browser back/forward)
    window.addEventListener('popstate', handleRouteChange);
    
    // Also check periodically for pathname changes (in case router doesn't trigger popstate)
    const interval = setInterval(handleRouteChange, 300);
    
    // Initial check
    handleRouteChange();
    
    return () => {
      window.removeEventListener('popstate', handleRouteChange);
      clearInterval(interval);
    };
  }, [state.tabs]);

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
    // Return default values instead of throwing error for better resilience
    // This allows components to work even if there's a timing issue with the provider
    return {
      title: '',
      tabs: [],
      breadcrumbs: [],
      setSubmoduleNav: () => {},
      setBreadcrumbs: () => {},
      clearSubmoduleNav: () => {},
      registerSubmodules: () => {}
    };
  }
  return context;
}
