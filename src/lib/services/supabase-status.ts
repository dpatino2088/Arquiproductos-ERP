import { create } from 'zustand';
import { supabaseHealthChecker, HealthStatus } from '../supabase/health-check';
import { supabaseCircuitBreaker, CircuitState } from '../supabase/circuit-breaker';
import { logger } from '../logger';

interface SupabaseStatusState {
  health: HealthStatus | null;
  circuitState: CircuitState;
  isDegraded: boolean;
  lastError: {
    message: string;
    timestamp: string;
    status?: number;
  } | null;
  
  // Actions
  updateHealth: (health: HealthStatus) => void;
  updateCircuitState: (state: CircuitState) => void;
  recordError: (error: any) => void;
  startMonitoring: () => void;
  stopMonitoring: () => void;
}

export const useSupabaseStatus = create<SupabaseStatusState>((set, get) => ({
  health: null,
  circuitState: CircuitState.CLOSED,
  isDegraded: false,
  lastError: null,

  updateHealth: (health: HealthStatus) => {
    const isDegraded = !health.healthy || health.responseTime > 5000;
    
    set({ 
      health, 
      isDegraded,
    });

    // Update circuit breaker state
    const stats = supabaseCircuitBreaker.getStats();
    set({ circuitState: stats.state });

    logger.debug('Supabase status updated', {
      healthy: health.healthy,
      responseTime: health.responseTime,
      isDegraded,
      circuitState: stats.state,
    });
  },

  updateCircuitState: (state: CircuitState) => {
    set({ circuitState: state });
  },

  recordError: (error: any) => {
    set({
      lastError: {
        message: error?.message || 'Unknown error',
        timestamp: new Date().toISOString(),
        status: error?.status,
      },
    });
  },

  startMonitoring: () => {
    // TEMPORALMENTE DESHABILITADO para reducir carga en Supabase
    // El proyecto está agotando recursos según el dashboard de Supabase
    // TODO: Re-habilitar cuando el proyecto tenga más recursos disponibles
    
    // Subscribe to health checks - DESHABILITADO
    // supabaseHealthChecker.subscribe((health) => {
    //   get().updateHealth(health);
    // });

    // Start periodic health checks - DESHABILITADO (era cada minuto)
    // Cuando se re-habilite, usar intervalo más largo: 300000 (5 minutos)
    // supabaseHealthChecker.startPeriodicCheck(300000); // Every 5 minutes

    logger.info('Supabase monitoring started (health checks disabled to reduce load on Supabase)');
  },

  stopMonitoring: () => {
    supabaseHealthChecker.stopPeriodicCheck();
    logger.info('Supabase monitoring stopped');
  },
}));

