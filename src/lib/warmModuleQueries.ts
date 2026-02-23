import type { QueryClient } from '@tanstack/react-query';

export type WarmQuerySpec = {
  queryKey: unknown[];
  queryFn: () => Promise<unknown>;
  /** If false, skip warming this query (e.g. no permission or tab not present). Default true. */
  enabled?: boolean;
};

/**
 * Warms module caches so tab switching is instant.
 * Calls ensureQueryData for each query where enabled !== false; does not refetch if data is already fresh.
 * Use on module mount and when scopeKey changes.
 */
export function warmModuleQueries(
  queryClient: QueryClient,
  specs: WarmQuerySpec[]
): void {
  specs.forEach(({ queryKey, queryFn, enabled }) => {
    if (enabled === false) return;
    queryClient.ensureQueryData({ queryKey, queryFn });
  });
}
