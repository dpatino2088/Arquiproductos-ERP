# 🔧 Ejecutar Migración 332: Backfill Robusto

## 📋 Problema

La migración 331 no funcionó. Esta versión (332) es más robusta:
- ✅ Logs muy detallados de cada paso
- ✅ Manejo de errores mejorado
- ✅ Verifica QuoteLines antes de procesar
- ✅ Muestra errores específicos si falla

## 🚀 Pasos

1. **Ejecutar migración 332:**
   - Archivo: `database/migrations/332_backfill_salesorder_lines_robust.sql`
   - Copia y pega TODO el script en Supabase SQL Editor
   - Ejecuta

2. **Revisar los logs:**
   - Los logs aparecen en la pestaña "Logs" de Supabase (no en Results)
   - Ve a: Dashboard → Logs → Postgres Logs
   - Busca mensajes que empiecen con: `🔧 Backfilling missing SalesOrderLines`

3. **Verificar resultados:**
   - Al final del script hay una query de verificación
   - Debería mostrar: `✅ All SalesOrders have SalesOrderLines`

## ⚠️ IMPORTANTE: Ver Logs en Supabase

Los `RAISE NOTICE` no aparecen en "Results", aparecen en:
- Dashboard → Logs → Postgres Logs
- O en la consola de Supabase

## ❌ Si hay errores

Los errores se mostrarán claramente en los logs:
```
❌ ERROR creating line for QuoteLine ...:
   Message: [mensaje específico]
   SQLSTATE: [código]
```

Copia el mensaje de error completo para análisis.


