/// <reference types="vite/client" />
// ✅ LOGGER ULTRA-SEGURO: Nunca causa TypeError - Maneja objetos React complejos

type LogArg = unknown;

function safeToString(x: unknown, depth = 0, visited = new WeakSet<object>()): string {
  // Prevenir recursión infinita
  if (depth > 10) return "[max-depth]";
  
  try {
    // Errores primero
    if (x instanceof Error) {
      return x.stack ?? x.message ?? "Error";
    }
    
    // Primitivos
    const t = typeof x;
    if (t === "string") return x as string;
    if (t === "number" || t === "boolean" || t === "bigint") return String(x);
    if (x === null) return "null";
    if (x === undefined) return "undefined";
    
    // Objetos
    if (t === "object" && x !== null) {
      // Evitar referencias circulares
      if (visited.has(x)) {
        return "[circular]";
      }
      visited.add(x);
      
      try {
        // Intentar JSON.stringify con replacer seguro
        return JSON.stringify(x, (key, value) => {
          // Evitar referencias circulares en el replacer
          if (typeof value === "object" && value !== null) {
            if (visited.has(value)) {
              return "[circular]";
            }
            visited.add(value);
  }

          // Convertir bigint
          if (typeof value === "bigint") {
            return value.toString();
          }
          
          // Convertir funciones
          if (typeof value === "function") {
            return `[Function: ${value.name || "anonymous"}]`;
  }

          // Convertir símbolos
          if (typeof value === "symbol") {
            return value.toString();
          }
          
          // Convertir undefined (JSON.stringify lo omite, pero lo manejamos)
          if (value === undefined) {
            return "[undefined]";
  }

          return value;
        }, 2);
      } catch (jsonErr) {
        // Si JSON.stringify falla, intentar toString
        try {
          const str = Object.prototype.toString.call(x);
          // Si es un objeto genérico, intentar extraer propiedades básicas
          if (str === "[object Object]") {
            try {
              const keys = Object.keys(x as object).slice(0, 5); // Solo primeras 5 keys
              return `{${keys.map(k => `${k}: [${typeof (x as any)[k]}]`).join(", ")}}`;
            } catch {
              return str;
            }
          }
          return str;
        } catch {
          return "[unstringifiable]";
        }
      }
    }
    
    // Funciones, símbolos, etc.
    if (t === "function") {
      return `[Function: ${(x as Function).name || "anonymous"}]`;
    }
    if (t === "symbol") {
      return x.toString();
    }
    
    return String(x);
  } catch (e) {
    return "[logger-failed]";
    }
}

function normalizeArgs(args: LogArg[]): string[] {
  // Crear un nuevo WeakSet para cada llamada (se limpia automáticamente)
  const visited = new WeakSet<object>();
  return args.map(arg => safeToString(arg, 0, visited));
}

// Wrapper ultra-seguro para console methods
function safeConsoleCall(
  method: typeof console.error,
  args: string[]
): void {
  try {
    method.apply(console, args as any);
  } catch (e) {
    // Si incluso console.error falla, usar console.log como último recurso
    try {
      console.log("[Logger] Failed to log:", ...args);
    } catch {
      // Si todo falla, no hacer nada (evitar crash)
    }
  }
}

// ✅ CRITICAL: Sobrescribir console methods GLOBALMENTE para evitar TypeError
// Esto protege contra errores de React/librerías que usan console directamente
if (typeof window !== 'undefined') {
  const originalError = console.error;
  const originalWarn = console.warn;
  const originalLog = console.log;
  const originalInfo = console.info;
  const originalDebug = console.debug;
    
  console.error = (...args: any[]) => {
    try {
      originalError.apply(console, normalizeArgs(args) as any);
    } catch (e) {
      originalError('[Logger] console.error failed');
    }
  };

  console.warn = (...args: any[]) => {
    try {
      originalWarn.apply(console, normalizeArgs(args) as any);
    } catch (e) {
      originalWarn('[Logger] console.warn failed');
    }
  };

  console.log = (...args: any[]) => {
    try {
      originalLog.apply(console, normalizeArgs(args) as any);
    } catch (e) {
      originalLog('[Logger] console.log failed');
    }
  };

  console.info = (...args: any[]) => {
    try {
      originalInfo.apply(console, normalizeArgs(args) as any);
    } catch (e) {
      originalInfo('[Logger] console.info failed');
    }
  };
    
  console.debug = (...args: any[]) => {
    try {
      originalDebug.apply(console, normalizeArgs(args) as any);
    } catch (e) {
      originalDebug('[Logger] console.debug failed');
    }
  };
}

export const logger = {
  info: (...args: LogArg[]) => {
    if (import.meta.env.DEV) {
      console.info(...args);
    }
  },
  warn: (...args: LogArg[]) => {
if (import.meta.env.DEV) {
      console.warn(...args);
    }
  },
  error: (...args: LogArg[]) => {
    console.error(...args);
  },
  debug: (...args: LogArg[]) => {
    if (import.meta.env.DEV) {
      console.debug(...args);
    }
  },
  setLogLevel: (level: string) => {}, // No-op for backwards compatibility
};

export default logger;
