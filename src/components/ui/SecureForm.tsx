import React, { useState, useRef, useEffect } from 'react';
import { sanitizeInput, validateEmail } from '../../lib/security';

interface SecureFormProps {
  onSubmit: (data: { email: string; password: string; name?: string; confirmPassword?: string }) => void;
  type: 'login' | 'register';
  isLoading?: boolean;
  error?: string | null;
  onClearError?: () => void;
}

export const SecureForm: React.FC<SecureFormProps> = ({
  onSubmit,
  type,
  isLoading = false,
  error,
  onClearError
}) => {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    name: '',
    confirmPassword: ''
  });
  
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const formRef = useRef<HTMLFormElement>(null);

  // Clear error when form data changes
  useEffect(() => {
    if (error && onClearError) {
      onClearError();
    }
  }, [formData, error, onClearError]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    const sanitizedValue = sanitizeInput(value);
    
    setFormData(prev => ({ ...prev, [name]: sanitizedValue }));
    
    // Clear validation error for this field
    if (validationErrors[name]) {
      setValidationErrors(prev => ({ ...prev, [name]: '' }));
    }
  };

  const handleBlur = (e: React.FocusEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setTouched(prev => ({ ...prev, [name]: true }));
    
    // Validate on blur
    validateField(name, value);
  };

  const validateField = (name: string, value: string) => {
    let error = '';
    
    switch (name) {
      case 'email':
        if (!value) {
          error = 'Email is required';
        } else if (!validateEmail(value)) {
          error = 'Please enter a valid email address';
        }
        break;
        
      case 'password':
        if (!value) {
          error = 'Password is required';
        } else if (value.length < 8) {
          error = 'Password must be at least 8 characters long';
        }
        break;
        
      case 'name':
        if (type === 'register' && !value) {
          error = 'Name is required';
        }
        break;
        
      case 'confirmPassword':
        if (type === 'register') {
          if (!value) {
            error = 'Please confirm your password';
          } else if (value !== formData.password) {
            error = 'Passwords do not match';
          }
        }
        break;
    }
    
    setValidationErrors(prev => ({ ...prev, [name]: error }));
    return error;
  };

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};
    
    // Validate all fields
    Object.keys(formData).forEach(key => {
      if (type === 'login' && (key === 'name' || key === 'confirmPassword')) {
        return; // Skip these fields for login
      }
      
      const error = validateField(key, formData[key as keyof typeof formData]);
      if (error) {
        errors[key] = error;
      }
    });
    
    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }
    
    // Prepare data based on form type
    const submitData = type === 'login' 
      ? { email: formData.email, password: formData.password }
      : { email: formData.email, password: formData.password, name: formData.name };
    
    onSubmit(submitData);
  };

  const getFieldError = (name: string): string => {
    return touched[name] ? validationErrors[name] || '' : '';
  };

  return (
    <form ref={formRef} onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
          {error}
        </div>
      )}
      
      {type === 'register' && (
        <div>
          <label htmlFor="name" className="block text-sm font-medium text-foreground mb-2">
            Name
          </label>
          <input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleInputChange}
            onBlur={handleBlur}
            className={`w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary ${
              getFieldError('name') ? 'border-red-300' : 'border-border'
            }`}
            placeholder="Enter your name"
            disabled={isLoading}
          />
          {getFieldError('name') && (
            <p className="mt-1 text-sm text-red-600">{getFieldError('name')}</p>
          )}
        </div>
      )}
      
      <div>
        <label htmlFor="email" className="block text-sm font-medium text-foreground mb-2">
          Email
        </label>
        <input
          type="email"
          id="email"
          name="email"
          value={formData.email}
          onChange={handleInputChange}
          onBlur={handleBlur}
          className={`w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary ${
            getFieldError('email') ? 'border-red-300' : 'border-border'
          }`}
          placeholder="Enter your email"
          disabled={isLoading}
          autoComplete="email"
        />
        {getFieldError('email') && (
          <p className="mt-1 text-sm text-red-600">{getFieldError('email')}</p>
        )}
      </div>
      
      <div>
        <label htmlFor="password" className="block text-sm font-medium text-foreground mb-2">
          Password
        </label>
        <input
          type="password"
          id="password"
          name="password"
          value={formData.password}
          onChange={handleInputChange}
          onBlur={handleBlur}
          className={`w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary ${
            getFieldError('password') ? 'border-red-300' : 'border-border'
          }`}
          placeholder="Enter your password"
          disabled={isLoading}
          autoComplete={type === 'login' ? 'current-password' : 'new-password'}
        />
        {getFieldError('password') && (
          <p className="mt-1 text-sm text-red-600">{getFieldError('password')}</p>
        )}
      </div>
      
      {type === 'register' && (
        <div>
          <label htmlFor="confirmPassword" className="block text-sm font-medium text-foreground mb-2">
            Confirm Password
          </label>
          <input
            type="password"
            id="confirmPassword"
            name="confirmPassword"
            value={formData.confirmPassword}
            onChange={handleInputChange}
            onBlur={handleBlur}
            className={`w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary ${
              getFieldError('confirmPassword') ? 'border-red-300' : 'border-border'
            }`}
            placeholder="Confirm your password"
            disabled={isLoading}
            autoComplete="new-password"
          />
          {getFieldError('confirmPassword') && (
            <p className="mt-1 text-sm text-red-600">{getFieldError('confirmPassword')}</p>
          )}
        </div>
      )}
      
      <button
        type="submit"
        disabled={isLoading}
        className="w-full py-2 px-4 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {isLoading ? 'Processing...' : type === 'login' ? 'Sign In' : 'Create Account'}
      </button>
    </form>
  );
};
