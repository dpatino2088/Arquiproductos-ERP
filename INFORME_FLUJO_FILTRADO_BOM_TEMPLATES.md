# INFORME: Flujo de filtrado de BOM Templates

**Fecha:** 2026-01-22  
**Módulo:** BOM Template Filtering  
**Fuente de verdad:** `src/hooks/useBOMTemplates.ts`

---

## DÓNDE se filtran los templates (fuente de verdad)

### 1) `src/hooks/useBOMTemplates.ts` ✅ **AQUÍ se filtra “de verdad”**

Este hook hace **3 cosas**:

1. **Query base (structural filters)** contra `BOMTemplates`
   - Filtra por: `organization_id`, `product_type_id`, `hardware_color`
   - Flags: `deleted = false`, `archived = false` (y `active` si aplica)

2. **Carga slots** (`BOMTemplateSlots`) de esos templates candidatos  
   - Join lógico a `CatalogItems` para traer `sku` por `catalog_item_id`

3. **Aplica filtros por selección (selections)** en memoria:
   - `bottom_bar`
   - `tube`
   - `headbox` / `cassette`
   - `operating_type` (manual / motorized) + motor / drive
   - **Side channel y bottom channel NO filtran** (solo afectan BOM generation)

**Conclusión:** Si “desaparecen templates” al hacer click, el lugar donde ocurre es aquí; casi siempre por **cómo llega el config/filtros** (ver abajo).

---

### 2) `src/pages/sales/ProductConfigurator.tsx` ✅ **AQUÍ se construye `templateFilters`**

Aquí **no se filtra**, pero aquí nace el bug más común:

- Si el `setConfig` al seleccionar Bottom Bar **pisa el config entero** (replace en vez de merge)
- O si `normalizeCfg` convierte `""` / `null` / `undefined` en un estado equivocado

**Si en este punto** `bottom_bar_sku` queda como `""` o `undefined`, o `operation_type` cambia, **useBOMTemplates vuelve a correr** y puede irse a **0 templates**.

---

### 3) `src/hooks/useBOMTemplateRoleOptions.ts` ✅ **Solo opciones para las CARDS**

Este hook **NO filtra templates**. Solo:

- Recibe `candidateTemplateIds`
- Trae options desde `BOMTemplateSlots` para `item_role = 'bottom_bar'`, etc.
- Hace join a `CatalogItems`

---

## CÓMO se filtran (lógica exacta)

### Pipeline

- **A) BaseTemplates**  
  Solo filtros estructurales: query inicial a `BOMTemplates`.

- **B) FilteredTemplates**  
  Se aplican selections en memoria.

### Al elegir Bottom Bar

1. **Match por `bottom_bar_item_id` (UUID)** primero  
2. **Fallback por `bottom_bar_sku`** si no hay `item_id`  
3. **Role-only fallback:**  
   Si el slot tiene el rol pero `catalog_item_id` está vacío → se acepta.

Ese **role-only fallback** es lo que mantiene varios templates vivos cuando los slots no tienen item asignado (por diseño).

### Matching: `slotMatches()`

- Prioridad 1: `catalog_item_id` (UUID)
- Prioridad 2: `sku` (exacto, case-sensitive, trimmed)
- Si no hay filtro → no se filtra por ese slot.

---

## Por qué aparece “BOM template selection” en PRODUCT

La UI detecta:

- Quedan **2+ templates** después del filtrado  
→ Muestra selector para que el usuario elija 1.

No es “misterioso”: es la forma de resolver la ambigüedad.  
Si ves *“2 templates found – please select one”*, el selector es coherente con eso.

---

## El problema real que suele romper todo

### 1) “Selecciono bottom bar y se pierden templates”

En la mayoría de los casos es uno de estos **3**:

#### (A) `setConfig` **reemplaza** en vez de **merge**

```ts
// ❌ MAL – mata hardware_color, product_type_id, operation_type, etc.
setConfig({ bottom_bar_item_id: id, bottom_bar_sku: sku })

// ✅ BIEN
setConfig(prev => ({ ...prev, bottom_bar_item_id: id, bottom_bar_sku: sku }))
```

**Estado actual:** En `HardwareStep.tsx` el click de Bottom Bar y la X de deselección usan **merge** (`onUpdate(prev => ({ ...prev, ... }))`). ✅

#### (B) Estado **none / unset / selected** mal interpretado

- `headbox_sku = ""` (string vacío) y el normalizador lo trata como “selected” o “none” incorrecto  
→ Se excluyen templates sin querer.

**Regla sana:**

- `undefined` = **UNSET** (no filtra)
- `null` = **NONE** (excluye templates con ese rol)
- `string` sku = **SELECTED** (filtra)

#### (C) Filtrar por SKU cuando deberías por UUID

- El filtro usa `bottom_bar_sku` pero el slot tiene `catalog_item_id` y el SKU llega con espacios/case distinto  
→ No hay match.

**Regla:** Filtrar por `bottom_bar_item_id` siempre que exista.

---

### 2) “Manual y Motorized salen con el mismo precio”

Esto **ya no es filtrado de templates**; es **pricing / compute**:

- En QuoteLines no se está aplicando el BOM del template seleccionado al cálculo  
  (o se calcula con BOM vacío / solo tela).
- El UI deja elegir motor/drive/tube, pero el cálculo final **no usa el template resuelto** para sumar BOM/labor.

**Dónde arreglarlo:** Donde se construye el “ConfiguredProduct” o el cálculo del QuoteLine debe haber:

```
resolveTemplateId(config) → con ese template generar BOM instance → cost → msrp
```

Si `bom_template_id` sigue “Not resolved”, la línea no puede diferenciar manual vs motor.

---

## Operation type como filtro estructural

- **Hoy:** `operation_type` **no** se aplica en el query inicial a `BOMTemplates`.  
  Los baseTemplates incluyen manual + motorized; luego se filtra en memoria por slots (motor vs drive).

- **Para que sea “estructural temprano”** en el **query** haría falta una columna tipo `operation_type` (o equivalente) en `BOMTemplates`. Sin cambio de schema, se sigue filtrando en memoria después de cargar slots.

---

## Resumen directo

**“¿Dónde y cómo se filtran los templates?”**

- **Dónde:** `src/hooks/useBOMTemplates.ts`
- **Cómo:**
  1. Query base a `BOMTemplates` (product_type + hardware_color + org + flags)
  2. Se cargan slots (`BOMTemplateSlots`) + SKUs (`CatalogItems`)
  3. Se filtra en memoria por selections usando `slotMatches()` y la lógica unset/none/selected.

`ProductConfigurator.tsx` solo **arma los filtros**; `HardwareStep` solo **setea config** y muestra opciones desde slots. El filtrado “de verdad” ocurre en el hook.

---

## Acciones útiles ya (sin adivinar)

- **A)** Handler del click Bottom Bar: confirmar que siempre es **merge** (✅ verificado).
- **B)** En `useBOMTemplates`: loguear **solo primitivos** (counts, ids, valores normalizados de filtros). Nada de objetos completos → se evita `[circular]`.
- **C)** Si se quiere `operation_type` estructural en el query: revisar schema y añadir columna o vista; si no, mantener filtrado en memoria como ahora.
