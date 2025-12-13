# 🔧 Solución al Error de Recursión Infinita en OrganizationUsers

## 📋 Descripción del Problema

Estás recibiendo este error al intentar agregar usuarios a tu organización:

```
Error agregando usuario a la organización: infinite recursion detected in policy for relation "OrganizationUsers"
```

**Causa:** Las políticas RLS (Row Level Security) de Supabase están consultando la tabla `OrganizationUsers` dentro de sus propias definiciones, creando un ciclo infinito.

---

## ✅ Solución (Paso a Paso)

### Paso 1: Acceder a Supabase Dashboard

1. Ve a [https://supabase.com](https://supabase.com)
2. Inicia sesión en tu cuenta
3. Selecciona tu proyecto
4. En el menú lateral, haz clic en **"SQL Editor"**

### Paso 2: Ejecutar el Script de Reparación

1. Abre el archivo: `database/migrations/FINAL_FIX_RLS_RECURSION.sql`
2. **Copia TODO el contenido** del archivo
3. En el SQL Editor de Supabase, **pega el código completo**
4. Haz clic en **"Run"** (o presiona `Ctrl+Enter` / `Cmd+Enter`)
5. Espera a que se ejecute completamente

**Deberías ver mensajes como:**
```
✅ Políticas eliminadas correctamente
✅ Migración completada exitosamente
✅ Políticas RLS recreadas sin recursión
✅ Funciones helper configuradas con SECURITY DEFINER
```

### Paso 3: Verificar que Todo Funciona

1. Abre una nueva pestaña en el SQL Editor
2. Copia el contenido del archivo: `database/migrations/VERIFICAR_FIX_RLS.sql`
3. Pégalo y ejecútalo
4. Verifica que veas:
   - ✅ 3 funciones creadas
   - ✅ 6 políticas activas
   - ✅ RLS habilitado

### Paso 4: Probar en tu Aplicación

1. Recarga tu aplicación web (F5 o Cmd+R)
2. Intenta agregar un usuario nuevamente
3. El error de recursión **ya no debería aparecer**

---

## 🔍 ¿Qué Hace el Script?

El script realiza estas acciones:

### 1. **Elimina las políticas problemáticas**
   - Borra todas las políticas RLS existentes que causaban recursión

### 2. **Crea funciones helper especiales**
   - `can_insert_organization_user()`: Verifica permisos para insertar usuarios
   - `can_view_organization_users()`: Verifica permisos para ver usuarios
   - `can_manage_organization_users()`: Verifica permisos para gestionar usuarios

   **Característica clave:** Estas funciones usan:
   - `SECURITY DEFINER`: Se ejecutan con permisos elevados
   - `SET LOCAL row_security = off`: **Desactivan RLS temporalmente** para evitar recursión

### 3. **Recrea políticas simplificadas**
   - Las nuevas políticas **solo llaman a las funciones helper**
   - No consultan directamente `OrganizationUsers`
   - **Eliminan completamente la recursión**

---

## 🎯 Permisos Resultantes

Después de aplicar el fix, tendrás estos permisos:

| Rol | SELECT (Ver) | INSERT (Invitar) | UPDATE (Editar) | DELETE (Eliminar) |
|-----|-------------|------------------|-----------------|-------------------|
| **SuperAdmin** | ✅ Todas las orgs | ✅ Cualquier rol | ✅ Todos | ✅ Todos |
| **Owner** | ✅ Su org | ✅ Todos los roles | ✅ Todos | ✅ Todos |
| **Admin** | ✅ Su org | ✅ Excepto owners | ❌ | ❌ |
| **Member** | ✅ Solo su registro | ❌ | ✅ Solo su registro* | ❌ |

*Los miembros pueden actualizar su información pero **no pueden cambiar su propio rol**.

---

## 🐛 Si el Error Persiste

### Opción 1: Limpiar caché del navegador
```
1. Presiona Ctrl+Shift+Delete (o Cmd+Shift+Delete en Mac)
2. Selecciona "Caché" y "Datos de sitios"
3. Elimina y recarga la página
```

### Opción 2: Verificar que el usuario actual tiene permisos

Ejecuta este query en Supabase SQL Editor (reemplaza los UUIDs):

```sql
SELECT 
  role,
  organization_id,
  user_email
FROM "OrganizationUsers"
WHERE user_id = 'tu-user-id-aquí'::uuid;
```

Verifica que tu usuario tenga rol `owner` o `admin` en la organización.

### Opción 3: Verificar logs de Supabase

1. Ve a **Logs** en el dashboard de Supabase
2. Filtra por "Postgres Logs"
3. Busca errores relacionados con `OrganizationUsers`

---

## 📚 Documentación Técnica

### ¿Por qué SECURITY DEFINER funciona?

```sql
CREATE FUNCTION check_permissions() 
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER  -- 👈 Se ejecuta como el owner de la BD
AS $$
BEGIN
  SET LOCAL row_security = off;  -- 👈 Desactiva RLS temporalmente
  -- Ahora puede consultar OrganizationUsers sin activar las políticas
  ...
END;
$$;
```

**Flujo sin recursión:**
1. Usuario intenta INSERT en `OrganizationUsers`
2. Política RLS llama a `can_insert_organization_user()`
3. La función se ejecuta con `SECURITY DEFINER` y `row_security = off`
4. Consulta `OrganizationUsers` **sin activar políticas RLS**
5. Retorna resultado
6. Política RLS permite o deniega el INSERT

### Diferencia con la implementación anterior

**❌ ANTES (causaba recursión):**
```sql
CREATE POLICY "insert_policy" ON "OrganizationUsers"
FOR INSERT WITH CHECK (
  -- Esta consulta activa las políticas RLS otra vez ❌
  organization_id IN (
    SELECT organization_id 
    FROM "OrganizationUsers"  -- 💥 RECURSIÓN AQUÍ
    WHERE user_id = auth.uid()
  )
);
```

**✅ AHORA (sin recursión):**
```sql
CREATE POLICY "insert_policy" ON "OrganizationUsers"
FOR INSERT WITH CHECK (
  -- Solo llama a la función helper ✅
  can_insert_organization_user(auth.uid(), organization_id, role)
);
```

---

## 🆘 Contacto y Soporte

Si después de aplicar esta solución sigues teniendo problemas:

1. Verifica que ejecutaste **TODO** el script `FINAL_FIX_RLS_RECURSION.sql`
2. Ejecuta el script de verificación `VERIFICAR_FIX_RLS.sql`
3. Revisa los logs de Supabase para errores específicos
4. Comparte los mensajes de error exactos para diagnóstico

---

## ✨ Resumen

| Archivo | Propósito |
|---------|-----------|
| `FINAL_FIX_RLS_RECURSION.sql` | **Script principal** - Aplica la solución completa |
| `VERIFICAR_FIX_RLS.sql` | Verifica que todo esté configurado correctamente |
| `SOLUCION_RECURSION_RLS.md` | Este documento con instrucciones |

**🎯 Resultado esperado:** Después de aplicar el fix, podrás agregar usuarios a tu organización sin errores de recursión infinita.

