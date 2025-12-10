'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Blocks,
  Box,
  Building2,
  Factory,
  Folder,
  Layers,
  LayoutGrid,
  LucideIcon,
  Settings,
  ShoppingCart
} from 'lucide-react';
import { cn } from '@/components/ui/cn';

type NavItem = {
  label: string;
  href: string;
  icon: LucideIcon;
};

const coreNav: NavItem[] = [
  { label: 'Inicio', href: '/(dashboard)', icon: LayoutGrid },
  { label: 'Directorio', href: '/(dashboard)/directory/customers', icon: Folder },
  { label: 'Inventario', href: '/(dashboard)/inventory/warehouses', icon: Box },
  { label: 'Finanzas', href: '/(dashboard)/financials/invoices', icon: Layers },
  { label: 'Configuración', href: '/(dashboard)/settings/item-categories', icon: Settings }
];

const futureNav: NavItem[] = [
  { label: 'Catálogo', href: '/catalog', icon: Blocks },
  { label: 'Ventas', href: '/sales', icon: ShoppingCart },
  { label: 'Manufactura', href: '/manufacturing', icon: Factory },
  { label: 'Empresas', href: '/companies', icon: Building2 }
];

export function Sidebar() {
  const pathname = usePathname();

  const renderLink = (item: NavItem) => {
    const active = pathname.startsWith(item.href);
    return (
      <Link
        key={item.href}
        href={item.href}
        className={cn(
          'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors',
          active
            ? 'bg-primary/10 text-primary border border-primary/20 shadow-soft'
            : 'text-muted-foreground hover:text-foreground hover:bg-muted'
        )}
      >
        <item.icon className="h-4 w-4" />
        <span>{item.label}</span>
      </Link>
    );
  };

  return (
    <aside className="glass sticky top-4 h-[calc(100vh-2rem)] w-64 rounded-2xl p-4">
      <div className="mb-6 px-2">
        <p className="text-xs uppercase text-muted-foreground">Arquiproductos ERP</p>
        <p className="text-lg font-semibold text-foreground">Panel Principal</p>
      </div>
      <div className="space-y-2">
        <p className="px-2 text-[11px] uppercase tracking-[0.08em] text-muted-foreground">
          Núcleo
        </p>
        <div className="space-y-1">{coreNav.map(renderLink)}</div>
      </div>
      <div className="mt-6 space-y-2">
        <p className="px-2 text-[11px] uppercase tracking-[0.08em] text-muted-foreground">
          Próximos módulos
        </p>
        <div className="space-y-1 opacity-50">{futureNav.map(renderLink)}</div>
      </div>
    </aside>
  );
}

