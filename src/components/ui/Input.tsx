import React, { forwardRef } from 'react';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
}

const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className = '', error, ...props }, ref) => {
    const baseClasses = 'w-full px-2.5 py-1.5 text-xs border rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0';
    const normalClasses = 'border-gray-200 bg-gray-50 focus:ring-primary/20 focus:border-primary/50';
    const errorClasses = 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500';
    
    const inputClasses = `${baseClasses} ${error ? errorClasses : normalClasses} ${className}`;

    return (
      <div className="w-full">
        <input
          ref={ref}
          className={inputClasses}
          {...props}
        />
        {error && (
          <p className="mt-1 text-xs text-red-600">{error}</p>
        )}
      </div>
    );
  }
);

Input.displayName = 'Input';

export default Input;

