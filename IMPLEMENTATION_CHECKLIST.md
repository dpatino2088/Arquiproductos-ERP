# ✅ Checklist de Implementación - Enhanced BOM Architecture

## 📋 FASE 1: Preparación y Revisión (30 min)

### 1.1 Revisar la migración
- [ ] Abrir `database/migrations/146_enhanced_bom_architecture.sql`
- [ ] Revisar que las tablas creadas sean las necesarias
- [ ] Verificar que los nombres de columnas coincidan con tus necesidades
- [ ] Ajustar `organization_id` si es necesario (la migración usa el primer activo)

### 1.2 Backup de base de datos
```bash
# En Supabase Dashboard o usando pg_dump
# Hacer backup antes de ejecutar migración
```

### 1.3 Ejecutar migración en desarrollo
- [ ] Ir a Supabase Dashboard → SQL Editor
- [ ] Copiar y pegar el contenido de `146_enhanced_bom_architecture.sql`
- [ ] Ejecutar la migración
- [ ] Verificar que no haya errores
- [ ] Revisar los mensajes `RAISE NOTICE` en los logs

**Comando alternativo (si usas CLI):**
```bash
# Si tienes Supabase CLI configurado
supabase db reset  # Solo en desarrollo
# O ejecutar directamente en SQL Editor
```

---

## 📋 FASE 2: Poblar Datos Base (1-2 horas)

### 2.1 Verificar que se crearon las opciones base
```sql
-- Verificar ProductOptions creados
SELECT * FROM "ProductOptions" WHERE deleted = false ORDER BY sort_order;

-- Verificar ProductOptionValues
SELECT 
  po.option_code,
  pov.value_code,
  pov.label
FROM "ProductOptionValues" pov
JOIN "ProductOptions" po ON pov.option_id = po.id
WHERE pov.deleted = false
ORDER BY po.sort_order, pov.sort_order;
```

### 2.2 Poblar CatalogItems con SKUs reales
**IMPORTANTE:** Necesitas tener tus SKUs en `CatalogItems` antes de continuar.

```sql
-- Ejemplo: Verificar que tienes SKUs como RC4004, RCA-04, etc.
SELECT id, sku, item_name, item_type 
FROM "CatalogItems" 
WHERE sku IN ('RC4004', 'RCA-04', 'RC4001', 'RC4002', 'RC4003', ...)
AND deleted = false;
```

**Si no los tienes, créalos:**
```sql
-- Ejemplo de inserción (ajusta según tus datos reales)
INSERT INTO "CatalogItems" (
  organization_id,
  sku,
  item_name,
  item_type,
  uom,
  cost_exw,
  msrp
) VALUES (
  'tu-org-id',
  'RC4004',
  'Bracket Base',
  'hardware',
  'unit',
  10.00,
  15.00
);
```

### 2.3 Crear HardwareColorMapping
```sql
-- Ejemplo: Mapear brackets por color
-- Primero, necesitas los IDs de tus CatalogItems

-- Paso 1: Obtener IDs
SELECT id, sku FROM "CatalogItems" WHERE sku LIKE 'RC4004%';

-- Paso 2: Crear mapeos (ajusta los IDs reales)
INSERT INTO "HardwareColorMapping" (
  organization_id,
  base_part_id,
  hardware_color,
  mapped_part_id
)
SELECT 
  'tu-org-id',
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004'),  -- Base
  'white',
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC4004-WH') -- White variant
WHERE EXISTS (SELECT 1 FROM "CatalogItems" WHERE sku = 'RC4004-WH')
ON CONFLICT DO NOTHING;

-- Repetir para black, silver, bronze según tengas variantes
```

### 2.4 Crear CassettePartsMapping
```sql
-- Ejemplo: Mapear partes de cassette L-shape
INSERT INTO "CassettePartsMapping" (
  organization_id,
  cassette_shape,
  part_role,
  catalog_item_id,
  qty_per_unit
)
SELECT 
  'tu-org-id',
  'L',
  'profile',
  (SELECT id FROM "CatalogItems" WHERE sku = 'CASSETTE-L-PROFILE'),
  1
WHERE EXISTS (SELECT 1 FROM "CatalogItems" WHERE sku = 'CASSETTE-L-PROFILE')
ON CONFLICT DO NOTHING;

-- Repetir para:
-- - endcap_left, endcap_right
-- - clip
-- - round, square shapes
```

