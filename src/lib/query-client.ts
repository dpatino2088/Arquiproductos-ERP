import { QueryClient } from '@tanstack/react-query';
import { logger } from './logger';
import { errorTracker } from './error-tracker';

// Create and configure React Query client
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error: any) => {
        // Don't retry on 4xx errors (client errors)
        if (error?.status >= 400 && error?.status < 500) {
          return false;
        }
        // Retry up to 2 times for other errors
        return failureCount < 2;
      },
      staleTime: 5 * 60 * 1000, // 5 minutes
      gcTime: 10 * 60 * 1000, // 10 minutes (previously cacheTime)
      refetchOnWindowFocus: false,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: (failureCount, error: any) => {
        // Don't retry mutations on client errors
        if (error?.status >= 400 && error?.status < 500) {
          return false;
        }
        // Retry once for server errors
        return failureCount < 1;
      },
      onError: (error: any, variables: any, context: any) => {
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
  onError: (error: any) => {
    logger.error('Query mutation failed', error);
  },
});

// Add global query error handler
queryClient.setQueryDefaults(['*'], {
  onError: (error: any) => {
    logger.error('Query failed', error);
    errorTracker.trackError(
      error instanceof Error ? error : new Error(String(error)),
      {
        type: 'query_error',
      }
    );
  },
});

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
