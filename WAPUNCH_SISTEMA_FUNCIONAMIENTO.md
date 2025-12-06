# 🎯 WAPunch - Funcionamiento del Sistema Completo

## 📋 Resumen Ejecutivo

**WAPunch** es una plataforma multi-empresa de control de asistencia basada en **WhatsApp**. Los empleados realizan acciones (Check-In, Check-Out, Breaks, Transfers) mediante comandos de WhatsApp que se procesan automáticamente y se almacenan en Supabase.

---

## 🏗️ Arquitectura del Sistema

### 1. **Multi-Tenant (Multi-Empresa)**
- Cada empresa tiene su propio espacio aislado
- Los datos de una empresa NO son visibles para otra
- Cada empresa tiene sus propios:
  - Empleados
  - Sucursales (branches)
  - Usuarios administrativos
  - Registros de asistencia

### 2. **Sistema de Roles (RBAC)**
```
super_admin  → Control total de la empresa
admin        → Gestión completa (puede crear/editar empleados)
supervisor   → Puede ver datos de empleados, pero no editar
employee     → Solo puede ver sus propios datos
```

### 3. **Estados de Empleados**
Cada empleado tiene un `current_status` que indica su estado actual:
- `out` → No está trabajando (fuera)
- `in` → Está trabajando (check-in realizado)
- `on_break` → Está en descanso
- `on_transfer` → Está en transferencia entre sucursales

---

## 📊 Estructura de Datos

### **Tablas Principales**

#### 1. `companies` - Empresas
- Información básica de cada empresa
- Timezone, país, dirección

#### 2. `company_users` - Usuarios de la Empresa
- Relaciona usuarios de auth.users con empresas
- Define el rol de cada usuario en cada empresa
- Un usuario puede pertenecer a múltiples empresas (con diferentes roles)

#### 3. `employees` - Empleados
- **CRÍTICO**: Cada empleado tiene un `user_id` que lo vincula a `auth.users`
- `whatsapp_number` → Número único para recibir comandos
- `current_status` → Estado actual (out/in/on_break/on_transfer)
- `employee_code` → Código de empleado
- Campos de soft-delete: `is_deleted`, `archived`, `anonymized_at`

#### 4. `branches` - Sucursales
- Cada empresa puede tener múltiples sucursales
- Geofencing: `latitude`, `longitude`, `radius_meters`
- Tipos: `branch` o `site`

#### 5. `attendance_logs` - Registros de Asistencia
- **Log crudo** de cada acción
- Tipos: `check_in`, `check_out`, `start_break`, `end_break`, `start_transfer`, `end_transfer`
- Incluye: timestamp, ubicación GPS, mensaje original de WhatsApp

#### 6. `work_sessions` - Sesiones de Trabajo
- Representa un período completo de trabajo (check-in → check-out)
- Estado: `open` (activa), `closed` (finalizada), `invalid`
- Calcula `duration_minutes` automáticamente

#### 7. `break_sessions` - Sesiones de Descanso
- Descansos dentro de una sesión de trabajo
- Vinculado a un `work_session_id`

#### 8. `transfer_sessions` - Transferencias entre Sucursales
- Movimientos de empleados entre sucursales
- `from_branch_id` → `to_branch_id`

---

## 🔄 Flujo de Funcionamiento

### **Flujo de Check-In (Ejemplo)**

1. **Empleado envía por WhatsApp**: "check in"
2. **n8n procesa el mensaje**:
   - Identifica al empleado por `whatsapp_number`
   - Verifica que `current_status = 'out'` (solo puede hacer check-in si está fuera)
   - Obtiene ubicación GPS del mensaje
   - Valida geofencing (está dentro del radio de alguna sucursal)
3. **Supabase crea registros**:
   - `attendance_logs`: log tipo `check_in`
   - `work_sessions`: nueva sesión con status `open`
   - `employees.current_status`: actualiza a `'in'`

### **Flujo de Break**

1. **Empleado envía**: "start break"
2. **Validación**: `current_status` debe ser `'in'`
3. **Creación**:
   - `attendance_logs`: log tipo `start_break`
   - `break_sessions`: nueva sesión vinculada al `work_session_id` activo
   - `employees.current_status`: actualiza a `'on_break'`
