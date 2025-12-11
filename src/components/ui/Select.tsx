import React, { forwardRef } from 'react';

export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  error?: string;
  options: Array<{ value: string; label: string }>;
}

const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ className = '', error, options, ...props }, ref) => {
    const baseClasses = 'w-full px-2.5 py-1.5 text-xs border rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0 bg-white';
    const normalClasses = 'border-gray-200 focus:ring-primary/20 focus:border-primary/50';
    const errorClasses = 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500';
    
    const selectClasses = `${baseClasses} ${error ? errorClasses : normalClasses} ${className}`;

    return (
      <div className="w-full">
        <select
          ref={ref}
          className={selectClasses}
          {...props}
        >
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        {error && (
          <p className="mt-1 text-xs text-red-600">{error}</p>
        )}
      </div>
    );
  }
);

Select.displayName = 'Select';

export default Select;

