import React from 'react';

export interface RadioGroupProps {
  value: string;
  onChange: (value: string) => void;
  options: Array<{ value: string; label: string }>;
  className?: string;
}

const RadioGroup: React.FC<RadioGroupProps> = ({ 
  value, 
  onChange, 
  options, 
  className = '' 
}) => {
  return (
    <div className={`flex gap-4 ${className}`}>
      {options.map((option) => (
        <label
          key={option.value}
          className="flex items-center gap-2 cursor-pointer"
        >
          <input
            type="radio"
            value={option.value}
            checked={value === option.value}
            onChange={(e) => onChange(e.target.value)}
            className="w-4 h-4 text-primary border-gray-300 focus:ring-2 focus:ring-primary/20 focus:ring-offset-0"
          />
          <span className="text-sm font-medium text-gray-900">{option.label}</span>
        </label>
      ))}
    </div>
  );
};

export default RadioGroup;

