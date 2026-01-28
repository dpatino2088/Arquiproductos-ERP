import React, { forwardRef } from 'react';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  error?: string;
}

const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className = '', error, ...props }, ref) => {
    // Estilo underline: solo línea gris inferior pegada al field; sin bordes laterales/superior
    const baseClasses = 'w-full px-0 py-1.5 pb-1 text-xs bg-transparent rounded-none transition-colors focus:outline-none border-0 border-b';
    const normalClasses = 'border-gray-300 focus:border-[var(--primary-brand-hex)] focus:ring-0';
    const errorClasses = 'border-red-500 bg-red-50/50 focus:border-red-500 focus:ring-0';
    
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

