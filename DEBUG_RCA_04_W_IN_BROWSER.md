# Debug RCA-04-W en el Navegador

## Pasos para diagnosticar:

1. **Abre la consola del navegador** (F12 → Console)

2. **Ejecuta estos comandos en la consola:**

```javascript
// Verificar si el item está en la base de datos
// (Esto requiere acceso a Supabase, pero puedes verificar en la UI)

// Verificar el estado de los items en el componente React
// Abre React DevTools si está disponible

// Verificar directamente en el código
// Busca en la consola los logs que empiezan con "🔍"
```

3. **Busca estos logs específicos:**
   - `🔍 useCatalogItems - Query Results:` → Debe mostrar si RCA-04-W se carga desde la BD
   - `🔍 Items Component - items from hook:` → Debe mostrar si RCA-04-W está en el array de items
   - `🔍 Items.tsx - itemsData mapping:` → Debe mostrar si RCA-04-W está después del mapeo
   - `🔍 RCA-04-W Filter Debug:` → Debe mostrar qué filtro está ocultando RCA-04-W

4. **Si no ves los logs:**
   - Verifica que el código se haya recargado (hard refresh: Cmd+Shift+R)
   - Verifica que no haya errores de JavaScript que impidan la ejecución
   - Verifica que estés en modo desarrollo (los logs deberían aparecer siempre ahora)

5. **Verificar filtros activos:**
   - Revisa si hay algún filtro activo en la UI
   - Verifica que `selectedActive` esté vacío `[]`
   - Verifica que no haya filtros de Manufacturer, Category, Family, etc. activos

## Comandos útiles en la consola:

```javascript
// Ver todos los logs que contienen "RCA"
console.log('Searching for RCA logs...');
// Luego busca en la consola los logs que aparecen

// Ver el estado del componente (si React DevTools está disponible)
// Abre React DevTools → Components → Items → ver el estado
```








