import { QueryClient } from '@tanstack/react-query';
import { logger } from './logger';
import { errorTracker } from './error-tracker';

/**
 * React Query Client Configuration
 * Optimized for performance and UX in production
 * 
 * Key optimizations:
 * - 10min staleTime: Reduce unnecessary refetches
 * - 30min gcTime: Keep data in cache longer
 * - No refetch on focus/reconnect: Better mobile performance
 * - Smart retry logic: Don't retry client errors (4xx)
 */
/** Keep previous data while fetching new data (no flash / empty list). Use in list queries. */
export const keepPreviousData = <T>(previousData: T | undefined) => previousData;

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error: Error & { status?: number }) => {
        // Don't retry on 4xx errors (client errors)
        if (error?.status && error.status >= 400 && error.status < 500) {
          return false;
        }
        // Retry once for other errors (5xx, network) — ERP: avoid long waits
        return failureCount < 1;
      },
      staleTime: 60 * 1000, // 1 minute - lists stay fresh
      gcTime: 10 * 60 * 1000, // 10 minutes - cache kept for tab switching
      refetchOnWindowFocus: false, // Critical for ERP: no refetch on tab focus
      refetchOnReconnect: false, // Avoid refetch on flaky WiFi
      refetchOnMount: false, // Rely on staleTime + invalidation; avoid phantom refetches
    },
    mutations: {
      retry: (failureCount, error: Error & { status?: number }) => {
        // Don't retry mutations on client errors
        if (error?.status && error.status >= 400 && error.status < 500) {
          return false;
        }
        // Retry once for server errors
        return failureCount < 1;
      },
      onError: (error: Error, variables: unknown, context: unknown) => {
        // Track mutation errors
        errorTracker.trackError(
          error instanceof Error ? error : new Error(String(error)),
          {
            type: 'mutation_error',
            variables,
            context,
          }
        );
      },
    },
  },
});

// Global error handler for queries
queryClient.setMutationDefaults(['*'], {
  onError: (error: Error) => {
    logger.error('Query mutation failed', error);
  },
});

// Global error handler for queries is handled in the individual hooks

// Query client event listeners for observability
queryClient.getQueryCache().subscribe((event) => {
  if (event.type === 'observerResultsUpdated') {
    const query = event.query;
    if (query.state.error) {
      logger.warn('Query error detected', {
        queryKey: query.queryKey,
        error: query.state.error,
      });
    }
  }
});

queryClient.getMutationCache().subscribe((event) => {
  if (event.type === 'updated') {
    const mutation = event.mutation;
    if (mutation.state.error) {
      logger.warn('Mutation error detected', {
        mutationKey: mutation.options.mutationKey,
        error: mutation.state.error,
      });
    }
  }
});
