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
import { recoverFromChunkLoadFailure } from './lib/chunk-recovery'
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
// Shared helper lives in lib/chunk-recovery so the ErrorBoundary can reuse it.
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

// Vite's official event when a dynamically imported module fails to preload.
// This is the most reliable signal for stale chunks after a new deploy.
window.addEventListener('vite:preloadError', (ev: Event) => {
  const payload = (ev as Event & { payload?: unknown }).payload
  const message =
    payload instanceof Error
      ? payload.message
      : typeof payload === 'string'
        ? payload
        : String((payload as { message?: string })?.message ?? 'vite preload error')
  void recoverFromChunkLoadFailure(message, '/assets/.js')
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
