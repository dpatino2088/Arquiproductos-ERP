# Sistema de Manejo de Errores de Supabase - Implementación Completa

## 📋 Resumen

Se ha implementado un sistema completo y profesional para manejar errores de Supabase (500, 502, 503) siguiendo las mejores prácticas de desarrollo full stack.

## 🏗️ Arquitectura Implementada

### 1. **Circuit Breaker Pattern** (`src/lib/supabase/circuit-breaker.ts`)
- **Propósito**: Evita hacer peticiones cuando el servicio está caído
- **Estados**: CLOSED (normal), OPEN (fallando), HALF_OPEN (probando recuperación)
- **Configuración**:
  - 5 fallos antes de abrir el circuito
  - 2 éxitos antes de cerrar
  - 30 segundos antes de intentar recuperación

### 2. **Retry Handler con Backoff Exponencial** (`src/lib/supabase/retry-handler.ts`)
- **Propósito**: Reintentos inteligentes para errores temporales
- **Características**:
  - Backoff exponencial con jitter
  - Solo reintenta errores 500, 502, 503, 504, 429
  - Máximo 3 reintentos
  - Delay máximo de 10 segundos

### 3. **Health Check** (`src/lib/supabase/health-check.ts`)
- **Propósito**: Monitoreo continuo del estado de Supabase
- **Características**:
  - Verificación cada 60 segundos
  - Mide tiempo de respuesta
  - Sistema de suscripciones para notificar cambios
  - Cliente mínimo para evitar dependencias circulares

### 4. **Estado Centralizado** (`src/lib/services/supabase-status.ts`)
- **Propósito**: Store Zustand para compartir estado del servicio
- **Información almacenada**:
  - Estado de salud actual
  - Estado del circuit breaker
  - Último error registrado
  - Indicador de degradación

### 5. **Cliente Mejorado** (`src/lib/supabase/client.ts`)
- **Propósito**: Cliente Supabase con interceptors y wrappers
- **Características**:
  - Interceptor de fetch para capturar errores
  - Wrappers con circuit breaker y retry
  - Logging automático de errores
  - Métodos `getSession()` y `getUser()` mejorados

### 6. **Hook y Componente UI** (`src/hooks/useSupabaseHealth.ts`)
- **Propósito**: Integración con React para mostrar estado
- **Componentes**:
  - `useSupabaseHealth()`: Hook para acceder al estado
  - `SupabaseStatusBanner`: Banner visual de estado

## 🔄 Flujo de Funcionamiento

```
1. Usuario hace petición
   ↓
2. Interceptor captura la petición
   ↓
3. Circuit Breaker verifica estado
   ├─ OPEN → Rechaza inmediatamente
   ├─ HALF_OPEN → Permite con precaución
   └─ CLOSED → Continúa
   ↓
4. Retry Handler ejecuta con backoff
   ↓
5. Si falla → Actualiza Circuit Breaker
   ↓
6. Health Check monitorea continuamente
   ↓
7. UI muestra banner si hay problemas
```

## 📁 Archivos Creados/Modificados

### Nuevos Archivos:
- `src/lib/supabase/circuit-breaker.ts`
- `src/lib/supabase/retry-handler.ts`
- `src/lib/supabase/health-check.ts`
- `src/lib/supabase/client.ts` (reemplaza `supabase.ts`)
- `src/lib/services/supabase-status.ts`
- `src/hooks/useSupabaseHealth.ts`

### Archivos Modificados:
- `src/App.tsx` - Integración del banner y monitoreo
- `src/stores/auth-store.ts` - Actualización de importación
- Todos los archivos que importaban `supabase` - Actualizados a `supabase/client`

## 🎯 Características Clave

### ✅ Resiliencia
- Circuit breaker previene cascadas de fallos
- Retry inteligente solo para errores recuperables
- Health check continuo para detección temprana

### ✅ Observabilidad
- Logging estructurado con timestamps
- Métricas de tiempo de respuesta
- Tracking de errores con contexto

### ✅ Experiencia de Usuario
- Banner visual cuando hay problemas
- Mensajes claros según el tipo de error
- No bloquea la aplicación completamente

### ✅ Performance
- Health check ligero (solo getSession)
- Retry con backoff evita sobrecarga
- Circuit breaker reduce peticiones innecesarias

## 🔧 Configuración

