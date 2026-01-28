# Informe: "Manual drive selection is required" / "Motor selection is required" pese a tener Drive Type seleccionado

## 1. Síntoma

- En el paso **QUOTE**, al pulsar **Add to Quote**, aparece:
  - **"Configuration Incomplete: Please complete the following fields: Manual drive selection is required"** cuando Drive Type = manual, o
  - **"Motor selection is required"** cuando Drive Type = motor.
- En **Product Specifications** sí se muestra **Drive Type: manual** o **Drive Type: motor**.
- El usuario sí eligió Manual/Motor y, en principio, un ítem concreto de drive o motor en OPERATING SYSTEM.

---

## 2. Dónde se valida

- **Archivo:** `src/pages/sales/ProductConfigurator.tsx`
- **Función:** `handleComplete` (al hacer clic en "Add to Quote" en el paso QUOTE).
- **Bloque:** validación de `questions.requiredSteps.operatingSystem` (aprox. líneas 734–800).

La lógica exige, además de `operation_type` / `drive_type`:

- Si **Manual:** al menos uno de: `drive_sku`, `driveSku`, `drive_item_id`, `driveItemId`, `manual_drive`.
- Si **Motor:** al menos uno de: `motor_sku`, `motorSku`, `motor_item_id`, `motorItemId`.
- En ambos: `tube_sku` o `tubeSku` o `tube_type` o `tubeType` o `tube_item_id` o `tubeItemId`.

Esas comprobaciones se hacen sobre `configAny`:

```ts
const hasDrive = !!(
  configAny.drive_sku ||
  configAny.driveSku ||
  configAny.drive_item_id ||
  configAny.driveItemId ||
  configAny.manual_drive
);
```

---

## 3. De dónde sale `configAny`

En `handleComplete`:

```ts
const normalizedConfig = normalizeConfig(config as Partial<UnifiedProductConfig>);
const configAny = normalizedConfig as any;
```

- `config` = estado de React con toda la configuración (incluidas las claves que vienen de OperatingSystemStep).
- `normalizedConfig` = resultado de `normalizeConfig(config)`.
- `configAny` = ese mismo objeto para acceder con `as any`.

Toda la validación de drive/motor/tube usa `configAny` (es decir, `normalizedConfig`).

---

## 4. Qué hace `normalizeConfig`

- **Archivo:** `src/pages/sales/product-config/config-contract.ts`
- **Función:** `normalizeConfig`.

`normalizeConfig` devuelve un objeto nuevo construido a mano, solo con ciertos campos, por ejemplo:

- `product_type_id`, `bom_template_id`, `productType`
- `width_m`, `height_m`, `area`, `position`, `quantity`
- `hardware_color`, `cassette`, `side_channel`, `side_channel_type`, `drive_type`, `tube_type`
- `fabric_variant_id`, `variantId`, `collectionId`, etc.
- `operatingSystem`, `operation_type`, `operating_system_variant`, `bottom_rail_type`
- `accessories`

**No se incluyen en el objeto devuelto**, entre otros:

- `drive_sku`, `driveSku`, `drive_item_id`, `driveItemId`, `manual_drive`
- `motor_sku`, `motorSku`, `motor_item_id`, `motorItemId`
- `tube_sku`, `tubeSku`, `tube_type`, `tubeType`, `tube_item_id`, `tubeItemId`
- `bottom_bar_sku`, `bottom_bar_item_id`, etc.

Es decir: `normalizeConfig` **no copia** las claves de ítems concretos (drive, motor, tube, bottom_bar, etc.) al objeto que devuelve.

---

## 5. Hipótesis del problema

La validación de "Manual drive selection is required" y "Motor selection is required" se ejecuta sobre `configAny` = `normalizeConfig(config)`.

`normalizeConfig` **no pone** en su salida `drive_sku`, `drive_item_id`, `motor_sku`, `tube_sku`, etc. Por tanto, en `configAny` esas propiedades **no existen** (o son `undefined`).

En consecuencia:

- `configAny.drive_sku`, `configAny.drive_item_id`, `configAny.manual_drive`, etc. son siempre `undefined`.
- `hasDrive` y `hasMotor` dan siempre `false`.
- `hasTube` también da `false` por el mismo motivo.

Aunque en `config` (estado de React) sí estén guardados `drive_sku`, `drive_item_id`, etc. (porque el usuario los eligió en OperatingSystemStep), la validación **nunca los lee** porque usa `normalizedConfig`, que es un objeto que **los ha omitido**.

Resumen: **el fallo no es que falte la selección de drive/motor en el configurador, sino que la validación lee un objeto (`normalizedConfig`) que nunca contiene esas claves.**

---

## 6. Evidencia en código

| Qué | Dónde |
|-----|-------|
| `handleComplete` asigna `configAny = normalizeConfig(config)` | `ProductConfigurator.tsx` ~702–703 |
| Validación de drive/motor/tube usa `configAny.*` | `ProductConfigurator.tsx` ~765–795 |
| `normalizeConfig` devuelve un objeto sin `drive_sku`, `drive_item_id`, `motor_sku`, `tube_sku`, etc. | `config-contract.ts` ~52–89 |

---

## 7. Propuesta de solución

Usar el **config crudo** (`config`) para la validación de ítems concretos (drive, motor, tube), en lugar de `normalizedConfig`/`configAny`.

O, de forma equivalente: que `normalizeConfig` **preserve** (o haga merge de) las claves que no define explícitamente (por ejemplo `drive_sku`, `drive_item_id`, `motor_sku`, `motor_item_id`, `tube_sku`, `tube_item_id`, `manual_drive`, etc.) desde `config` hacia el objeto que devuelve, de modo que al hacer `configAny = normalizedConfig` esas propiedades sí existan.

Con una de estas dos opciones, la validación volvería a ver los valores que el usuario realmente seleccionó y dejaría de mostrar "Manual drive selection is required" / "Motor selection is required" cuando drive o motor sí están elegidos.

---

## 8. Resumen

| Aspecto | Detalle |
|---------|---------|
| Síntoma | "Manual drive selection is required" o "Motor selection is required" en QUOTE aunque Drive Type = manual/motor. |
| Causa | La validación usa `normalizeConfig(config)`, que no incluye `drive_sku`, `drive_item_id`, `motor_sku`, `tube_sku`, etc. |
| Efecto | `hasDrive` / `hasMotor` / `hasTube` son siempre false aunque el usuario haya seleccionado drive, motor y tube. |
| Acción | Validar con `config` (o que `normalizeConfig` preserve esas claves) en lugar de depender solo del objeto normalizado para esos campos. |
