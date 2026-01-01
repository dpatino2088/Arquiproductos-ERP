import React, { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import { router } from '../lib/router';

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
    
    // Extract the main module from the current path and from the tabs
    const currentModule = currentPath.split('/')[1];
    const tabsModule = tabs[0]?.href.split('/')[1];
    
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
    
    // Process tabs with active state
    // First, find the most specific matching tab (longest href that matches)
    const matchingTabs = tabs.filter(tab => 
      currentPath === tab.href || currentPath.startsWith(tab.href + '/')
    );
    const mostSpecificTab = matchingTabs.reduce((prev, current) => 
      current.href.length > prev.href.length ? current : prev, 
      matchingTabs[0] || { href: '', id: '' }
    );
    
    const processedTabs = tabs.map(tab => ({
      ...tab,
      // Only mark as active if it's the most specific match
      isActive: tab.id === mostSpecificTab.id && (currentPath === tab.href || currentPath.startsWith(tab.href + '/')),
      onClick: () => {
        // Use router.navigate instead of manual pushState
        router.navigate(tab.href);
      }
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
  }, []);

  // Auto-update tab active states when route changes
  React.useEffect(() => {
    const handleRouteChange = () => {
      const currentPath = window.location.pathname;
      
      // Update active state of tabs based on current path
      if (state.tabs.length > 0) {
        // Find the most specific matching tab (longest href that matches)
        const matchingTabs = state.tabs.filter(tab => 
          currentPath === tab.href || currentPath.startsWith(tab.href + '/')
        );
        const mostSpecificTab = matchingTabs.reduce((prev, current) => 
          current.href.length > prev.href.length ? current : prev, 
          matchingTabs[0] || { href: '', id: '' }
        );
        
        const updatedTabs = state.tabs.map(tab => ({
          ...tab,
          // Only mark as active if it's the most specific match
          isActive: tab.id === mostSpecificTab.id && (currentPath === tab.href || currentPath.startsWith(tab.href + '/'))
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
