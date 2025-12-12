import React from 'react';

export interface LabelProps extends React.LabelHTMLAttributes<HTMLLabelElement> {
  required?: boolean;
}

const Label: React.FC<LabelProps> = ({ 
  children, 
  className = '', 
  required = false,
  ...props 
}) => {
  return (
    <label
      className={`block text-sm font-medium text-gray-900 mb-0.5 ${className}`}
      {...props}
    >
      {children}
      {required && <span className="text-red-600 ml-1">*</span>}
    </label>
  );
};

export default Label;

