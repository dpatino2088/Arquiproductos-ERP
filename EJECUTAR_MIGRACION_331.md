# 🔧 Ejecutar Migración 331: Backfill Simplificado

## 📋 Problema

La migración 329 no creó las SalesOrderLines. Esta versión simplificada:
- ✅ Muestra errores claramente
- ✅ Usa solo columnas básicas primero
- ✅ Logs detallados de cada paso

## 🚀 Pasos

1. **Primero ejecutar diagnóstico:**
   - Archivo: `DIAGNOSTICO_SALESORDER_LINES.sql`
   - Esto mostrará si hay QuoteLines disponibles

2. **Luego ejecutar migración 331:**
   - Archivo: `database/migrations/331_backfill_salesorder_lines_simple.sql`
   - Esta versión es más simple y muestra errores claramente

## ✅ Resultado Esperado

Deberías ver logs como:
```
🔧 Backfilling missing SalesOrderLines (Simplified)...
  Found 5 SalesOrder(s) without lines
  
  📦 Processing SalesOrder: SO-090156 (...)
     Quote ID: ...
     📝 Creating line 1 for QuoteLine ...
     ✅ Created SalesOrderLine: ...
  
✅ Backfill complete:
   - Processed: 5 SalesOrder(s)
   - Created: X SalesOrderLine(s)
   - Errors: 0
```

## ❌ Si hay errores

Los errores se mostrarán claramente:
```
❌ ERROR: [mensaje del error]
   SQLSTATE: [código del error]
```

Esto nos dirá exactamente qué está fallando (columnas faltantes, constraints, etc.)


