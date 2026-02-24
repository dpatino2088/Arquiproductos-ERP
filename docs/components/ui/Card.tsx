import React, { memo } from 'react';

interface CardProps {
  children: React.ReactNode;
  variant?: 'default' | 'outlined' | 'elevated';
  padding?: 'none' | 'sm' | 'md' | 'lg';
  className?: string;
  hover?: boolean;
  clickable?: boolean;
  onClick?: () => void;
}

const Card = memo(({
  children,
  variant = 'default',
  padding = 'md',
  className = '',
  hover = false,
  clickable = false,
  onClick,
}: CardProps) => {
  const baseClasses = 'bg-white rounded-lg transition-all duration-200';

  const variantClasses = {
    default: 'border border-gray-200',
    outlined: 'border-2 border-gray-300',
    elevated: 'shadow-lg border border-gray-100',
  };

  const paddingClasses = {
    none: '',
    sm: 'p-3',
    md: 'p-4',
    lg: 'p-6',
  };

  const interactionClasses = [
    hover ? 'hover:shadow-md hover:border-gray-300' : '',
    clickable ? 'cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2' : '',
  ].filter(Boolean).join(' ');

  const cardClasses = [
    baseClasses,
    variantClasses[variant],
    paddingClasses[padding],
    interactionClasses,
    className,
  ].filter(Boolean).join(' ');

  const CardElement = clickable ? 'button' : 'div';

  return (
    <CardElement
      className={cardClasses}
      onClick={onClick}
      {...(clickable && { role: 'button', tabIndex: 0 })}
    >
      {children}
    </CardElement>
  );
});

Card.displayName = 'Card';

// Card sub-components
const CardHeader = memo(({ 
  children, 
  className = '' 
}: { 
  children: React.ReactNode; 
  className?: string; 
}) => (
  <div className={`mb-4 ${className}`}>
    {children}
  </div>
));

CardHeader.displayName = 'CardHeader';

const CardTitle = memo(({ 
  children, 
  className = '',
  as: Component = 'h3'
}: { 
  children: React.ReactNode; 
  className?: string;
  as?: 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';
}) => (
  <Component className={`text-lg font-semibold text-gray-900 ${className}`}>
    {children}
  </Component>
));

CardTitle.displayName = 'CardTitle';

const CardContent = memo(({ 
  children, 
  className = '' 
}: { 
  children: React.ReactNode; 
  className?: string; 
}) => (
  <div className={`text-gray-600 ${className}`}>
    {children}
  </div>
));

CardContent.displayName = 'CardContent';

const CardFooter = memo(({ 
  children, 
  className = '' 
}: { 
  children: React.ReactNode; 
  className?: string; 
}) => (
  <div className={`mt-4 ${className}`}>
    {children}
  </div>
));

CardFooter.displayName = 'CardFooter';

// Export compound component
export default Object.assign(Card, {
  Header: CardHeader,
  Title: CardTitle,
  Content: CardContent,
  Footer: CardFooter,
});
