import { ViewMode } from '../stores/ui-store';

// View mode color constants
export const VIEW_MODE_COLORS = {
  employee: {
    sidebar: {
      background: 'white',
      border: 'var(--gray-250)',
      textPrimary: 'var(--graphite-black-hex)',
      textSecondary: 'var(--gray-950)'
    },
    buttons: {
      active: {
        background: 'var(--gray-250)',
        color: 'var(--teal-800)',
        border: 'var(--teal-800)'
      },
      inactive: {
        color: 'var(--graphite-black-hex)'
      },
      hover: {
        background: 'var(--gray-250)'
      }
    }
  },
  manager: {
    sidebar: {
      background: 'var(--gray-950)',
      border: 'var(--gray-800)',
      textPrimary: 'var(--gray-300)',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: 'var(--gray-800)',
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: 'var(--gray-300)'
      },
      hover: {
        background: 'var(--gray-800)'
      }
    }
  },
  group: {
    sidebar: {
      background: 'var(--gray-950)',
      border: 'var(--gray-800)',
      textPrimary: 'var(--gray-300)',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: 'var(--gray-800)',
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: 'var(--gray-300)'
      },
      hover: {
        background: 'var(--gray-800)'
      }
    }
  },
  vap: {
    sidebar: {
      background: '#1b3556', // Navy-800
      border: '#1b3556',
      textPrimary: '#FFFFFF',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: '#10243d', // Navy-900
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: '#FFFFFF'
      },
      hover: {
        background: '#10243d'
      }
    }
  },
  rp: {
    sidebar: {
      background: '#134e4a', // Teal-900
      border: '#134e4a',
      textPrimary: '#FFFFFF',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: '#042f2e', // Teal-950
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: '#FFFFFF'
      },
      hover: {
        background: '#042f2e'
      }
    }
  },
  personal: {
    sidebar: {
      background: '#1b3556', // Navy-800 (same as VAP)
      border: '#1b3556',
      textPrimary: '#FFFFFF',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: '#10243d', // Navy-900 (same as VAP)
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: '#FFFFFF'
      },
      hover: {
        background: '#10243d'
      }
    }
  }
} as const;

// Utility functions for getting view mode styles
export const getViewModeColors = (viewMode: ViewMode) => {
  return VIEW_MODE_COLORS[viewMode];
};

export const getSidebarStyles = (viewMode: ViewMode) => {
  const colors = getViewModeColors(viewMode);
  return {
    backgroundColor: colors.sidebar.background,
    borderColor: colors.sidebar.border
  };
};

export const getButtonStyles = (viewMode: ViewMode, isActive: boolean) => {
  const colors = getViewModeColors(viewMode);
  
  if (isActive) {
    return {
      backgroundColor: colors.buttons.active.background,
      color: colors.buttons.active.color,
      borderLeft: `3px solid ${colors.buttons.active.border}`
    };
  }
  
  return {
    backgroundColor: 'transparent',
    color: colors.buttons.inactive.color,
    borderLeft: '3px solid transparent'
  };
};

export const getHoverStyles = (viewMode: ViewMode) => {
  const colors = getViewModeColors(viewMode);
  return {
    backgroundColor: colors.buttons.hover.background
  };
};

export const getTextStyles = (viewMode: ViewMode, isActive: boolean) => {
  const colors = getViewModeColors(viewMode);
  
  if (isActive) {
    return {
      color: colors.buttons.active.color
    };
  }
  
  return {
    color: colors.buttons.inactive.color
  };
};

export const getLogoTextColor = (viewMode: ViewMode) => {
  const colors = getViewModeColors(viewMode);
  return colors.sidebar.textSecondary;
};

// View mode cycling utility
const VIEW_MODE_CYCLE: ViewMode[] = ['employee', 'manager', 'group', 'vap', 'rp', 'personal'];

export const getNextViewMode = (currentMode: ViewMode): ViewMode => {
  const currentIndex = VIEW_MODE_CYCLE.indexOf(currentMode);
  const nextIndex = (currentIndex + 1) % VIEW_MODE_CYCLE.length;
  return VIEW_MODE_CYCLE[nextIndex];
};

// Settings URL mapping
const SETTINGS_URLS: Record<ViewMode, string> = {
  employee: '/org/cmp/employee/settings', // This might not be used, but for completeness
  manager: '/org/cmp/management/settings/company-settings',
  group: '/org/grp/settings',
  vap: '/org/vap/settings',
  rp: '/org/rp/settings',
  personal: '/me/settings'
};

export const getSettingsUrl = (viewMode: ViewMode): string => {
  return SETTINGS_URLS[viewMode];
};

