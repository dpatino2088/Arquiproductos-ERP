import { ButtonHTMLAttributes, forwardRef } from 'react';
import { cn } from './cn';

type Variant = 'primary' | 'secondary' | 'ghost' | 'outline' | 'destructive';
type Size = 'sm' | 'md' | 'lg' | 'icon';

const variantClasses: Record<Variant, string> = {
  primary:
    'bg-primary text-primary-foreground shadow-soft hover:opacity-90 focus-visible:ring-2 focus-visible:ring-primary',
  secondary:
    'bg-secondary text-secondary-foreground hover:bg-secondary/90 focus-visible:ring-2 focus-visible:ring-secondary',
  ghost:
    'bg-transparent text-foreground hover:bg-muted focus-visible:ring-2 focus-visible:ring-muted-foreground',
  outline:
    'border border-border text-foreground hover:bg-muted focus-visible:ring-2 focus-visible:ring-primary',
  destructive:
    'bg-destructive text-destructive-foreground hover:bg-destructive/90 focus-visible:ring-2 focus-visible:ring-destructive'
};

const sizeClasses: Record<Size, string> = {
  sm: 'h-8 px-3 text-sm rounded-md',
  md: 'h-10 px-4 text-sm rounded-lg',
  lg: 'h-12 px-5 text-base rounded-lg',
  icon: 'h-10 w-10 rounded-lg flex items-center justify-center'
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { className, variant = 'primary', size = 'md', ...props },
  ref
) {
  return (
    <button
      ref={ref}
      className={cn(
        'inline-flex items-center justify-center font-medium transition-colors focus-visible:outline-none disabled:opacity-60 disabled:cursor-not-allowed',
        variantClasses[variant],
        sizeClasses[size],
        className
      )}
      {...props}
    />
  );
});

