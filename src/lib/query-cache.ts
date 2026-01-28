import React from 'react';

/**
 * Global Query Cache for Supabase
 * 
 * Prevents unnecessary refetches and persists data across tab switches.
 * Implements stale-while-revalidate pattern.
 */

interface CacheEntry<T> {
  data: T;
  timestamp: number;
  staleTime: number; // ms until data is considered stale
  cacheTime: number; // ms until data is garbage collected
}

interface CacheOptions {
  staleTime?: number; // Default 5 minutes
  cacheTime?: number; // Default 30 minutes
  persist?: boolean; // Persist to sessionStorage
}

class QueryCache {
  private cache = new Map<string, CacheEntry<any>>();
  private persistKeys = new Set<string>();

  constructor() {
    // Restore from sessionStorage on init
    this.restoreFromStorage();
    
    // Cleanup stale entries every minute
    setInterval(() => this.cleanup(), 60000);
    
    // Persist to storage before unload
    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', () => this.persistToStorage());
    }
  }

  private getCacheKey(key: string | string[]): string {
    return Array.isArray(key) ? key.join(':') : key;
  }

  get<T>(key: string | string[]): T | null {
    const cacheKey = this.getCacheKey(key);
    const entry = this.cache.get(cacheKey);
    
    if (!entry) return null;
    
    const now = Date.now();
    
    // Check if data is expired (past cacheTime)
    if (now - entry.timestamp > entry.cacheTime) {
      this.cache.delete(cacheKey);
      this.persistKeys.delete(cacheKey);
      return null;
    }
    
    return entry.data;
  }

  isStale(key: string | string[]): boolean {
    const cacheKey = this.getCacheKey(key);
    const entry = this.cache.get(cacheKey);
    
    if (!entry) return true;
    
    const now = Date.now();
    return now - entry.timestamp > entry.staleTime;
  }

  set<T>(
    key: string | string[], 
    data: T, 
    options: CacheOptions = {}
  ): void {
    const cacheKey = this.getCacheKey(key);
    const {
      staleTime = 5 * 60 * 1000, // 5 minutes default
      cacheTime = 30 * 60 * 1000, // 30 minutes default
      persist = false,
    } = options;

    this.cache.set(cacheKey, {
      data,
      timestamp: Date.now(),
      staleTime,
      cacheTime,
    });

    if (persist) {
      this.persistKeys.add(cacheKey);
    }

    if (import.meta.env.DEV) {
      console.log(`[QueryCache] SET: ${cacheKey}`, {
        staleTime: `${staleTime / 1000}s`,
        cacheTime: `${cacheTime / 1000}s`,
        persist,
        dataSize: JSON.stringify(data).length,
      });
    }
  }

  invalidate(key: string | string[]): void {
    const cacheKey = this.getCacheKey(key);
    this.cache.delete(cacheKey);
    this.persistKeys.delete(cacheKey);
    
    if (import.meta.env.DEV) {
      console.log(`[QueryCache] INVALIDATE: ${cacheKey}`);
    }
  }

  invalidatePattern(pattern: string): void {
    const keysToDelete: string[] = [];
    
    for (const key of this.cache.keys()) {
      if (key.includes(pattern)) {
        keysToDelete.push(key);
      }
    }
    
    keysToDelete.forEach(key => {
      this.cache.delete(key);
      this.persistKeys.delete(key);
    });
    
    if (import.meta.env.DEV && keysToDelete.length > 0) {
      console.log(`[QueryCache] INVALIDATE PATTERN: ${pattern}`, {
        keysInvalidated: keysToDelete.length,
      });
    }
  }

  clear(): void {
    this.cache.clear();
    this.persistKeys.clear();
    
    if (typeof window !== 'undefined') {
      try {
        window.sessionStorage.removeItem('queryCache');
      } catch (err) {
        console.warn('[QueryCache] Failed to clear sessionStorage', err);
      }
    }
    
    if (import.meta.env.DEV) {
      console.log('[QueryCache] CLEAR: All cache cleared');
    }
  }

  private cleanup(): void {
    const now = Date.now();
    const keysToDelete: string[] = [];
    
    for (const [key, entry] of this.cache.entries()) {
      if (now - entry.timestamp > entry.cacheTime) {
        keysToDelete.push(key);
      }
    }
    
    keysToDelete.forEach(key => {
      this.cache.delete(key);
      this.persistKeys.delete(key);
    });
    
    if (import.meta.env.DEV && keysToDelete.length > 0) {
      console.log(`[QueryCache] CLEANUP: Removed ${keysToDelete.length} expired entries`);
    }
  }

  private persistToStorage(): void {
    if (typeof window === 'undefined' || this.persistKeys.size === 0) return;
    
    try {
      const toPersist: Record<string, CacheEntry<any>> = {};
      
      for (const key of this.persistKeys) {
        const entry = this.cache.get(key);
        if (entry) {
          toPersist[key] = entry;
        }
      }
      
      window.sessionStorage.setItem('queryCache', JSON.stringify(toPersist));
      
      if (import.meta.env.DEV) {
        console.log(`[QueryCache] PERSIST: Saved ${Object.keys(toPersist).length} entries to sessionStorage`);
      }
    } catch (err) {
      console.warn('[QueryCache] Failed to persist to sessionStorage', err);
    }
  }

  private restoreFromStorage(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const raw = window.sessionStorage.getItem('queryCache');
      if (!raw) return;
      
      const persisted = JSON.parse(raw) as Record<string, CacheEntry<any>>;
      const now = Date.now();
      let restoredCount = 0;
      
      for (const [key, entry] of Object.entries(persisted)) {
        // Only restore if not expired
        if (now - entry.timestamp <= entry.cacheTime) {
          this.cache.set(key, entry);
          this.persistKeys.add(key);
          restoredCount++;
        }
      }
      
      if (import.meta.env.DEV && restoredCount > 0) {
        console.log(`[QueryCache] RESTORE: Loaded ${restoredCount} entries from sessionStorage`);
      }
    } catch (err) {
      console.warn('[QueryCache] Failed to restore from sessionStorage', err);
    }
  }
}

