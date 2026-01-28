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

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <OrganizationProvider>
        <PermissionProvider>
          <App />
          <ReactQueryDevtools initialIsOpen={false} />
        </PermissionProvider>
      </OrganizationProvider>
    </QueryClientProvider>
  </React.StrictMode>
)
