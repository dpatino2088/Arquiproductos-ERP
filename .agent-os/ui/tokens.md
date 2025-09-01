# Design Tokens & Theming

## tailwind.config.ts
```ts
import type { Config } from 'tailwindcss';
export default {
  darkMode: ['class'],
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: { DEFAULT: 'hsl(var(--brand-primary))', foreground: 'hsl(var(--primary-foreground))' },
        secondary: { DEFAULT: 'hsl(var(--brand-secondary))', foreground: 'hsl(var(--secondary-foreground))' },
        card: { DEFAULT: 'hsl(var(--card))', foreground: 'hsl(var(--card-foreground))' },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
    },
  },
  plugins: [require('tailwindcss-animate'), require('@tailwindcss/typography')],
} satisfies Config;

```

## src/styles/global.css
```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    /* Layout */
    --sidebar-width: 240px;
    --navbar-height: 56px;

    /* Typography */
    --font-family: 'Inter', 'Helvetica Neue', sans-serif;
    --font-size-body: 14px;
    --font-size-small: 12px;
    --font-size-heading: 16px;
    --font-size-title: 20px;

    /* Primarios */
    --graphite-black: 0 0% 10%;       /* #1A1A1A - Texto principal, íconos oscuros */
    --light-gray: 210 20% 97%;        /* #F5F7FA - Fondo base, áreas amplias */
    --white: 0 0% 100%;               /* #FFFFFF - Tarjetas, superficies elevadas */
    --teal-brand: 174 100% 29%;       /* #009688 - Color de marca, botones primarios */

    /* Base palette (mapped to new colors) */
    --foreground: var(--graphite-black);
    --background: var(--light-gray);
    --brand-primary: var(--teal-brand);
    --brand-secondary: 262 46% 55%;    /* Violet #7E57C2 (static) */

    --primary: var(--brand-primary);
    --primary-foreground: var(--white);
    --secondary: var(--brand-secondary);
    --secondary-foreground: var(--white);

    --card: var(--white);
    --card-foreground: var(--foreground);
    --popover: var(--white);
    --popover-foreground: var(--foreground);
    --muted: var(--light-gray);
    --muted-foreground: 220 9% 46%;   /* #757575 - Muted Gray */
    --accent: var(--brand-primary);
    --accent-foreground: var(--white);
    --destructive: 4 90% 58%;         /* #C62828 - Danger Red */
    --destructive-foreground: var(--white);
    --border: 216 12% 84%;            /* #D6DAE1 - Subtle Border */
    --input: 216 12% 84%;
    --ring: 45 100% 51%;              /* #FFB300 - Focus Ring */
    --radius: 0.5rem;

    /* Sidebar colors */
    --sidebar-light-background: var(--white);
    --sidebar-dark-background: var(--graphite-black);
    --sidebar-background: var(--sidebar-light-background);
    --sidebar-foreground: var(--foreground);

    /* Secundarios / Estados */
    --success-green: 122 39% 49%;     /* #2E7D32 */
    --danger-red: 4 90% 58%;          /* #C62828 */
    --info-blue: 210 79% 46%;         /* #1565C0 */
    --warning-amber: 32 100% 47%;     /* #EF6C00 */

    /* Neutros */
    --secondary-text: 220 9% 46%;     /* #4B4F57 - Secondary Text */
    --muted-gray: 0 0% 46%;           /* #757575 - Placeholders, texto deshabilitado */
    --subtle-border: 216 12% 84%;     /* #D6DAE1 */
    --strong-border: 215 13% 70%;     /* #B8BFCA */

    /* Auxiliares */
    --focus-ring: 45 100% 51%;        /* #FFB300 - Color para indicar foco accesible */
    --row-highlight: 207 44% 92%;     /* #D6EAF8 - Fondos suaves para hover o resaltado */

    /* Legacy status tokens (mapped to new colors) */
    --status-green: #2E7D32;
    --status-red: #C62828;
    --status-blue: #1565C0;
    --status-amber: #EF6C00;
    --neutral-gray: #757575;
    --highlight-bg: #D6EAF8;
  }

  .dark {
    --sidebar-background: var(--sidebar-dark-background);
    --sidebar-foreground: 0 0% 98%;
  }
}

@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground; font-family: var(--font-family); font-size: var(--font-size-body); line-height: 1.5; }

  .btn { height: 32px; padding: 0 12px; font-size: 12px; border-radius: 8px; @apply inline-flex items-center justify-center font-medium transition-colors; }
  .btn-primary { @apply bg-primary text-primary-foreground hover:bg-primary/90; }
  .btn-secondary { @apply bg-background border border-border text-foreground hover:bg-muted; }

  .icon-btn { width: 32px; height: 32px; @apply inline-flex items-center justify-center rounded hover:bg-muted transition-colors; }

  .text-body { font-size: var(--font-size-body); }
  .text-small { font-size: var(--font-size-small); }
  .text-heading { font-size: var(--font-size-heading); }
  .text-title { font-size: var(--font-size-title); }

  /* Status utilities */
  .text-status-green { color: var(--status-green); }
  .text-status-red { color: var(--status-red); }
  .text-status-blue { color: var(--status-blue); }
  .text-status-amber { color: var(--status-amber); }
  .text-neutral-gray { color: var(--neutral-gray); }

  .bg-status-green { background-color: var(--status-green); }
  .bg-status-red { background-color: var(--status-red); }
  .bg-status-blue { background-color: var(--status-blue); }
  .bg-status-amber { background-color: var(--status-amber); }
  .bg-neutral-gray { background-color: var(--neutral-gray); }
  .bg-highlight { background-color: var(--highlight-bg); }

  .bg-status-green-10 { background-color: #1FB6A11A; }
  .bg-status-red-10 { background-color: #D32F2F1A; }
  .bg-status-blue-10 { background-color: #1976D21A; }
  .bg-status-amber-10 { background-color: #F9A8251A; }
  .bg-neutral-gray-10 { background-color: #9E9E9E1A; }
}

```

