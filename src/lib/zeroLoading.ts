import type { QueryClient } from '@tanstack/react-query';

const DEFAULT_COOLDOWN_MS = 20_000;

const lastWarmAt = new Map<string, number>();

export type WarmDetailOptions = { cooldownMs?: number };

export type WarmDetailSpec = {
  queryKey: unknown[];
  queryFn: () => Promise<unknown>;
  /** If false, skip warming. */
  enabled?: boolean;
  /** Unique id for cooldown (e.g. `${scopeKey}:${orderId}`). */
  warmId: string;
};

/**
 * Returns true if we are allowed to warm this id (cooldown elapsed or first time).
 * Uses in-memory Map keyed by warmId. Thread-safe per tab.
 */
export function shouldWarm(warmId: string, cooldownMs: number = DEFAULT_COOLDOWN_MS): boolean {
  const now = Date.now();
  const last = lastWarmAt.get(warmId);
  if (last == null) return true;
  return now - last >= cooldownMs;
}

/**
 * Warms detail cache only when:
 * - enabled !== false
 * - shouldWarm(warmId, cooldownMs)
 * - not already fetching that queryKey
 * Updates lastWarmAt on start so rapid repeats don't spam.
 */
export async function warmDetailIfNeeded(
  queryClient: QueryClient,
  spec: WarmDetailSpec,
  opts: WarmDetailOptions = {}
): Promise<void> {
  const cooldownMs = opts.cooldownMs ?? DEFAULT_COOLDOWN_MS;
  if (spec.enabled === false || !spec.warmId) return;
  if (!shouldWarm(spec.warmId, cooldownMs)) return;
  if (queryClient.getQueryState(spec.queryKey)?.status === 'pending') return;
  if ((queryClient.isFetching({ queryKey: spec.queryKey }) as number) > 0) return;

  lastWarmAt.set(spec.warmId, Date.now());

  try {
    await queryClient.ensureQueryData({ queryKey: spec.queryKey, queryFn: spec.queryFn });
  } catch {
    // Don't break UI; warm is best-effort.
  }
}