4. **Para terminar break**: "end break"
   - Cierra `break_sessions`
   - `current_status` vuelve a `'in'`

### **Flujo de Transfer**

1. **Empleado envía**: "start transfer to [branch_name]"
2. **Validación**: `current_status` debe ser `'in'`
3. **Creación**:
   - `attendance_logs`: log tipo `start_transfer`
   - `transfer_sessions`: nueva sesión con `from_branch_id` y `to_branch_id`
   - `current_status`: actualiza a `'on_transfer'`
4. **Para terminar transfer**: "end transfer"
   - Cierra `transfer_sessions`
   - `current_status` vuelve a `'in'`

### **Flujo de Check-Out**

1. **Empleado envía**: "check out"
2. **Validación**: `current_status` debe ser `'in'` (no puede estar en break o transfer)
3. **Cierre**:
   - `attendance_logs`: log tipo `check_out`
   - `work_sessions`: actualiza `check_out_time` y calcula `duration_minutes`, status = `'closed'`
   - `employees.current_status`: actualiza a `'out'`

---

## 🔒 Seguridad (RLS - Row Level Security)

### **Principio Base: Deny All**
Todas las tablas empiezan con:
```sql
ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;
CREATE POLICY "deny_all" ON <table> FOR ALL USING (false);
```

### **Reglas de Acceso**

#### **Para Empleados (role = 'employee')**
- ✅ Pueden ver SOLO sus propios datos:
  - Su propio registro en `employees`
  - Sus propios `attendance_logs`
  - Sus propias `work_sessions`, `break_sessions`, `transfer_sessions`
- ❌ NO pueden:
  - Ver datos de otros empleados
  - Crear o modificar registros (eso lo hace el bot de WhatsApp)

#### **Para Supervisores (role = 'supervisor')**
- ✅ Pueden ver:
  - Todos los empleados de su empresa
  - Todos los logs de asistencia de su empresa
  - Todas las sesiones de su empresa
- ❌ NO pueden:
  - Crear o editar empleados
  - Modificar registros de asistencia

#### **Para Admins (role = 'admin' o 'super_admin')**
- ✅ Pueden:
  - Ver todo lo que los supervisores
  - Crear y editar empleados
  - Ver y gestionar sucursales
  - Ver reportes completos
- ⚠️ **Importante**: Los logs de asistencia se crean automáticamente por el bot (usando `service_role`), no manualmente por admins

---

## 🎨 Funcionalidades de la UI

### **Dashboard Principal**
- **Para Admins/Supervisores**:
  - Total de empleados activos
  - Empleados actualmente trabajando (`current_status = 'in'`)
  - Empleados en descanso (`current_status = 'on_break'`)
  - Empleados en transferencia (`current_status = 'on_transfer'`)
  - Estadísticas de asistencia del día/semana/mes

### **"Who's Working" (Quién Está Trabajando)**
- Lista en tiempo real de empleados con `current_status != 'out'`
- Muestra:
  - Nombre, posición, sucursal
  - Estado actual (in/on_break/on_transfer)
  - Última actividad (check-in, start break, etc.)
  - Ubicación GPS (si está disponible)
  - Tiempo desde última actividad

### **"Team Attendance" (Asistencia del Equipo)**
- Vista de calendario/semanal
- Muestra sesiones de trabajo de todos los empleados
- Filtros por:
  - Sucursal
  - Departamento
  - Rango de fechas
- Detalles de cada sesión:
  - Check-in time
  - Check-out time
  - Duración total
  - Breaks tomados
  - Transfers realizados

### **"Employee Timesheet" (Hoja de Tiempo del Empleado)**
- Vista individual de un empleado
- Historial completo de:
  - Work sessions
  - Break sessions
  - Transfer sessions
- Estadísticas:
  - Horas trabajadas por día/semana/mes
  - Promedio de horas
  - Tiempo total en breaks

### **"Directory" (Directorio de Empleados)**
- Lista de todos los empleados de la empresa
- Filtros y búsqueda
- Información:
  - Nombre, código, posición
  - Estado actual (`current_status`)
  - WhatsApp number
  - Sucursal asignada
