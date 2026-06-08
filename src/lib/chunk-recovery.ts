// Recover from dynamic import chunk load failures (stale chunks after deploy,
// SW/cache issues). Shared by the global listeners in main.tsx and the
// ErrorBoundary (which catches React.lazy import rejections before they ever
// surface as an `unhandledrejection`).

const CHUNK_RECOVERY_STATE_KEY = 'adaptio_chunk_recovery_state';
const CHUNK_RECOVERY_MAX_ATTEMPTS = 2;
const CHUNK_RECOVERY_WINDOW_MS = 2 * 60 * 1000;

export function isChunkLoadFailureText(text: string): boolean {
  const msg = (text || '').toLowerCase();
  return (
    msg.includes('failed to fetch dynamically imported module') ||
    msg.includes('error loading dynamically imported module') ||
    msg.includes('importing a module script failed') ||
    msg.includes('loading chunk') ||
    msg.includes('chunkloaderror') ||
    (msg.includes('/assets/') && msg.includes('.js'))
  );
}

function getChunkRecoveryState(): { attempts: number; lastAt: number } {
  try {
    const raw = sessionStorage.getItem(CHUNK_RECOVERY_STATE_KEY);
    if (!raw) return { attempts: 0, lastAt: 0 };
    const parsed = JSON.parse(raw) as { attempts?: number; lastAt?: number };
    return {
      attempts: Number(parsed.attempts ?? 0),
      lastAt: Number(parsed.lastAt ?? 0),
    };
  } catch {
    return { attempts: 0, lastAt: 0 };
  }
}

function setChunkRecoveryState(next: { attempts: number; lastAt: number }): void {
  try {
    sessionStorage.setItem(CHUNK_RECOVERY_STATE_KEY, JSON.stringify(next));
  } catch {
    // no-op
  }
}

/**
 * Attempts to recover from a chunk load failure by clearing stale SW/caches and
 * reloading. Returns true when a reload has been scheduled (caller should show
 * an "updating" state), false when the message is not a chunk failure or the
 * bounded retry budget is exhausted.
 */
export async function recoverFromChunkLoadFailure(
  message: string | null | undefined,
  extraContext?: string | null | undefined
): Promise<boolean> {
  const msg = `${message || ''} ${extraContext || ''}`.trim();
  if (!isChunkLoadFailureText(msg)) return false;

  const now = Date.now();
  const current = getChunkRecoveryState();
  const inWindow = now - current.lastAt <= CHUNK_RECOVERY_WINDOW_MS;
  const attempts = inWindow ? current.attempts : 0;
  if (attempts >= CHUNK_RECOVERY_MAX_ATTEMPTS) return false;

  setChunkRecoveryState({ attempts: attempts + 1, lastAt: now });
  try {
    // Clear stale SW/caches so new deploy chunks can be fetched.
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map((r) => r.unregister()));
    }
    if ('caches' in window) {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((name) => caches.delete(name)));
    }
  } catch {
    // Best-effort recovery; continue with reload.
  }
  const url = new URL(window.location.href);
  url.searchParams.set('__chunk_recover', String(Date.now()));
  window.location.replace(url.toString());
  return true;
}