### 2.5 Crear MotorTubeCompatibility
```sql
-- Ejemplo: CM-09 compatible con RTU-65
INSERT INTO "MotorTubeCompatibility" (
  organization_id,
  tube_type,
  motor_family,
  required_crown_item_id,
  required_drive_item_id,
  notes
)
SELECT 
  'tu-org-id',
  'RTU-65',
  'CM-09',
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC3100-ABC-65'),  -- Crown
  (SELECT id FROM "CatalogItems" WHERE sku = 'RC3164-XX'),      -- Drive
  'CM-09 motor with RTU-65 tube requires specific crown and drive'
WHERE EXISTS (SELECT 1 FROM "CatalogItems" WHERE sku = 'RC3100-ABC-65')
ON CONFLICT DO NOTHING;

-- Repetir para todas las combinaciones válidas:
-- CM-05: RTU-42, RTU-50
-- CM-06: RTU-42, RTU-50, RTU-65
-- CM-09: RTU-65, RTU-80
-- CM-10: RTU-80
```

---

## 📋 FASE 3: Actualizar BOM Templates (2-3 horas)

### 3.1 Revisar BOMTemplates existentes
```sql
-- Ver templates actuales
SELECT 
  bt.id,
  bt.name,
  pt.name as product_type,
  COUNT(bc.id) as component_count
FROM "BOMTemplates" bt
JOIN "ProductTypes" pt ON bt.product_type_id = pt.id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.deleted = false
GROUP BY bt.id, bt.name, pt.name;
```

### 3.2 Actualizar BOMComponents con nuevos campos
```sql
-- Ejemplo: Actualizar un componente existente con qty_type
UPDATE "BOMComponents"
SET 
  qty_type = 'fixed',
  qty_value = 2,
  select_rule = NULL
WHERE 
  component_role = 'bracket'
  AND bom_template_id = 'tu-template-id'
  AND deleted = false;

-- Ejemplo: Componente con qty per_width
UPDATE "BOMComponents"
SET 
  qty_type = 'per_width',
  qty_value = 1.0,
  select_rule = NULL
WHERE 
  component_role = 'tube'
  AND bom_template_id = 'tu-template-id'
  AND deleted = false;

-- Ejemplo: Componente resuelto por regla
UPDATE "BOMComponents"
SET 
  qty_type = 'by_option',
  qty_value = NULL,
  select_rule = '{"type": "by_compatibility", "table": "MotorTubeCompatibility", "tube_option": "tube_type", "motor_option": "motor_family"}'::jsonb
WHERE 
  component_role = 'motor_crown'
  AND block_condition->>'operation_type' = 'motor'
  AND bom_template_id = 'tu-template-id'
  AND deleted = false;
```

### 3.3 Crear componentes para cassette (si no existen)
```sql
-- Ejemplo: Cassette profile (condicional)
INSERT INTO "BOMComponents" (
  bom_template_id,
  organization_id,
  block_type,
  block_condition,
  component_role,
  component_item_id,  -- NULL si se resuelve por regla
  qty_type,
  qty_value,
  uom,
  select_rule,
  applies_color,
  hardware_color,
  sequence_order
)
SELECT 
  bt.id,
  bt.organization_id,
  'cassette',
  '{"cassette_shape": {"$ne": "none"}}'::jsonb,
  'cassette_profile',
  NULL,  -- Se resuelve por CassettePartsMapping
  'per_width',
  1.0,
  'm',
  '{"type": "by_mapping", "table": "CassettePartsMapping", "shape_option": "cassette_shape", "role": "profile"}'::jsonb,
  false,
  NULL,
  10
FROM "BOMTemplates" bt
WHERE bt.name LIKE '%Roller%'
AND bt.deleted = false
ON CONFLICT DO NOTHING;
```

---

## 📋 FASE 4: Actualizar Frontend (3-4 horas)

### 4.1 Crear hook para ConfiguredProducts
Crear `src/hooks/useConfiguredProducts.ts`:

