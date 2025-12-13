import { useEffect } from 'react';
import { useSupabaseStatus } from '../lib/services/supabase-status';
import { AlertCircle, CheckCircle, XCircle, Loader } from 'lucide-react';

export function useSupabaseHealth() {
  const { health, circuitState, isDegraded, startMonitoring, stopMonitoring } = useSupabaseStatus();

  useEffect(() => {
    startMonitoring();
    return () => stopMonitoring();
  }, [startMonitoring, stopMonitoring]);

  return {
    health,
    circuitState,
    isDegraded,
    isHealthy: health?.healthy ?? true,
    responseTime: health?.responseTime ?? 0,
  };
}

// Componente de banner de estado
export function SupabaseStatusBanner() {
  const { health, isDegraded, circuitState } = useSupabaseHealth();

  if (!health || health.healthy) {
    return null;
  }

  const getStatusInfo = () => {
    if (circuitState === 'OPEN') {
      return {
        icon: XCircle,
        message: 'El servicio de autenticación no está disponible. Por favor, intenta más tarde.',
        className: 'bg-red-50 border-red-200 text-red-800',
      };
    }

    if (isDegraded) {
      return {
        icon: AlertCircle,
        message: 'El servicio está experimentando problemas. Algunas funciones pueden ser lentas.',
        className: 'bg-yellow-50 border-yellow-200 text-yellow-800',
      };
    }

    return {
      icon: Loader,
      message: 'Verificando estado del servicio...',
      className: 'bg-blue-50 border-blue-200 text-blue-800',
    };
  };

  const statusInfo = getStatusInfo();
  const Icon = statusInfo.icon;

  return (
    <div className={`border-l-4 ${statusInfo.className} p-4 mb-4`}>
      <div className="flex items-start">
        <Icon className="h-5 w-5 mr-3 flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <p className="text-sm font-medium">{statusInfo.message}</p>
          {health.responseTime > 0 && (
            <p className="text-xs mt-1 opacity-75">
              Tiempo de respuesta: {health.responseTime}ms
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
