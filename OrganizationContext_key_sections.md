# OrganizationContext.tsx - Secciones Clave

## 1. Consulta OrganizationUsers (líneas 98-103)

```typescript
// 1) Load memberships (LIST, not maybeSingle)
const { data: membershipsData, error: membershipsError } = await supabase
  .from("OrganizationUsers")
  .select("id, organization_id, user_id, user_email, user_name, role, status, deleted, created_at, updated_at")
  .eq("user_id", user.id)
  .eq("deleted", false)
  .in("status", ["active", "invited"]); // ✅ IMPORTANT
```

## 2. Consulta Organizations (líneas 168-173)

```typescript
// 3) Load organizations by ids
const { data: orgsData, error: orgsError } = await supabase
  .from("Organizations")
  .select("id, name, created_at")
  .in("id", membershipOrgIds)
  .eq("deleted", false)
  .order("created_at", { ascending: false });
```

## 3. setOrganizations (línea 217)

```typescript
setOrganizations(safeOrgs);
```

## 4. setActiveOrganizationId (línea 225)

```typescript
setActiveOrganizationId(nextActive);
```

### Contexto completo alrededor de setActiveOrganizationId (líneas 219-225)

```typescript
// 4) Ensure active org
const stored = localStorage.getItem(STORAGE_KEY);
const storedValid = stored && safeOrgs.some(o => o.id === stored);

let nextActive = storedValid ? stored : (safeOrgs[0]?.id ?? null);

setActiveOrganizationId(nextActive);
```

## Notas

- La consulta a `OrganizationUsers` filtra por `user_id`, `deleted = false` y status `active` o `invited`
- La consulta a `Organizations` usa los `organization_id` obtenidos de los memberships
- `setOrganizations` recibe `safeOrgs` que es un array ordenado por prioridad de rol y nombre
- `setActiveOrganizationId` se establece desde localStorage si es válido, o toma el primer org disponible