```typescript
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export function useConfiguredProducts(quoteLineId?: string) {
  const { activeOrganizationId } = useOrganizationContext();
  const [configuredProduct, setConfiguredProduct] = useState<any>(null);
  const [options, setOptions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!quoteLineId || !activeOrganizationId) return;

    const load = async () => {
      // Load ConfiguredProduct
      const { data: cp } = await supabase
        .from('ConfiguredProducts')
        .select('*')
        .eq('quote_line_id', quoteLineId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .single();

      if (cp) {
        setConfiguredProduct(cp);

        // Load options
        const { data: opts } = await supabase
          .from('ConfiguredProductOptions')
          .select('*')
          .eq('configured_product_id', cp.id)
          .order('option_code');

        setOptions(opts || []);
      }
      setLoading(false);
    };

    load();
  }, [quoteLineId, activeOrganizationId]);

  return { configuredProduct, options, loading };
}
```

### 4.2 Actualizar QuoteNew.tsx para guardar ConfiguredProducts
En `src/pages/sales/QuoteNew.tsx`, después de crear `QuoteLine`:

```typescript
// Después de insertar QuoteLine
const { data: quoteLine, error: quoteLineError } = await supabase
  .from('QuoteLines')
  .insert({...})
  .select()
  .single();

if (quoteLine) {
  // 1) Crear ConfiguredProduct
  const { data: configuredProduct } = await supabase
    .from('ConfiguredProducts')
    .insert({
      organization_id: activeOrganizationId,
      product_type_id: productTypeId,
      quote_line_id: quoteLine.id,
      width_mm: width_mm,
      height_mm: height_mm,
      qty: quantity,
      fabric_catalog_item_id: fabricCatalogItemId,
    })
    .select()
    .single();

  if (configuredProduct) {
    // 2) Insertar opciones
    const optionsToInsert = [
      { configured_product_id: configuredProduct.id, option_code: 'operation_type', option_value: productConfig.drive_type },
      { configured_product_id: configuredProduct.id, option_code: 'tube_type', option_value: productConfig.tubeSize },
      { configured_product_id: configuredProduct.id, option_code: 'hardware_color', option_value: productConfig.hardware_color },
      // ... más opciones
    ].filter(opt => opt.option_value); // Solo insertar si tiene valor

    await supabase
      .from('ConfiguredProductOptions')
      .insert(optionsToInsert);
  }

  // 3) Generar BOM (usar función existente o nueva)
  // ...
}
```

### 4.3 Crear función para cargar opciones disponibles
```typescript
// src/hooks/useProductOptions.ts
export function useProductOptions() {
  const { activeOrganizationId } = useOrganizationContext();
  const [options, setOptions] = useState<any[]>([]);
  const [values, setValues] = useState<Record<string, any[]>>({});

  useEffect(() => {
    if (!activeOrganizationId) return;

    const load = async () => {
      // Load ProductOptions
      const { data: opts } = await supabase
        .from('ProductOptions')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('active', true)
        .order('sort_order');

      setOptions(opts || []);

      // Load values for each option
      if (opts) {
        const valuesMap: Record<string, any[]> = {};
        for (const opt of opts) {
          const { data: vals } = await supabase
            .from('ProductOptionValues')
            .select('*')
            .eq('option_id', opt.id)
            .eq('deleted', false)
            .eq('active', true)
            .order('sort_order');
          valuesMap[opt.option_code] = vals || [];
        }
        setValues(valuesMap);
      }
    };

    load();
  }, [activeOrganizationId]);

  return { options, values };
}
```

---

## 📋 FASE 5: Actualizar Función de Generación BOM (2-3 horas)

### 5.1 Crear nueva función o actualizar existente
Crear `database/migrations/147_update_bom_generation_with_new_tables.sql`:

```sql
-- Actualizar generate_configured_bom_for_quote_line para usar:
-- 1) ConfiguredProductOptions en lugar de parámetros
-- 2) MotorTubeCompatibility para resolver motor parts
-- 3) CassettePartsMapping para resolver cassette parts
-- 4) HardwareColorMapping para resolver colored parts
-- 5) qty_type, qty_value, select_rule de BOMComponents

-- (Esto requiere reescribir la función existente)
```

