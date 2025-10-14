import React from 'react';

export type ViewMode = 'employee' | 'manager' | 'group';

// View mode color constants
export const VIEW_MODE_COLORS = {
  employee: {
    sidebar: {
      background: 'var(--gray-250)',
      border: 'var(--gray-300)',
      textPrimary: 'var(--graphite-black-hex)',
      textSecondary: 'var(--gray-950)'
    },
    buttons: {
      active: {
        background: 'white',
        color: 'var(--teal-700)',
        border: 'var(--teal-700)'
      },
      inactive: {
        color: 'var(--graphite-black-hex)'
      },
      hover: {
        background: 'white'
      }
    }
  },
  manager: {
    sidebar: {
      background: 'var(--navy-700)',
      border: 'var(--navy-600)',
      textPrimary: 'var(--gray-300)',
      textSecondary: 'var(--gray-100)'
    },
    buttons: {
      active: {
        background: 'var(--navy-800)',
        color: 'var(--teal-500)',
        border: 'var(--teal-500)'
      },
      inactive: {
        color: 'var(--gray-300)'
      },
      hover: {
        background: 'var(--navy-800)'
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
const VIEW_MODE_CYCLE: ViewMode[] = ['employee', 'manager', 'group'];

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
};

export const getSettingsUrl = (viewMode: ViewMode): string => {
  return SETTINGS_URLS[viewMode];
};

// Dashboard URL mapping
const DASHBOARD_URLS: Record<ViewMode, string> = {
  employee: '/org/cmp/employee/dashboard',
  manager: '/org/cmp/management/dashboard',
  group: '/org/grp/dashboard',
};

export const getDashboardUrl = (viewMode: ViewMode): string => {
  return DASHBOARD_URLS[viewMode];
};

// View mode display names
const VIEW_MODE_LABELS: Record<ViewMode, string> = {
  employee: 'Employee View',
  manager: 'Management View',
  group: 'Group View',
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
    },
    onKeyDown: (e: React.KeyboardEvent<HTMLButtonElement>) => {
      // Enhanced keyboard support
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick();
      }
    },
    // Enhanced accessibility attributes
    'aria-current': isActive ? 'page' : undefined,
    tabIndex: 0
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
