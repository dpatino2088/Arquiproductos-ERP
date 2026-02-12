# Implementación UI: DealerConfiguratorPolicies en el Configurador

Documento detallado de los cambios ejecutados para conectar **DealerConfiguratorPolicies** al configurador (solo frontend; sin enforcement en backend).

---

## 1. Hook `useDealerConfiguratorPolicy`

**Ruta:** `src/hooks/useDealerConfiguratorPolicy.ts`

### Interfaz exportada

```ts
export interface DealerConfiguratorPolicy {
  id: string;
  organization_id: string;
  dealer_id: string;
  allowed_product_type_codes: string[];
  allow_variants_catalog: boolean;
  allow_variants_oneoff: boolean;
  allow_accessories_only: boolean;
  allow_hardware: boolean;
  allow_operating_system: boolean;
  created_at?: string;
  updated_at?: string;
}
```

### Comportamiento

- Usa **ActingAsContext** (`activeDealerId`) y **OrganizationContext** (`activeOrganizationId`).
- Si no hay `activeDealerId` o `activeOrganizationId`, devuelve `null` (sin restricciones).
- Consulta Supabase:
  - Tabla: `DealerConfiguratorPolicies`
  - Filtros: `organization_id`, `dealer_id`
  - `.maybeSingle()` para no fallar si no existe fila.
- Normaliza `allowed_product_type_codes` a array (por si viene vacío o no array).
- Devuelve la fila tipada o `null`. Sin policy = comportamiento actual del configurador (todo visible).

---

## 2. ProductConfigurator.tsx

**Ruta:** `src/pages/sales/ProductConfigurator.tsx`

### 2.1 Uso del hook

```ts
const policy = useDealerConfiguratorPolicy();
```

### 2.2 Filtrado de pasos (step builder)

Dentro del `useMemo` que construye `steps`:

- **Hardware:** se añade el paso HARDWARE solo si:
  - `questions.requiredSteps.hardware` es true **y**
  - `!policy || policy.allow_hardware`
- **Operating System:** se añade el paso OPERATING SYSTEM solo si:
  - `questions.requiredSteps.operatingSystem` es true **y**
  - `!policy || policy.allow_operating_system`

Variables usadas:

```ts
const allowHardware = !policy || policy.allow_hardware;
const allowOperatingSystem = !policy || policy.allow_operating_system;
// ...
if (questions.requiredSteps.hardware && allowHardware) {
  dynamicSteps.push({ id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent });
}
if (questions.requiredSteps.operatingSystem && allowOperatingSystem) {
  dynamicSteps.push({ id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent });
}
```

- Sin policy: se muestran hardware y operating system según `questions.requiredSteps`.
- Con policy y `allow_hardware: false`: no se muestra el paso HARDWARE.
- Con policy y `allow_operating_system: false`: no se muestra el paso OPERATING SYSTEM.

### 2.3 Paso ProductStep (selección de producto)

Se pasa `policy` como prop:

```tsx
<ProductStep
  config={config as any}
  onUpdate={productStepOnUpdate as any}
  policy={policy}
/>
```

### 2.4 Paso VariantsStep (variantes)

En la construcción de `stepProps` para el step actual:

```ts
if (step.id === 'variants') {
  stepProps.policy = policy;
}
```

Luego se hace `<StepComponent {...stepProps} />`, así que VariantsStep recibe `policy`.

---

## 3. ProductStep.tsx

**Ruta:** `src/pages/sales/curtain-config/ProductStep.tsx`

### 3.1 Props

- Nueva prop opcional: `policy?: DealerConfiguratorPolicy | null`.
- Tipo importado: `DealerConfiguratorPolicy` desde `@/hooks/useDealerConfiguratorPolicy`.

### 3.2 Filtrado de product types (cards visibles)

- Se mantiene `productCards` (derivado de `productTypes` + metadata UI).
- Se añade un **useMemo** para las cards visibles según policy:

```ts
const visibleProductCards = useMemo(() => {
  if (!policy || !policy.allowed_product_type_codes?.length) return productCards;
  return productCards.filter(
    (p): p is NonNullable<typeof p> =>
      !!p && policy!.allowed_product_type_codes.includes(p.code)
  );
}, [productCards, policy]);
```

