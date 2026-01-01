# Plan de Reconstrucción del Módulo Manufacturing
## Análisis Quirúrgico - Sin Romper Nada Existente

---

## PROBLEMAS IDENTIFICADOS

### 1. Trigger de Quote Approved
❌ **NO copia QuoteLines a SalesOrderLines**
- Resultado: Sales Orders sin líneas
- Impacto: No se pueden generar BOMs

### 2. Trigger de Manufacturing Order
❌ **NO genera BOMs cuando se crea el MO**
- Resultado: Manufacturing Orders sin BOMs
- Impacto: Material tab vacío

### 3. OrderList Frontend
❌ **Sales Orders desaparecen después de crear MO**
- Ya corregido en el código frontend
- Pero no se refleja por falta de datos

---

## SOLUCIÓN QUIRÚRGICA - 3 FASES

### FASE 1: Reparar Trigger de Quote Approved
**Objetivo**: Que copie QuoteLines a SalesOrderLines automáticamente

**Archivo**: `PHASE1_FIX_QUOTE_APPROVED_TRIGGER.sql`
1. Verificar función `on_quote_approved_create_operational_docs`
2. Asegurar que copie todas las columnas necesarias
3. Probar con un Quote nuevo

### FASE 2: Reparar Datos Existentes (Retroactivo)
**Objetivo**: Corregir los 6 Sales Orders sin líneas

**Archivo**: `PHASE2_FIX_EXISTING_DATA.sql`
1. Copiar QuoteLines → SalesOrderLines para SO-000001 a SO-000006
2. Generar QuoteLineComponents
3. Crear BomInstances
4. Copiar a BomInstanceLines

### FASE 3: Activar Trigger de BOM
**Objetivo**: Que genere BOMs automáticamente al crear MO

**Archivo**: `PHASE3_FIX_BOM_TRIGGER.sql`
1. Verificar función `on_manufacturing_order_insert_generate_bom`
2. Asegurar que copie QuoteLineComponents a BomInstanceLines
3. Probar con un MO nuevo

---

## ORDEN DE EJECUCIÓN

```
1. PHASE1_FIX_QUOTE_APPROVED_TRIGGER.sql  ← Arregla el trigger
2. PHASE2_FIX_EXISTING_DATA.sql           ← Arregla datos existentes
3. PHASE3_FIX_BOM_TRIGGER.sql             ← Arregla trigger de BOM
```

---

## VERIFICACIÓN

Después de cada fase, ejecutar:
- `VERIFY_PHASE1.sql`
- `VERIFY_PHASE2.sql`
- `VERIFY_PHASE3.sql`

---

## NO TOCAR (Mantener funcionando)

✅ Sales module
✅ Quotes module  
✅ Quote Approved view
✅ Directory module
✅ Catalog module
✅ Existing Sales Orders structure
✅ Authentication & permissions

---

## RESULTADO ESPERADO

- ✅ Quote Approved → Crea SO con líneas
- ✅ SO Confirmed → Aparece en OrderList
- ✅ Crear MO → Genera BOM automáticamente
- ✅ Sales Orders permanecen visibles en OrderList
- ✅ Material tab muestra BOMs

---

## PRÓXIMO PASO

Crear los 3 scripts de fase y ejecutarlos en orden.






