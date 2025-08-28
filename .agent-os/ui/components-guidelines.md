inbat# UI Components – Guidelines & Examples

## Alert
```tsx
import { ReactNode } from 'react'
import { STATUS } from '@/lib/colors'
type Variant = 'success' | 'error' | 'info' | 'warning' | 'neutral'
export function Alert({ variant='info', title, children }: { variant?: Variant, title?: string, children?: ReactNode }) {
  const map = { success: STATUS.success, error: STATUS.error, info: STATUS.info, warning: STATUS.warning, neutral: STATUS.neutral } as const
  return (<div className={`w-full rounded-md border border-border p-3 flex items-start gap-3 ${map[variant]}`}>
    <div className="text-sm font-medium">{title}</div>{children && <div className="text-sm opacity-90">{children}</div>}</div>)
}

```

## Modal
```tsx
import { ReactNode } from 'react'
export function Modal({ open, title, children, onClose }: { open: boolean, title?: string, children?: ReactNode, onClose: () => void }) {
  if (!open) return null
  return (<div className="fixed inset-0 z-50 flex items-center justify-center">
    <div className="absolute inset-0 bg-black/30" onClick={onClose} />
    <div className="relative z-10 w-full max-w-md bg-card text-card-foreground rounded-xl border border-border shadow-lg p-4">
      {title && <div className="text-heading font-semibold mb-2">{title}</div>}
      <div className="text-sm">{children}</div>
      <div className="mt-4 flex justify-end gap-2"><button className="btn" onClick={onClose}>Close</button><button className="btn btn-primary" onClick={onClose}>Confirm</button></div>
    </div></div>)
}

```

## ToastProvider
```tsx
import { createContext, useContext, useMemo, useState, ReactNode, useCallback, useEffect } from 'react'
import { STATUS } from '@/lib/colors'
type ToastVariant = 'success' | 'error' | 'info' | 'warning'
type Toast = { id: number, title: string, message?: string, variant: ToastVariant, duration?: number }
const ToastCtx = createContext<{ addToast: (t: Omit<Toast,'id'>) => void } | null>(null)
export function useToast() { const ctx = useContext(ToastCtx); if (!ctx) throw new Error('useToast must be used inside <ToastProvider>'); return ctx }
export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const addToast = useCallback((t: Omit<Toast,'id'>) => { setToasts(prev => [...prev, { id: Date.now() + Math.random(), duration: 3500, ...t }]) }, [])
  useEffect(() => { const timers = toasts.map(t => setTimeout(() => setToasts(prev => prev.filter(x => x.id !== t.id)), t.duration ?? 3500)); return () => { timers.forEach(clearTimeout) } }, [toasts])
  const value = useMemo(() => ({ addToast }), [addToast])
  const variantMap = { success: STATUS.success, error: STATUS.error, info: STATUS.info, warning: STATUS.warning } as const
  return (<ToastCtx.Provider value={value}>{children}
    <div className="fixed bottom-4 right-4 z-50 space-y-2 w-[320px]">
      {toasts.map(t => (<div key={t.id} className={`rounded-md border border-border p-3 shadow-sm ${variantMap[t.variant]}`}>
        <div className="text-sm font-semibold">{t.title}</div>{t.message && <div className="text-xs opacity-90">{t.message}</div>}</div>))}
    </div></ToastCtx.Provider>)
}

```

## NotificationBell
```tsx
import { useState } from 'react'
import { STATUS } from '@/lib/colors'
type Item = { id: number, title: string, detail?: string, variant?: keyof typeof STATUS }
export function NotificationBell() {
  const [open, setOpen] = useState(false)
  const [items] = useState<Item[]>([
    { id: 1, title: 'Timesheet submitted', detail: 'Alex for 08/23 - 08/27', variant: 'info' },
    { id: 2, title: 'Leave approved', detail: 'Maria PTO Aug 29', variant: 'success' },
    { id: 3, title: 'Attendance warning', detail: 'Joan missed clock-in', variant: 'warning' },
  ])
  return (<div className="relative">
    <button className="icon-btn" onClick={() => setOpen(v => !v)} aria-label="Notifications">🔔</button>
    {open && (<div className="absolute right-0 mt-2 w-80 bg-card text-card-foreground border border-border rounded-lg shadow-lg p-2 z-40">
      <div className="text-sm font-medium px-2 py-1">Notifications</div>
      <div className="divide-y divide-border max-h-80 overflow-auto">
        {items.map(i => (<div key={i.id} className={`p-2 text-sm ${i.variant ? STATUS[i.variant] : ''}`}>
          <div className="font-medium">{i.title}</div>{i.detail && <div className="text-xs opacity-80">{i.detail}</div>}</div>))}
      </div>
      <div className="px-2 py-1 text-xs text-muted-foreground">Showing latest 3</div>
    </div>)}
  </div>)
}

```
