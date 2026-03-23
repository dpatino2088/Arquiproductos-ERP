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

// Recover from dynamic import chunk load failures (stale chunks after deploy, cache issues)
const CHUNK_LOAD_KEY = 'adaptio_chunk_reload_attempted'
async function recoverFromChunkLoadFailure(message: string | null | undefined): Promise<void> {
  const msg = message || ''
  const isChunkFailure =
    msg.includes('Failed to fetch dynamically imported module') ||
    msg.includes('Importing a module script failed')

  if (!isChunkFailure || sessionStorage.getItem(CHUNK_LOAD_KEY)) return

  sessionStorage.setItem(CHUNK_LOAD_KEY, '1')
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
  void recoverFromChunkLoadFailure(ev?.message)
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
