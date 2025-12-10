import React, { memo } from 'react';

interface StackProps {
  children: React.ReactNode;
  spacing?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | '2xl';
  direction?: 'vertical' | 'horizontal';
  align?: 'start' | 'center' | 'end' | 'stretch';
  justify?: 'start' | 'center' | 'end' | 'between' | 'around' | 'evenly';
  className?: string;
  wrap?: boolean;
}

const Stack = memo(({
  children,
  spacing = 'md',
  direction = 'vertical',
  align = 'stretch',
  justify = 'start',
  className = '',
  wrap = false,
}: StackProps) => {
  const spacingClasses = {
    vertical: {
      xs: 'space-y-1',
      sm: 'space-y-2',
      md: 'space-y-4',
      lg: 'space-y-6',
      xl: 'space-y-8',
      '2xl': 'space-y-12',
    },
    horizontal: {
      xs: 'space-x-1',
      sm: 'space-x-2',
      md: 'space-x-4',
      lg: 'space-x-6',
      xl: 'space-x-8',
      '2xl': 'space-x-12',
    },
  };

  const alignClasses = {
    start: direction === 'vertical' ? 'items-start' : 'items-start',
    center: 'items-center',
    end: direction === 'vertical' ? 'items-end' : 'items-end',
    stretch: 'items-stretch',
  };

  const justifyClasses = {
    start: 'justify-start',
    center: 'justify-center',
    end: 'justify-end',
    between: 'justify-between',
    around: 'justify-around',
    evenly: 'justify-evenly',
  };

  const directionClasses = {
    vertical: 'flex-col',
    horizontal: 'flex-row',
  };

  const stackClasses = [
    'flex',
    directionClasses[direction],
    spacingClasses[direction][spacing],
    alignClasses[align],
    justifyClasses[justify],
    wrap ? 'flex-wrap' : '',
    className,
  ].filter(Boolean).join(' ');

  return (
    <div className={stackClasses}>
      {children}
    </div>
  );
});

Stack.displayName = 'Stack';

export default Stack;
