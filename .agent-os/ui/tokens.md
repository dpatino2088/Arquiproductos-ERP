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

    /* Tailwind v3 Color Palette */
    --gray-950: #030712;
    --gray-900: #111827;
    --gray-800: #1f2937;
    --gray-700: #374151;
    --gray-600: #4b5563;
    --gray-500: #6b7280;
    --gray-400: #9ca3af;
    --gray-300: #d1d5db;
    --gray-200: #e5e7eb;
    --gray-100: #f3f4f6;
    --gray-50: #f9fafb;
    
    --teal-950: #042f2e;
    --teal-900: #134e4a;
    --teal-800: #115e59;
    --teal-700: #0f766e;  /* Primary brand color */
    --teal-600: #0d9488;
    --teal-500: #14b8a6;
    --teal-400: #2dd4bf;
    --teal-300: #5eead4;
    --teal-200: #99f6e4;
    --teal-100: #ccfbf1;
    --teal-50: #f0fdfa;
    
    --red-950: #450a0a;
    --red-900: #7f1d1d;
    --red-800: #991b1b;
    --red-700: #b91c1c;
    --red-600: #dc2626;
    --red-500: #ef4444;
    --red-400: #f87171;
    --red-300: #fca5a5;
    --red-200: #fecaca;
    --red-100: #fee2e2;
    --red-50: #fef2f2;
    
    --orange-950: #431407;
    --orange-900: #7c2d12;
    --orange-800: #9a3412;
    --orange-700: #c2410c;
    --orange-600: #ea580c;
    --orange-500: #f97316;
    --orange-400: #fb923c;
    --orange-300: #fdba74;
    --orange-200: #fed7aa;
    --orange-100: #ffedd5;
    --orange-50: #fff7ed;
    
    --blue-950: #172554;
    --blue-900: #1e3a8a;
    --blue-800: #1e40af;
    --blue-700: #1d4ed8;
    --blue-600: #2563eb;
    --blue-500: #3b82f6;
    --blue-400: #60a5fa;
    --blue-300: #93c5fd;
    --blue-200: #bfdbfe;
    --blue-100: #dbeafe;
    --blue-50: #eff6ff;
    
    --green-950: #052e16;
    --green-900: #14532d;
    --green-800: #166534;
    --green-700: #15803d;
    --green-600: #16a34a;
    --green-500: #22c55e;
    --green-400: #4ade80;
    --green-300: #86efac;
    --green-200: #bbf7d0;
    --green-100: #dcfce7;
    --green-50: #f0fdf4;

    /* Semantic Color Mapping using Tailwind v3 - UPDATED */
    --foreground: 218 11% 15%;               /* Dark text - HSL for gray-900 */
    --background: 210 20% 98%;               /* Light background - HSL for gray-50 */
    --brand-primary: 174 78% 26%;            /* Primary brand color #0f766e in HSL */
    --brand-secondary: 220 9% 46%;           /* Secondary brand color - HSL for gray-600 */

    --primary: var(--brand-primary);
    --primary-foreground: 210 20% 98%;       /* HSL for gray-50 */
    --secondary: var(--brand-secondary);
    --secondary-foreground: 210 20% 98%;    /* HSL for gray-50 */

    --card: 210 20% 98%;                     /* HSL for gray-50 */
    --card-foreground: var(--foreground);
    --popover: 210 20% 98%;                  /* HSL for gray-50 */
    --popover-foreground: var(--foreground);
    --muted: 220 14% 96%;                    /* HSL for gray-100 */
    --muted-foreground: 220 9% 46%;          /* HSL for gray-500 */
    --accent: var(--brand-primary);
    --accent-foreground: 210 20% 98%;        /* HSL for gray-50 */
    --destructive: 0 84% 60%;                /* HSL for red-600 */
    --destructive-foreground: 210 20% 98%;   /* HSL for gray-50 */
    --border: 220 13% 91%;                   /* HSL for gray-200 */
    --input: 220 13% 91%;                    /* HSL for gray-200 */
    --ring: var(--brand-primary);           /* Focus ring - primary teal */
    --radius: 0.5rem;

    /* Sidebar colors */
    --sidebar-light-background: var(--gray-50);
    --sidebar-dark-background: var(--gray-900);
    --sidebar-background: var(--sidebar-light-background);
    --sidebar-foreground: var(--foreground);

    /* Status colors per design system specification - UPDATED */
    --status-green: #15803d;               /* Success/Active - Green 700 */
    --status-red: #D32F2F;                 /* Error/Critical/Delete */
    --status-blue: #1976D2;                /* Info/Neutral actions */
    --status-amber: #F9A825;               /* Warning/Pending approvals */
    --neutral-gray: #9E9E9E;               /* Disabled/Inactive elements */
    --highlight-bg: #E3F2FD;               /* Hover states, highlighted rows */
    
    /* Utility colors */
    --focus-ring: var(--brand-primary);     /* Focus indicator - primary teal */
    --row-highlight: var(--teal-50);        /* Row hover/highlight */
    
    /* Hex versions for direct usage */
    --teal-brand-hex: var(--teal-700);
    --teal-brand-rgba-10: rgba(15, 118, 110, 0.1);
    --graphite-black-hex: var(--gray-900);
    --white-hex: var(--gray-50);
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

  /* Status utilities using design system colors - UPDATED */
  .text-status-green { color: var(--status-green); }
  .text-status-red { color: var(--status-red); }
  .text-status-blue { color: var(--status-blue); }
  .text-status-orange { color: var(--status-amber); }
  .text-neutral-gray { color: var(--neutral-gray); }

  /* Text utilities */
  .text-secondary { color: var(--gray-600); }
  .text-muted { color: var(--gray-500); }
  
  /* Light background variants for badges using design system colors */
  .bg-status-green-light { background-color: rgba(21, 128, 61, 0.1); }
  .bg-status-red-light { background-color: rgba(211, 47, 47, 0.1); }
  .bg-status-blue-light { background-color: rgba(25, 118, 210, 0.1); }
  .bg-status-orange-light { background-color: rgba(249, 168, 37, 0.1); }

  /* Solid backgrounds */
  .bg-status-green { background-color: var(--status-green); }
  .bg-status-red { background-color: var(--status-red); }
  .bg-status-blue { background-color: var(--status-blue); }
  .bg-status-orange { background-color: var(--status-amber); }
  .bg-neutral-gray { background-color: var(--neutral-gray); }
  .bg-highlight { background-color: var(--highlight-bg); }
  .bg-row-highlight { background-color: var(--row-highlight); }
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
