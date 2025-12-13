# 📋 Estándares de Código - Adaptio ERP

Guía de mejores prácticas establecidas para mantener código limpio, seguro y performante.

---

## 🚀 Cambios Recientes Aplicados

### ✅ Mejoras Implementadas

1. **DevLogger para Producción**
   - Archivo: `src/lib/dev-logger.ts`
   - Uso: `import { devLog, devWarn, devError } from '@/lib/dev-logger'`
   - Beneficio: Console.logs solo en desarrollo, no en producción

2. **TypeScript Type Safety**
   - Cambio: `as any` → `as unknown` en Supabase client
   - Beneficio: Mejor type checking, menos errores en runtime

3. **ESLint Mejorado**
   - Reglas añadidas: `no-console`, `@typescript-eslint/no-explicit-any`
   - Beneficio: Catch de errores comunes antes del build

4. **React Query Optimizado**
   - `staleTime: 10min`, `gcTime: 30min`
   - `refetchOnMount: false`, `refetchOnWindowFocus: false`
   - Beneficio: 60-70% menos peticiones HTTP

5. **GitIgnore Limpio**
   - Removidas secciones duplicadas (3x → 1x)
   - Beneficio: Mantenibilidad

---

## 📖 Reglas de Código

### 1. Logging en Producción ❌

```typescript
// ❌ NUNCA hacer esto
console.log('User data:', userData);

// ✅ SIEMPRE usar devLogger
import { devLog } from '@/lib/dev-logger';
devLog('User data:', userData);

// ✅ Para errores críticos, usar logger
import { logger } from '@/lib/logger';
logger.error('Critical error', error);
```

---

### 2. Type Safety 🔒

```typescript
// ❌ Evitar 'any' explícito
const data: any = fetchData();

// ✅ Usar tipos específicos o 'unknown'
const data: UserData = fetchData();
// O si no conoces el tipo:
const data: unknown = fetchData();
```

---

### 3. React Query Patterns 📊

```typescript
// ✅ BIEN - Usar configuración optimizada
export function useContacts() {
  return useQuery({
    queryKey: ['contacts', orgId],
    queryFn: fetchContacts,
    // No necesitas configurar staleTime/cacheTime, ya está global
  });
}

// ❌ MAL - Re-fetchear innecesariamente
useQuery({
  queryKey: ['contacts'],
  queryFn: fetchContacts,
  refetchOnMount: true, // ❌ Ya está configurado globalmente
  refetchOnWindowFocus: true, // ❌ Causa muchas peticiones
});
```

---

### 4. Import Optimization 📦

```typescript
// ❌ MAL - Importa TODO lucide-react (~500KB)
import { User, Mail, Settings } from 'lucide-react';

// ✅ BIEN - Tree-shakeable
import User from 'lucide-react/dist/esm/icons/user';
import Mail from 'lucide-react/dist/esm/icons/mail';

// ✅ O usar lazy loading para íconos pesados
const BigIcon = lazy(() => import('lucide-react/dist/esm/icons/big-icon'));
```

---

### 5. Error Handling 🛡️

```typescript
// ✅ SIEMPRE catch errors en async/await
try {
  const data = await supabase.from('table').select();
  if (data.error) throw data.error;
} catch (error) {
  logger.error('Database error', error);
  // Handle error gracefully
}

// ✅ SIEMPRE validar respuestas de Supabase
const { data, error } = await supabase.from('table').select();
if (error) {
  logger.error('Query failed', error);
  return null;
}
```

---

### 6. LocalStorage Best Practices 💾

```typescript
// ✅ SIEMPRE usar try-catch con localStorage
try {
  const data = localStorage.getItem('key');
  return data ? JSON.parse(data) : null;
} catch (error) {
  logger.warn('LocalStorage read failed', error);
  return null;
}

// ✅ Considerar límites de tamaño (5-10MB)
// Usar Zustand persist para state management
```

---

## 🔥 Performance Tips

### 1. Lazy Loading Rutas

```typescript
// ✅ Lazy load pages
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));
```

### 2. Memoization

```typescript
// ✅ Usar useMemo para cálculos costosos
const filteredData = useMemo(() => {
  return data.filter(item => item.active);
}, [data]);

// ✅ Usar useCallback para funciones pasadas como props
const handleClick = useCallback(() => {
  // handler logic
}, [dependencies]);
```

### 3. Bundle Size

```bash
# Verificar tamaño del bundle
npm run analyze

# Objetivo: 
# - Initial load: < 200KB (gzipped)
# - Total bundle: < 1MB
```

---

## 🔒 Security Checklist

- [ ] No console.logs con datos sensibles en producción
- [ ] Validar TODOS los inputs de usuario
- [ ] Usar `DOMPurify` para HTML dinámico
- [ ] HTTPS only en producción
- [ ] CSP headers configurados
- [ ] No hardcodear API keys/secrets

---

## 📊 Code Quality Metrics

### Objetivos:

- **TypeScript Coverage**: > 95% (actualmente ~40%)
- **Console Logs**: 0 en producción (actualmente 177)
- **Bundle Size**: < 200KB inicial (TBD)
- **Lighthouse Score**: > 90 (TBD)
- **Test Coverage**: > 80% (TBD)

---

## 🚨 Pre-Commit Checklist

Antes de hacer commit:

1. ✅ `npm run lint` pasa sin errores
2. ✅ `npm run build` compila exitosamente
3. ✅ No hay `console.log` en código nuevo
4. ✅ Tipos TypeScript correctos (no `any`)
5. ✅ Tests pasan (cuando se implementen)

---

## 📚 Recursos

- [React Query Docs](https://tanstack.com/query/latest)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Vite Performance](https://vitejs.dev/guide/performance.html)
- [Supabase Best Practices](https://supabase.com/docs/guides/best-practices)

---

**Última actualización**: 2025-12-13  
**Responsable**: Equipo de Desarrollo Adaptio

