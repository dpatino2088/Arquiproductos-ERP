import { cn } from './cn';

export function Table({ className, ...props }: React.HTMLAttributes<HTMLTableElement>) {
  return (
    <div className="overflow-hidden rounded-xl border border-border shadow-sm">
      <table className={cn('w-full border-collapse text-sm', className)} {...props} />
    </div>
  );
}

export function THead(props: React.HTMLAttributes<HTMLTableSectionElement>) {
  return <thead className="bg-muted/60 text-muted-foreground uppercase text-xs" {...props} />;
}

export function TBody(props: React.HTMLAttributes<HTMLTableSectionElement>) {
  return <tbody className="divide-y divide-border" {...props} />;
}

export function TR(props: React.HTMLAttributes<HTMLTableRowElement>) {
  return <tr className="hover:bg-muted/40 transition-colors" {...props} />;
}

export function TH(props: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return <th className="px-4 py-3 text-left font-semibold" {...props} />;
}

export function TD(props: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return <td className="px-4 py-3 align-middle" {...props} />;
}

