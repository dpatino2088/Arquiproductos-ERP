import { cn } from './cn';

type Tone = 'default' | 'success' | 'warning' | 'muted';

const toneClasses: Record<Tone, string> = {
  default: 'bg-secondary text-secondary-foreground',
  success: 'bg-emerald-500/15 text-emerald-700 border border-emerald-100',
  warning: 'bg-amber-500/15 text-amber-700 border border-amber-100',
  muted: 'bg-muted text-muted-foreground border border-border'
};

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  tone?: Tone;
}

export function Badge({ className, tone = 'default', ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium',
        toneClasses[tone],
        className
      )}
      {...props}
    />
  );
}