- Si **no hay policy** o `allowed_product_type_codes` está vacío: se muestran todas las cards (`productCards`).
- Si **hay policy** con códigos: solo se muestran las cards cuyo `code` (ej. `ROLLER`, `DUAL`) está en `policy.allowed_product_type_codes`.

### 3.3 Uso en el render

- Condición de “no product types”: se usa `visibleProductCards.length === 0` en lugar de `productCards.length === 0`.
- Grid de cards: se hace `visibleProductCards.map(...)` en lugar de `productCards.map(...)`.
- En dev se loguean `visibleCount` y `policy?.allowed_product_type_codes` para depuración.

---

## 4. VariantsStep.tsx

**Ruta:** `src/pages/sales/curtain-config/VariantsStep.tsx`

### 4.1 Props y estado

- Nueva prop opcional: `policy?: DealerConfiguratorPolicy | null`.
- Tipo importado: `DealerConfiguratorPolicy` desde `@/hooks/useDealerConfiguratorPolicy`.
- Estado local: `variantsTab: 'catalog' | 'oneoff'` para el tab activo cuando hay ambos permitidos.

### 4.2 Flags derivados de la policy

```ts
const showCatalog = !policy || policy.allow_variants_catalog;
const showOneOff = !policy || policy.allow_variants_oneoff;
const showTabs = !!policy && showCatalog && showOneOff;
```

- Sin policy: `showCatalog` y `showOneOff` true; `showTabs` false → solo contenido de catálogo, sin tabs.
- Con policy: se respetan `allow_variants_catalog` y `allow_variants_oneoff`; tabs solo si ambos son true.

### 4.3 Casos de render

1. **Sin productTypeId**  
   Mensaje existente: “Please select a product type in the previous step…”. Sin cambios.

2. **Policy con ni catálogo ni oneoff**  
   `if (policy && !showCatalog && !showOneOff)`:  
   - Mensaje: “Fabric selection is not available for your account.”  
   - Subtítulo: “Contact your administrator if you need access.”

3. **Policy solo OneOff (sin catálogo)**  
   `if (policy && !showCatalog && showOneOff)`:  
   - Título: “VARIANTS (Manual / OneOff)”.  
   - Placeholder: “Manual fabric entry (OneOff) – Enter SKU, Collection, Variant, Cost and roll width. Coming soon.”

4. **Resto (catálogo permitido y/o oneoff)**  
   - El contenido de catálogo (manufacturer, collection, variants grid, Fabric Spec Details) se guarda en una variable `catalogContent`.
   - Placeholder de OneOff en variable `oneOffPlaceholder` (mismo texto que el caso 3).

### 4.4 Return principal (card blanca)

- Si `showTabs` es true: se muestra una barra de tabs con **Catalog** y **OneOff**; al cambiar tab se pinta `catalogContent` o `oneOffPlaceholder`.
- Si `showTabs` es false: se pinta solo `catalogContent` (comportamiento actual cuando no hay policy o solo está permitido catálogo).

```tsx
{showTabs && (
  <div className="flex gap-2 border-b border-gray-200 pb-2 mb-4">
    <button ... onClick={() => setVariantsTab('catalog')}>Catalog</button>
    <button ... onClick={() => setVariantsTab('oneoff')}>OneOff</button>
  </div>
)}
{showTabs ? (variantsTab === 'catalog' ? catalogContent : oneOffPlaceholder) : catalogContent}
```

---

## 5. Resumen de flujo

| Contexto | Product types | Paso HARDWARE | Paso OPERATING SYSTEM | VariantsStep |
|----------|----------------|---------------|------------------------|--------------|
| Sin “actuar como” dealer / sin policy (org user) | Todos | Según questions | Según questions | Tabs Catalog + OneOff (admin puede probar) |
| Acting as dealer sin policy | Todos | Según questions | Según questions | Catálogo visible, sin tabs |
| Policy: `allowed_product_type_codes = ['ROLLER','DUAL']` | Solo ROLLER y DUAL | Según policy | Según policy | Según allow_variants_catalog / allow_variants_oneoff |
| Policy: `allow_hardware: false` | Según policy | Oculto | Según policy | Idem |
| Policy: `allow_operating_system: false` | Según policy | Según policy | Oculto | Idem |
| Policy: `allow_variants_catalog: true`, `allow_variants_oneoff: true` | Según policy | Según policy | Según policy | Tabs Catalog + OneOff |
| Policy: ambos variants false | Según policy | Según policy | Según policy | Mensaje “not available” |