// Dashboard URL mapping
const DASHBOARD_URLS: Record<ViewMode, string> = {
  employee: '/org/cmp/employee/dashboard',
  manager: '/org/cmp/management/dashboard',
  group: '/org/grp/dashboard',
  vap: '/org/vap/dashboard',
  rp: '/org/rp/dashboard',
  personal: '/me/dashboard'
};

export const getDashboardUrl = (viewMode: ViewMode): string => {
  return DASHBOARD_URLS[viewMode];
};

// View mode display names
const VIEW_MODE_LABELS: Record<ViewMode, string> = {
  employee: 'Employee View',
  manager: 'Management View',
  group: 'Group View',
  vap: 'VAP View',
  rp: 'RP View',
  personal: 'Personal View'
};

export const getViewModeLabel = (viewMode: ViewMode): string => {
  return VIEW_MODE_LABELS[viewMode];
};

// Common button props and event handlers
export const getNavigationButtonProps = (
  viewMode: ViewMode, 
  isActive: boolean, 
  onClick: () => void,
  additionalStyles?: React.CSSProperties
) => {
  const baseStyles = {
    fontSize: '14px',
    minHeight: '36px',
    padding: '12px 16px 12px 14px',
    ...getButtonStyles(viewMode, isActive),
    ...additionalStyles
  };

  const hoverStyles = getHoverStyles(viewMode);

  return {
    onClick,
    className: "flex items-center font-normal transition-colors group relative w-full",
    style: baseStyles,
    onMouseEnter: (e: React.MouseEvent<HTMLButtonElement>) => {
      if (!isActive) {
        e.currentTarget.style.backgroundColor = hoverStyles.backgroundColor;
      }
    },
    onMouseLeave: (e: React.MouseEvent<HTMLButtonElement>) => {
      if (!isActive) {
        e.currentTarget.style.backgroundColor = 'transparent';
      }
    }
  };
};

// Dashboard button specific props
export const getDashboardButtonProps = (
  viewMode: ViewMode,
  isActive: boolean,
  onClick: () => void
) => {
  return getNavigationButtonProps(viewMode, isActive, onClick, {
    minHeight: '40px',
    padding: '11px 16px 11px 14px'
  });
};

// Settings button utility - handles the repetitive settingsUrl logic
export const getSettingsButtonState = (
  viewMode: ViewMode,
  isNavItemActive: (name: string, href: string) => boolean
) => {
  const settingsUrl = getSettingsUrl(viewMode);
  const isActive = isNavItemActive('Settings', settingsUrl);
  
  return {
    settingsUrl,
    isActive,
    buttonProps: getNavigationButtonProps(viewMode, isActive, () => {})
  };
};

// Common icon container styles - used in multiple places
export const getIconContainerStyle = (): React.CSSProperties => ({
  width: '18px', 
  height: '18px', 
  flexShrink: 0
});

// Common text span styles for navigation items
export const getNavTextSpanStyle = (isCollapsed: boolean): React.CSSProperties => ({
  opacity: isCollapsed ? 0 : 1,
  pointerEvents: isCollapsed ? 'none' : 'auto'
});

// Navigation item icon and text structure - reduces repetition
export const createNavItemContent = (
  icon: React.ComponentType<{ style?: React.CSSProperties }>,
  text: string,
  isCollapsed: boolean,
  additionalTextStyles?: React.CSSProperties
) => {
  const Icon = icon;
  return (
    <>
      <div className="flex items-center justify-center" style={getIconContainerStyle()}>
        <Icon style={getIconContainerStyle()} />
      </div>
      <span 
        className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
        style={{
          ...getNavTextSpanStyle(isCollapsed),
          ...additionalTextStyles
        }}
      >
        {text}
      </span>
    </>
  );
};

// Collapse/Expand button content - handles conditional icon logic
export const createCollapseExpandContent = (
  isCollapsed: boolean,
  ChevronRight: React.ComponentType<{ style?: React.CSSProperties }>,
  ChevronLeft: React.ComponentType<{ style?: React.CSSProperties }>,
  expandedText: string = 'Expand',
  collapsedText: string = 'Collapse'
) => {
  return (
    <>
      <div className="flex items-center justify-center" style={getIconContainerStyle()}>
        {isCollapsed ? (
          <ChevronRight style={getIconContainerStyle()} />
        ) : (
          <ChevronLeft style={getIconContainerStyle()} />
        )}
      </div>
      <span 
        className="absolute left-12 transition-opacity duration-300 whitespace-nowrap"
        style={getNavTextSpanStyle(isCollapsed)}
      >
        {isCollapsed ? expandedText : collapsedText}
      </span>
    </>
  );
};