**O mejor:** Crear una nueva función `generate_enhanced_bom_for_configured_product()` que:
- Tome `configured_product_id` como parámetro
- Lea opciones de `ConfiguredProductOptions`
- Aplique reglas de compatibilidad
- Genere `BomInstance` y `BomInstanceLines`

---

## 📋 FASE 6: Testing (2-3 horas)

### 6.1 Test manual
1. [ ] Crear una cotización nueva
2. [ ] Agregar línea con configuración completa
3. [ ] Verificar que se creó `ConfiguredProduct`
4. [ ] Verificar que se crearon `ConfiguredProductOptions`
5. [ ] Verificar que se generó BOM correctamente
6. [ ] Verificar que se resolvieron SKUs por color
7. [ ] Verificar que se aplicaron reglas de compatibilidad

### 6.2 Test de casos edge
- [ ] Configuración sin cassette (debe omitir partes de cassette)
- [ ] Configuración manual (debe omitir partes de motor)
- [ ] Configuración con motor CM-09 + tube RTU-65 (debe resolver crown correcto)
- [ ] Configuración con hardware color white (debe mapear a variantes blancas)

### 6.3 Verificar BomInstances
```sql
-- Cuando quote esté aprobado, generar BomInstance
INSERT INTO "BomInstances" (
  organization_id,
  configured_product_id,
  bom_template_id,
  status
)
SELECT 
  cp.organization_id,
  cp.id,
  bt.id,
  'locked'
FROM "ConfiguredProducts" cp
JOIN "BOMTemplates" bt ON bt.product_type_id = cp.product_type_id
WHERE cp.quote_line_id = 'tu-quote-line-id'
AND cp.deleted = false
LIMIT 1;

-- Verificar líneas generadas
SELECT 
  bil.*,
  ci.sku,
  ci.item_name
FROM "BomInstanceLines" bil
JOIN "CatalogItems" ci ON bil.resolved_part_id = ci.id
WHERE bil.bom_instance_id = 'tu-bom-instance-id';
```

---

## 📋 FASE 7: Documentación y Limpieza (1 hora)

### 7.1 Documentar decisiones
- [ ] Documentar qué SKUs mapean a qué colores
- [ ] Documentar reglas de compatibilidad motor/tube
- [ ] Documentar qué partes de cassette se usan para cada shape

### 7.2 Limpiar datos de prueba
- [ ] Eliminar `ConfiguredProducts` de prueba
- [ ] Eliminar `BomInstances` de prueba
- [ ] Verificar que datos de producción estén correctos

---

## 🚨 Problemas Comunes y Soluciones

### Error: "organization_id not found"
**Solución:** La migración busca el primer `Organizations` activo. Si no existe, ajusta el `v_org_id` en la sección de seed data.

### Error: "FK constraint violation"
**Solución:** Asegúrate de que los `CatalogItems` existan antes de crear mapeos.

### Error: "Enum type does not exist"
**Solución:** Ejecuta la migración completa, los ENUMs se crean al inicio.

### BOM no se genera correctamente
**Solución:** 
1. Verifica que `ConfiguredProductOptions` tengan los valores correctos
2. Verifica que `BOMComponents.block_condition` coincida con las opciones
3. Verifica que las tablas de compatibilidad tengan datos

---

## 📞 Siguiente Paso Inmediato

**AHORA MISMO, haz esto:**

1. ✅ Abre Supabase Dashboard → SQL Editor
2. ✅ Copia el contenido de `database/migrations/146_enhanced_bom_architecture.sql`
3. ✅ Ejecuta la migración
4. ✅ Revisa los mensajes de `RAISE NOTICE` para ver qué se creó
5. ✅ Ejecuta este query para verificar:

```sql
SELECT 
  'Products' as table_name, COUNT(*) as count FROM "Products" WHERE deleted = false
UNION ALL
SELECT 'ProductOptions', COUNT(*) FROM "ProductOptions" WHERE deleted = false
UNION ALL
SELECT 'ProductOptionValues', COUNT(*) FROM "ProductOptionValues" WHERE deleted = false
UNION ALL
SELECT 'ConfiguredProducts', COUNT(*) FROM "ConfiguredProducts" WHERE deleted = false;
```

**Si todo sale bien, continúa con FASE 2. Si hay errores, compártelos y los corregimos.**









