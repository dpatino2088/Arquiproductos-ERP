import React, { forwardRef } from 'react';

export interface CheckboxProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(
  ({ className = '', label, error, ...props }, ref) => {
    return (
      <div className="w-full">
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            ref={ref}
            type="checkbox"
            className={`w-4 h-4 text-primary border-gray-300 rounded focus:ring-2 focus:ring-primary/20 focus:ring-offset-0 ${className}`}
            {...props}
          />
          {label && (
            <span className="text-xs text-gray-700">{label}</span>
          )}
        </label>
        {error && (
          <p className="mt-1 text-xs text-red-600">{error}</p>
        )}
      </div>
    );
  }
);

Checkbox.displayName = 'Checkbox';

export default Checkbox;