// Global singleton instance
export const queryCache = new QueryCache();

/**
 * React hook to use cached queries
 * 
 * @example
 * const { data, loading, refetch } = useCachedQuery(
 *   ['templates', orgId, productTypeId],
 *   async () => fetchTemplates(orgId, productTypeId),
 *   { staleTime: 5 * 60 * 1000, persist: true }
 * );
 */
export function useCachedQuery<T>(
  key: string | string[],
  queryFn: () => Promise<T>,
  options: CacheOptions & { enabled?: boolean } = {}
) {
  const { enabled = true, ...cacheOptions } = options;
  const [data, setData] = React.useState<T | null>(() => queryCache.get<T>(key));
  const [loading, setLoading] = React.useState(!data);
  const [error, setError] = React.useState<Error | null>(null);
  const mountedRef = React.useRef(true);

  const fetchData = React.useCallback(async (forceRefetch = false) => {
    if (!enabled) {
      setLoading(false);
      return;
    }

    try {
      // Check cache first
      const cached = queryCache.get<T>(key);
      const isStale = queryCache.isStale(key);
      
      if (cached && !forceRefetch) {
        // Use cached data immediately
        if (mountedRef.current) {
          setData(cached);
          setLoading(false);
        }
        
        // If stale, refetch in background
        if (isStale) {
          const fresh = await queryFn();
          queryCache.set(key, fresh, cacheOptions);
          
          if (mountedRef.current) {
            setData(fresh);
          }
        }
        
        return;
      }
      
      // No cache or force refetch - fetch fresh data
      if (mountedRef.current) {
        setLoading(true);
      }
      
      const fresh = await queryFn();
      queryCache.set(key, fresh, cacheOptions);
      
      if (mountedRef.current) {
        setData(fresh);
        setError(null);
      }
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err));
      
      if (mountedRef.current) {
        setError(error);
      }
      
      console.error('[useCachedQuery] Error:', error);
    } finally {
      if (mountedRef.current) {
        setLoading(false);
      }
    }
  }, [key, queryFn, enabled, cacheOptions]);

  React.useEffect(() => {
    mountedRef.current = true;
    fetchData();
    
    return () => {
      mountedRef.current = false;
    };
  }, [fetchData]);

  const refetch = React.useCallback(() => {
    return fetchData(true);
  }, [fetchData]);

  return { data, loading, error, refetch };
}

import React from 'react';