### Variables de Entorno Requeridas:
```env
VITE_SUPABASE_URL=tu-url-de-supabase
VITE_SUPABASE_ANON_KEY=tu-clave-publica
```

### Ajustes de Circuit Breaker:
Editar `src/lib/supabase/circuit-breaker.ts`:
```typescript
export const supabaseCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,        // Cambiar según necesidades
  successThreshold: 2,         // Cambiar según necesidades
  timeout: 5000,               // Cambiar según necesidades
  resetTimeout: 30000,         // Cambiar según necesidades
});
```

### Ajustes de Retry:
Editar `src/lib/supabase/retry-handler.ts`:
```typescript
const DEFAULT_CONFIG: RetryConfig = {
  maxRetries: 3,               // Cambiar según necesidades
  baseDelay: 1000,             // Cambiar según necesidades
  maxDelay: 10000,             // Cambiar según necesidades
  // ...
};
```

### Ajustes de Health Check:
Editar `src/lib/services/supabase-status.ts`:
```typescript
supabaseHealthChecker.startPeriodicCheck(60000); // Cambiar intervalo
```

## 📊 Monitoreo

### Logs Estructurados:
- Todos los errores incluyen timestamp
- Contexto completo (URL, status, duración)
- Niveles: debug, info, warn, error

### Métricas Disponibles:
- Tiempo de respuesta de Supabase
- Estado del circuit breaker
- Número de fallos totales
- Estado de salud actual

## 🚀 Uso

### En Componentes React:
```typescript
import { useSupabaseHealth } from '../hooks/useSupabaseHealth';

function MyComponent() {
  const { isHealthy, responseTime, circuitState } = useSupabaseHealth();
  
  if (!isHealthy) {
    return <div>Servicio no disponible</div>;
  }
  
  return <div>Tiempo de respuesta: {responseTime}ms</div>;
}
```

### En Stores/Actions:
```typescript
import { supabase } from '../lib/supabase/client';
import { useSupabaseStatus } from '../lib/services/supabase-status';

// El cliente ya tiene retry y circuit breaker integrados
const { data, error } = await supabase.auth.getSession();

// Registrar errores manualmente si es necesario
if (error) {
  useSupabaseStatus.getState().recordError(error);
}
```

## 🔍 Debugging

### Ver Estado del Circuit Breaker:
```typescript
import { supabaseCircuitBreaker } from './lib/supabase/circuit-breaker';

console.log(supabaseCircuitBreaker.getStats());
```

### Ver Último Health Check:
```typescript
import { supabaseHealthChecker } from './lib/supabase/health-check';

console.log(supabaseHealthChecker.getLastStatus());
```

### Ver Estado Completo:
```typescript
import { useSupabaseStatus } from './lib/services/supabase-status';

const state = useSupabaseStatus.getState();
console.log({
  health: state.health,
  circuitState: state.circuitState,
  isDegraded: state.isDegraded,
  lastError: state.lastError,
});
```

## ⚠️ Notas Importantes

1. **Importaciones**: Todos los archivos ahora deben importar desde `'../lib/supabase/client'` en lugar de `'../lib/supabase'`

2. **Health Check**: Usa un cliente separado para evitar dependencias circulares

3. **Circuit Breaker**: Se reinicia automáticamente, pero puede resetearse manualmente si es necesario

4. **Banner**: Solo se muestra cuando hay problemas, no bloquea la UI

5. **Performance**: El sistema está optimizado para no impactar el rendimiento normal

## 🎓 Mejores Prácticas Aplicadas

- ✅ **Separation of Concerns**: Cada módulo tiene una responsabilidad clara
- ✅ **Single Responsibility**: Cada clase/función hace una cosa
- ✅ **DRY**: Código reutilizable y sin duplicación
- ✅ **Observability**: Logging y métricas completas
- ✅ **User Experience**: Feedback visual sin bloquear
- ✅ **Resilience**: Múltiples capas de protección
- ✅ **Performance**: Optimizado para no impactar rendimiento

## 📝 Próximos Pasos Opcionales

1. **Métricas Avanzadas**: Integrar con servicios de monitoreo (Sentry, Datadog, etc.)
2. **Alertas**: Notificaciones cuando el servicio está caído por mucho tiempo
3. **Fallbacks**: Cache local para operaciones críticas
4. **Dashboard**: Panel de administración para ver estado en tiempo real
5. **Tests**: Unit tests para circuit breaker y retry handler

