# Por qué no se muestra Inventory y RLS de inventario

## 1. Por qué no sale el módulo Inventory en el sidebar

El módulo **Inventory** no aparece en el menú lateral por decisión de implementación actual:

### 1.1 No está en la lista de navegación

En **`src/components/Layout.tsx`** la lista de ítems del sidebar (`allItems`) es:

- Dashboard  
- Directory  
- Sales  
- Sales Orders  
- Catalog  
- Manufacturing  
- Financials  

**No hay ningún ítem con nombre "Inventory" ni href `/inventory`.** Las rutas `/inventory`, `/inventory/warehouse`, etc. sí existen en `App.tsx`, pero no hay enlace en el sidebar que las muestre.

### 1.2 No está en el sistema de acceso por módulos

En **`src/hooks/useAccessContext.ts`** el tipo `ModuleKey` es:

```ts
"dashboard" | "directory" | "sales" | "catalog" | "manufacturing" | "financials" | "settings"
```

No existe `"inventory"`. Los usuarios portal solo ven módulos en `allowedModules`; los internal pasan por RBAC con `MODULE_PERMS`. Como Inventory no está en esa lista, aunque se añadiera al sidebar habría que:

- Añadir `"inventory"` a `ModuleKey`.
- Definir en qué perfiles (portal/internal) se permite.
- Opcionalmente añadir `inventory` a `MODULE_PERMS` en `usePermissions.ts` (p. ej. `inventory.read` / `inventory.write`).

### 1.3 Cómo hacer visible el módulo Inventory

Para que Inventory aparezca en el sidebar:

1. **Layout.tsx**  
   Añadir a `allItems` algo como:
   ```ts
   { name: 'Inventory', href: '/inventory', icon: Package, module: 'inventory' },
   ```
2. **useAccessContext.ts**  
   Incluir `"inventory"` en `ModuleKey` y decidir para qué `userType` y perfiles va en `allowedModules`.
3. **usePermissions.ts** (si usas RBAC para internal):  
   Añadir en `MODULE_PERMS`:
   ```ts
   inventory: { view: ['inventory.read'], edit: ['inventory.write'] },
   ```
4. Crear permisos `inventory.read` / `inventory.write` en la tabla de permisos y asignarlos a los roles que deban ver/editar inventario.

---

## 2. Por qué la columna Availability puede mostrar "—"

La columna **Availability** (badge de disponibilidad) se alimenta del view `inventory_availability` y del warehouse por defecto. Si todo muestra "—", suele ser por una de estas causas:

| Causa | Explicación |
|--------|-------------|
| **Sin warehouse** | El hook no hace query si no hay `warehouseId`. Si la org no tiene al menos un warehouse (y uno marcado como default), el mapa de availability queda vacío y todos los ítems muestran "—". |
| **Vista sin datos** | El view `inventory_availability` hace FULL JOIN de `inventory_on_hand` e `inventory_on_order`. Solo devuelve filas para ítems que tienen al menos un registro en **InventoryBalances** o en **PurchaseOrders** (líneas con pendiente). Si no hay datos en esas tablas, el view no devuelve filas y todos los badges son "—". |
| **RLS** | El view no tiene RLS propio; usa las tablas base. Si el usuario no pasa las políticas RLS de esas tablas (p. ej. no es “member” de la org vía `is_org_user_member`), no verá filas. |

No es que “no exista” el módulo de inventario a nivel de datos: es que o no está en el menú (sección 1) o, donde sí se usa (Catalog Items, Manufacturing Materials, etc.), la combinación warehouse + datos + RLS hace que no haya filas para mostrar.

---

## 3. RLS para usuarios de inventario

Todas las tablas de inventario usan **Row Level Security** y la función **`public.is_org_user_member(p_org_id uuid)`** para decidir quién ve o modifica filas.

### 3.1 Quién es “member” de la org

`is_org_user_member(organization_id)` devuelve `true` si el usuario actual:

- Está en **OrganizationUsers** para esa `organization_id`, con `deleted = false` y `status IN ('active', 'invited')`, **o**
- Está en **DealerUsers** para esa misma `organization_id`, con `deleted = false` y `status IN ('active', 'invited')`.

Es **SECURITY DEFINER** y usa `search_path = public, auth`, así que no depende de RLS para leer OrganizationUsers/DealerUsers.

### 3.2 Políticas por tabla

Solo usuarios **authenticated** pueden usar estas tablas. En todos los casos, el criterio es que el usuario sea “member” de la organización dueña del dato.

---

#### Warehouses

