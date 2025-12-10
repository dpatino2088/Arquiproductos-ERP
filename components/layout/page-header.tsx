import { ReactNode } from 'react';
import { Button } from '@/components/ui/button';

interface PageHeaderProps {
  title: string;
  description?: string;
  actionLabel?: string;
  actionSlot?: ReactNode;
}

export function PageHeader({ title, description, actionLabel, actionSlot }: PageHeaderProps) {
  return (
    <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <div>
        <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">Arquiproductos</p>
        <h1 className="text-xl font-semibold text-foreground">{title}</h1>
        {description ? <p className="text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {actionSlot ?? (actionLabel ? <Button>{actionLabel}</Button> : null)}
    </div>
  );
}

