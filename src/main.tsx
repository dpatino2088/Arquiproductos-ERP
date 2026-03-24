/// <reference types="vite/client" />
// ✅ CRITICAL: Import logger FIRST to override console methods before React uses them
import './lib/logger' // This overrides console.error/warn/log to prevent TypeError
// ✅ CRITICAL: Import supabase client SECOND to ensure fetch interceptor is active before any other code
import './lib/supabase/client' // This sets up the fetch interceptor that blocks telemetry requests

import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import './styles/global.css'
import App from './App'
import { queryClient } from './lib/query-client'
import { performanceMonitor } from './lib/performance'
import { logger } from './lib/logger'
import './lib/error-tracker' // Initialize error tracking
import './lib/trusted-types' // Initialize Trusted Types
import './lib/service-worker' // Initialize Service Worker
// ⚠️ RUM monitoring disabled to prevent TypeError crash (will fix later)
// import './lib/rum-monitoring'
import './lib/performance-budgets' // Initialize performance budgets
import { useAuthStore } from './stores/auth-store'
import { OrganizationProvider } from './context/OrganizationContext'
import { ActingAsProvider } from './context/ActingAsContext'
import { PermissionProvider } from './context/PermissionContext'

// Initialize performance monitoring
performanceMonitor.init()

// Initialize RUM monitoring and set user context
const _unsubscribe = useAuthStore.subscribe(
  (state) => state.user
)

// Log application startup
logger.info('Application starting up', {
  environment: import.meta.env.MODE,
  version: import.meta.env.VITE_APP_VERSION || '1.0.0',
})

// Recover from dynamic import chunk load failures (stale chunks after deploy, cache issues).
// Keep retries bounded, but do not permanently block recovery for the rest of the session.
const CHUNK_RECOVERY_STATE_KEY = 'adaptio_chunk_recovery_state'
const CHUNK_RECOVERY_MAX_ATTEMPTS = 2
const CHUNK_RECOVERY_WINDOW_MS = 2 * 60 * 1000

function isChunkLoadFailureText(text: string): boolean {
  const msg = text.toLowerCase()
  return (
    msg.includes('failed to fetch dynamically imported module') ||
    msg.includes('error loading dynamically imported module') ||
    msg.includes('importing a module script failed') ||
    msg.includes('loading chunk') ||
    msg.includes('chunkloaderror') ||
    msg.includes('/assets/') && msg.includes('.js')
  )
}

function getChunkRecoveryState(): { attempts: number; lastAt: number } {
  try {
    const raw = sessionStorage.getItem(CHUNK_RECOVERY_STATE_KEY)
    if (!raw) return { attempts: 0, lastAt: 0 }
    const parsed = JSON.parse(raw) as { attempts?: number; lastAt?: number }
    return {
      attempts: Number(parsed.attempts ?? 0),
      lastAt: Number(parsed.lastAt ?? 0),
    }
  } catch {
    return { attempts: 0, lastAt: 0 }
  }
}

function setChunkRecoveryState(next: { attempts: number; lastAt: number }): void {
  try {
    sessionStorage.setItem(CHUNK_RECOVERY_STATE_KEY, JSON.stringify(next))
  } catch {
    // no-op
  }
}

async function recoverFromChunkLoadFailure(
  message: string | null | undefined,
  extraContext?: string | null | undefined
): Promise<void> {
  const msg = `${message || ''} ${extraContext || ''}`.trim()
  if (!isChunkLoadFailureText(msg)) return

  const now = Date.now()
  const current = getChunkRecoveryState()
  const inWindow = now - current.lastAt <= CHUNK_RECOVERY_WINDOW_MS
  const attempts = inWindow ? current.attempts : 0
  if (attempts >= CHUNK_RECOVERY_MAX_ATTEMPTS) return

  setChunkRecoveryState({ attempts: attempts + 1, lastAt: now })
  try {
    // Clear stale SW/caches so new deploy chunks can be fetched.
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations()
      await Promise.all(regs.map((r) => r.unregister()))
    }
    if ('caches' in window) {
      const cacheNames = await caches.keys()
      await Promise.all(cacheNames.map((name) => caches.delete(name)))
    }
  } catch {
    // Best-effort recovery; continue with reload.
  }
  const url = new URL(window.location.href)
  url.searchParams.set('__chunk_recover', String(Date.now()))
  window.location.replace(url.toString())
}

window.addEventListener('error', (ev: ErrorEvent) => {
  void recoverFromChunkLoadFailure(ev?.message, ev?.filename)
})

window.addEventListener('unhandledrejection', (ev: PromiseRejectionEvent) => {
  const reason = ev?.reason
  const reasonMessage =
    typeof reason === 'string'
      ? reason
      : reason?.message || String(reason ?? '')
  void recoverFromChunkLoadFailure(reasonMessage)
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <OrganizationProvider>
        <ActingAsProvider>
          <PermissionProvider>
            <App />
          <ReactQueryDevtools initialIsOpen={false} />
          </PermissionProvider>
        </ActingAsProvider>
      </OrganizationProvider>
    </QueryClientProvider>
  </React.StrictMode>
)