---

## 6. Archivos tocados

| Archivo | Cambios |
|---------|--------|
| `src/hooks/useDealerConfiguratorPolicy.ts` | Hook + interfaz; retorno `{ policy, loading }`; normalización de `allowed_product_type_codes` a minúsculas. |
| `src/context/ConfiguratorPolicyContext.tsx` | Contexto `ConfiguratorPolicyProvider` + `useConfiguratorPolicy()` para evitar prop drilling. |
| `src/pages/sales/ProductConfigurator.tsx` | `useDealerConfiguratorPolicy()`, filtrado de steps hardware/OS, `ConfiguratorPolicyProvider` envolviendo el configurador. |
| `src/pages/sales/curtain-config/ProductStep.tsx` | Policy/loading desde context (fallback a props); comparación case-insensitive; fail closed si policy con array vacío; loading state. |
| `src/pages/sales/curtain-config/VariantsStep.tsx` | Policy desde context; override `isOrgUser` para mostrar tabs Catalog/OneOff cuando no se actúa como dealer (admin puede probar OneOff). |

---

## 7. Ajustes de ingeniería (revisión)

### 7.1 Case-sensitivity en product type codes

- **Hook:** `allowed_product_type_codes` se normalizan al cargar: `raw.map(x => String(x).trim().toLowerCase())`.
- **ProductStep:** Se compara con `(p.code || '').toLowerCase()` frente a códigos ya en minúsculas. Así `ROLLER` en DB y `roller` en policy siguen coincidiendo.

### 7.2 Tabs en Variants: override para org-users

- **Regla:** OneOff solo aparece con policy (cuando actúas como dealer y la policy permite ambos) O cuando el usuario es org (internal).
- **Implementación:** `isOrgUser = userType === 'internal'` (desde `useAccessContext()`), no por `!activeDealerId`, para evitar falso positivo si un dealer entra sin haber seteado activeDealerId.  
  `isActingAsDealer = !!activeDealerId`.  
  `showTabs = (isOrgUser && showCatalog && showOneOff) || (isActingAsDealer && !!policy && showCatalog && showOneOff)`.  
  Así solo los internal (org) pueden ver tabs sin policy; dealers solo ven tabs si tienen policy que permite ambos.
- **OneOff tab:** Lleva badge "Beta" y `title` indicando que no se guarda en la quote aún, para no confundir a vendedores.

### 7.3 Policy con `allowed_product_type_codes` vacío = fail closed

- **Antes:** Array vacío → se mostraban todos los product types.
- **Después:** Si existe policy y el array está vacío → no se muestra ningún tipo; mensaje “No product types assigned. Contact your administrator…”.

### 7.4 Loading state

- **Hook:** Devuelve `{ policy, loading }`. `loading` solo es true cuando hay `activeDealerId` y se está haciendo fetch.
- **ProductStep:** Si `policyLoading` es true se muestra “Loading permissions…” (skeleton) para evitar flash de todos los tipos antes de restringir.

### 7.5 ConfiguratorPolicyContext (prop drilling)

- **ProductConfigurator** envuelve el configurador en `<ConfiguratorPolicyProvider value={{ policy, loading }}>`.
- **ProductStep** y **VariantsStep** usan `useConfiguratorPolicy()` para leer policy (y loading en ProductStep). Las props opcionales `policy` / `policyLoading` siguen disponibles como override (p. ej. tests).

---

## 8. Notas

- **Backend:** No se ha añadido enforcement en API/RLS; la restricción es solo de UI.
- **OneOff:** La pestaña OneOff es solo un placeholder (“Coming soon”).
- **allow_accessories_only:** El campo existe en la interfaz pero no se usa aún en esta implementación.