- Acciones (solo admins):
  - Crear nuevo empleado
  - Editar empleado
  - Archivar/Activar empleado

### **"Branches" (Sucursales)**
- Gestión de sucursales
- Configuración de geofencing:
  - Latitud, Longitud
  - Radio en metros
- Lista de empleados por sucursal

### **"Attendance Flags" (Banderas de Asistencia)**
- Alertas y anomalías:
  - Empleados con check-in pero sin check-out (sesiones abiertas)
  - Breaks muy largos
  - Check-ins fuera del horario esperado
  - Check-ins fuera del geofencing

---

## 🔌 Integración con Supabase

### **Queries Principales**

#### **Obtener empleados activos trabajando**
```typescript
const { data } = await supabase
  .from('employees')
  .select('*, branches(*)')
  .eq('company_id', companyId)
  .eq('is_active', true)
  .eq('is_deleted', false)
  .in('current_status', ['in', 'on_break', 'on_transfer']);
```

#### **Obtener sesiones de trabajo de un empleado**
```typescript
const { data } = await supabase
  .from('work_sessions')
  .select('*, break_sessions(*), transfer_sessions(*)')
  .eq('employee_id', employeeId)
  .eq('status', 'closed')
  .order('check_in_time', { ascending: false });
```

#### **Obtener logs de asistencia recientes**
```typescript
const { data } = await supabase
  .from('attendance_logs')
  .select('*, employees(first_name, last_name)')
  .eq('company_id', companyId)
  .order('log_time', { ascending: false })
  .limit(50);
```

### **Autenticación y Contexto de Usuario**

1. **Usuario se autentica** → `auth.users`
2. **Obtener su rol en la empresa**:
   ```typescript
   const { data: companyUser } = await supabase
     .from('company_users')
     .select('*, companies(*)')
     .eq('user_id', userId)
     .eq('is_deleted', false)
     .single();
   ```
3. **Obtener empleado asociado** (si es empleado):
   ```typescript
   const { data: employee } = await supabase
     .from('employees')
     .select('*')
     .eq('user_id', userId)
     .eq('is_deleted', false)
     .single();
   ```

---

## ⚠️ Consideraciones Importantes

### **1. Multi-Tenant Isolation**
- **SIEMPRE** filtrar por `company_id` en todas las queries
- El RLS ayuda, pero es mejor ser explícito

### **2. Estados Válidos**
- Validar `current_status` antes de permitir acciones
- Un empleado con `current_status = 'on_break'` NO puede hacer check-out directamente
- Debe terminar el break primero

### **3. Sesiones Abiertas**
- Verificar que no haya `work_sessions` con `status = 'open'` antes de crear una nueva
- Un empleado solo puede tener UNA sesión de trabajo abierta a la vez

### **4. Soft Deletes**
- Siempre filtrar `is_deleted = false` y `archived = false`
- Los datos nunca se eliminan físicamente (GDPR compliance)

### **5. WhatsApp Integration**
- La UI NO crea registros de asistencia directamente
- Los registros se crean automáticamente vía n8n → Supabase
- La UI solo **lee y visualiza** los datos

---

## 📱 Comandos de WhatsApp (Referencia)

| Comando | Estado Requerido | Resultado |
|---------|------------------|------------|
| `check in` | `out` | Crea work_session, status → `in` |
| `check out` | `in` | Cierra work_session, status → `out` |
| `start break` | `in` | Crea break_session, status → `on_break` |
| `end break` | `on_break` | Cierra break_session, status → `in` |
| `start transfer to [branch]` | `in` | Crea transfer_session, status → `on_transfer` |
| `end transfer` | `on_transfer` | Cierra transfer_session, status → `in` |

---

## 🎯 Próximos Pasos para la UI

1. **Crear tipos TypeScript** basados en el esquema
2. **Crear hooks de Supabase** para cada entidad
3. **Actualizar Dashboard** con datos reales
4. **Conectar "Who's Working"** con datos reales
5. **Implementar filtros y búsquedas** con RLS
6. **Crear formularios de gestión** (solo admins)
7. **Implementar visualización de geofencing** en mapas

---

**Este documento es la base para entender cómo debe funcionar WAPunch antes de ajustar la UI.**

