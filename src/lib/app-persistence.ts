/**
 * Global App Persistence Manager
 * 
 * Handles visibility changes and state persistence across tabs
 */

type VisibilityChangeHandler = () => void;

class AppPersistence {
  private visibilityHandlers: Set<VisibilityChangeHandler> = new Set();
  private isVisible = true;

  constructor() {
    if (typeof document !== 'undefined') {
      // Handle visibility change
      document.addEventListener('visibilitychange', () => {
        const wasVisible = this.isVisible;
        this.isVisible = document.visibilityState === 'visible';
        
        if (import.meta.env.DEV) {
          console.log(`[AppPersistence] Tab ${this.isVisible ? 'visible' : 'hidden'}`);
        }
        
        // Only notify when becoming visible (not when hiding)
        if (!wasVisible && this.isVisible) {
          this.notifyVisibilityChange();
        }
      });
    }
  }

  /**
   * Register a callback to run when tab becomes visible again
   * Use this to refresh stale data or reconnect websockets
   */
  onVisibilityChange(handler: VisibilityChangeHandler): () => void {
    this.visibilityHandlers.add(handler);
    
    // Return unsubscribe function
    return () => {
      this.visibilityHandlers.delete(handler);
    };
  }

  private notifyVisibilityChange(): void {
    this.visibilityHandlers.forEach(handler => {
      try {
        handler();
      } catch (err) {
        console.error('[AppPersistence] Visibility handler error:', err);
      }
    });
  }

  getIsVisible(): boolean {
    return this.isVisible;
  }
}

// Global singleton
export const appPersistence = new AppPersistence();

/**
 * React hook to run effect when tab becomes visible
 * 
 * @example
 * useOnVisibilityChange(() => {
 *   // Refresh data when user returns to tab
 *   refetchData();
 * });
 */
export function useOnVisibilityChange(callback: () => void) {
  React.useEffect(() => {
    return appPersistence.onVisibilityChange(callback);
  }, [callback]);
}

import React from 'react';
