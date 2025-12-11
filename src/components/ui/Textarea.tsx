import React, { forwardRef } from 'react';

export interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  error?: string;
}

const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className = '', error, ...props }, ref) => {
    const baseClasses = 'w-full px-2.5 py-1.5 text-xs border rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0 resize-none';
    const normalClasses = 'border-gray-200 bg-gray-50 focus:ring-primary/20 focus:border-primary/50';
    const errorClasses = 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500';
    
    const textareaClasses = `${baseClasses} ${error ? errorClasses : normalClasses} ${className}`;

    return (
      <div className="w-full">
        <textarea
          ref={ref}
          className={textareaClasses}
          {...props}
        />
        {error && (
          <p className="mt-1 text-xs text-red-600">{error}</p>
        )}
      </div>
    );
  }
);

Textarea.displayName = 'Textarea';

export default Textarea;