| Política | Operación | Condición |
|----------|-----------|-----------|
| `warehouses_select_org` | SELECT | `is_org_user_member(organization_id)` |
| `warehouses_insert_org` | INSERT | `is_org_user_member(organization_id)` |
| `warehouses_update_org` | UPDATE | `is_org_user_member(organization_id)` |

No hay DELETE; si se necesita, se puede añadir una política explícita.

---

#### PurchaseOrders

| Política | Operación | Condición |
|----------|-----------|-----------|
| `purchase_orders_select_org` | SELECT | `is_org_user_member(organization_id)` |
| `purchase_orders_insert_org` | INSERT | `is_org_user_member(organization_id)` |
| `purchase_orders_update_org` | UPDATE | `is_org_user_member(organization_id)` |

---

#### PurchaseOrderLines

El acceso se hereda del PO: el usuario debe ser member de la org del PO.

| Política | Operación | Condición |
|----------|-----------|-----------|
| `po_lines_select_via_po` | SELECT | `EXISTS (SELECT 1 FROM PurchaseOrders po WHERE po.id = purchase_order_id AND is_org_user_member(po.organization_id))` |
| `po_lines_insert_via_po` | INSERT | Mismo `EXISTS` con el `purchase_order_id` del insert |
| `po_lines_update_via_po` | UPDATE | Mismo `EXISTS` |

---

#### InventoryBalances

| Política | Operación | Condición |
|----------|-----------|-----------|
| `inv_balances_select_org` | SELECT | `is_org_user_member(organization_id)` |
| `inv_balances_insert_org` | INSERT | `is_org_user_member(organization_id)` |
| `inv_balances_update_org` | UPDATE | `is_org_user_member(organization_id)` |

---

#### InventoryItemProfiles

El permiso se resuelve por el warehouse: el usuario debe ser member de la org del warehouse.

| Política | Operación | Condición |
|----------|-----------|-----------|
| `inv_profiles_select_org` | SELECT | `is_org_user_member((SELECT w.organization_id FROM Warehouses w WHERE w.id = warehouse_id))` |
| `inv_profiles_insert_org` | INSERT | Misma subconsulta con el `warehouse_id` del insert |
| `inv_profiles_update_org` | UPDATE | Misma subconsulta |

---

### 3.3 Vista `inventory_availability`

La vista **no tiene RLS propio**. En Postgres, al hacer `SELECT` sobre la vista se ejecuta la consulta de la vista con el usuario actual; las tablas subyacentes (**inventory_on_hand** → InventoryBalances, **inventory_on_order** → PurchaseOrders/PurchaseOrderLines, **InventoryItemProfiles**) sí tienen RLS. Por tanto:

- El usuario solo ve filas de organizaciones para las que **is_org_user_member(organization_id)** sea verdadero en esas tablas.
- Si un usuario no tiene permiso en Warehouses, InventoryBalances o PurchaseOrders para esa org, no verá filas de la vista para esa org.

### 3.4 Resumen rápido por tipo de usuario

| Usuario | Qué ve en inventario |
|--------|-----------------------|
| **Internal (OrganizationUsers)** | Solo datos de las orgs donde tiene fila en OrganizationUsers (active/invited). |
| **Portal (DealerUsers)** | Solo datos de las orgs donde tiene fila en DealerUsers (active/invited). |
| **SuperAdmin** | No hay bypass especial en estas políticas; sigue siendo member de la org. Si está en OrganizationUsers de la org, ve sus datos; si no, no. |

Para que un usuario “vea todo” inventario de una org, debe ser member de esa org (por OrganizationUsers o DealerUsers). No existe una política tipo “superadmin ve todas las orgs” en las tablas de inventario.

---

## 4. Checklist rápido

- **No aparece el módulo Inventory en el menú**  
  → Añadir ítem a `allItems` en Layout, incluir `inventory` en ModuleKey y, si aplica, en MODULE_PERMS y permisos.

- **Aparece la columna Availability pero todo "—"**  
  → Revisar: (1) que la org tenga al menos un warehouse (y uno default), (2) que existan datos en InventoryBalances o PurchaseOrders para esos ítems, (3) que el usuario sea member de la org (RLS).

- **Error o vacío al consultar la vista**  
  → Revisar políticas RLS de Warehouses, InventoryBalances, PurchaseOrders, PurchaseOrderLines e InventoryItemProfiles y que `is_org_user_member` devuelva true para la org del usuario.

Referencia de migraciones: `20260216_inventory_availability_phase1_tables.sql` (tablas + RLS), `20260215_is_org_user_member_include_dealer_users.sql` (función de membership).