## src/lib/colors.ts
```ts
export const STATUS = {
  success: 'bg-status-green-10 text-status-green',
  info: 'bg-status-blue-10 text-status-blue',
  warning: 'bg-status-amber-10 text-status-amber',
  error: 'bg-status-red-10 text-status-red',
  neutral: 'bg-neutral-gray-10 text-neutral-gray',
} as const;

export function getStatusClasses(status?: string) {
  if (!status) return STATUS.neutral;
  switch ((status || '').toLowerCase()) {
    case 'completed':
    case 'success':
    case 'active':
    case 'done':
      return STATUS.success;
    case 'in progress':
    case 'processing':
    case 'working':
    case 'info':
      return STATUS.info;
    case 'pending':
    case 'waiting':
    case 'warning':
      return STATUS.warning;
    case 'error':
    case 'failed':
    case 'critical':
    case 'urgent':
      return STATUS.error;
    default:
      return STATUS.neutral;
  }
}

```

## src/lib/theme-init.ts
```ts
export type ViewType = 'personal' | 'manager';

export const APPROVED_ACCENTS = {
  teal: '#14B8A6',
  blue: '#3B82F6',
  indigo: '#6366F1',
  violet: '#8B5CF6',
  emerald: '#10B981',
  amber: '#F59E0B',
  rose: '#F43F5E',
} as const;
export type AccentName = keyof typeof APPROVED_ACCENTS;

export function setPrimaryAccent(name: AccentName) {
  const hex = APPROVED_ACCENTS[name];
  if (!hex) return;
  document.documentElement.style.setProperty('--brand-primary', toHslString(hex));
  try { localStorage.setItem('accent', name); } catch {}
}
export function loadPersistedAccent() {
  try {
    const saved = localStorage.getItem('accent') as AccentName | null;
    if (saved && APPROVED_ACCENTS[saved]) setPrimaryAccent(saved);
  } catch {}
}

export function setView(view: ViewType) {
  try { localStorage.setItem('view', view); } catch {}
  document.documentElement.classList.toggle('dark', view === 'manager');
}
export function applySavedView() {
  try {
    const v = (localStorage.getItem('view') as ViewType) || 'personal';
    document.documentElement.classList.toggle('dark', v === 'manager');
  } catch {}
}

function toHslString(input: string) {
  if (!input) return '';
  if (input.startsWith('#')) {
    const { h, s, l } = hexToHsl(input);
    return `${h} ${s}% ${l}%`;
  }
  return input;
}
function hexToHsl(hex: string) {
  let r = 0, g = 0, b = 0;
  const clean = hex.replace('#', '');
  if (clean.length === 3) {
    r = parseInt(clean[0] + clean[0], 16);
    g = parseInt(clean[1] + clean[1], 16);
    b = parseInt(clean[2] + clean[2], 16);
  } else if (clean.length === 6) {
    r = parseInt(clean.substring(0, 2), 16);
    g = parseInt(clean.substring(2, 4), 16);
    b = parseInt(clean.substring(4, 6), 16);
  }
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0, l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  return { h: Math.round(h * 360), s: Math.round(s * 100), l: Math.round(l * 100) };
}

```

## src/hooks/use-theme.tsx
```tsx
import { createContext, useContext, useState, useEffect, useCallback, useMemo, ReactNode } from 'react';
import { applySavedView, setView, ViewType, loadPersistedAccent } from '@/lib/theme-init';

interface ThemeContextType {
  view: ViewType;
  canManage: boolean;
  isSidebarDark: boolean;
  setViewType: (view: ViewType) => void;
  setCanManage: (can: boolean) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

const getInitialView = (): ViewType => {
  try { const saved = localStorage.getItem('view') as ViewType | null; return saved === 'manager' ? 'manager' : 'personal'; }
  catch { return 'personal'; }
};

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [view, setViewState] = useState<ViewType>(getInitialView);
  const [canManage, setCanManage] = useState<boolean>(true);

  const setViewType = useCallback((v: ViewType) => { setViewState(v); setView(v); }, []);

  useEffect(() => { applySavedView(); loadPersistedAccent(); }, []);

  const isSidebarDark = view === 'manager';
  const value = useMemo(() => ({ view, canManage, isSidebarDark, setViewType, setCanManage }), [view, canManage, isSidebarDark]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within a ThemeProvider');
  return ctx;
}

```
