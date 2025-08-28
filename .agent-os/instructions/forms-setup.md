# Instruction: Forms Setup

## Overview

Implement a comprehensive form system using React Hook Form (RHF) and Zod for validation. This setup should provide type-safe forms with excellent performance and user experience.

## Core Requirements

### 1. Form Management

- React Hook Form for form state management
- Zod schemas for validation
- Type-safe form handling
- Performance optimization

### 2. Validation System

- Client-side validation with Zod
- Real-time validation feedback
- Custom validation rules
- Error message handling

### 3. Form Components

- Reusable form components
- Consistent styling with Tailwind
- Accessibility features
- Error state management

## Implementation Steps

### Step 1: Form Utilities

```typescript
// src/lib/formUtils.ts
import { zodResolver } from "@hookform/resolvers/zod";
import type { Resolver } from "react-hook-form";
import { z } from "zod";

export function createZodResolver<T extends Record<string, any>>(
  schema: z.ZodSchema<T>
): Resolver<T> {
  return zodResolver(schema);
}

export function getFieldError(
  errors: any,
  fieldName: string
): string | undefined {
  const fieldError = errors[fieldName];
  return fieldError?.message;
}

export function isFieldValid(errors: any, fieldName: string): boolean {
  return !errors[fieldName];
}

export function getFormErrors(errors: any): string[] {
  return Object.values(errors)
    .map((error: any) => error?.message)
    .filter(Boolean);
}

export function createFormSchema<T extends Record<string, any>>(
  schema: z.ZodSchema<T>
) {
  return schema;
}
```

### Step 2: Common Validation Schemas

```typescript
// src/lib/validationSchemas.ts
import { z } from "zod";

// Common field validations
export const emailSchema = z
  .string()
  .min(1, "Email is required")
  .email("Invalid email format");

export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .regex(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
    "Password must contain uppercase, lowercase, and number"
  );

export const nameSchema = z
  .string()
  .min(2, "Name must be at least 2 characters")
  .max(50, "Name must be less than 50 characters");

// Form schemas
export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, "Password is required"),
  rememberMe: z.boolean().optional(),
});

export const registerSchema = z
  .object({
    firstName: nameSchema,
    lastName: nameSchema,
    email: emailSchema,
    password: passwordSchema,
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export const profileUpdateSchema = z.object({
  firstName: nameSchema,
  lastName: nameSchema,
  email: emailSchema,
  bio: z.string().max(500, "Bio must be less than 500 characters").optional(),
});

export type LoginForm = z.infer<typeof loginSchema>;
export type RegisterForm = z.infer<typeof registerSchema>;
export type ProfileUpdateForm = z.infer<typeof profileUpdateSchema>;
```

### Step 3: Form Components

```typescript
// src/components/ui/FormField.tsx
import React from "react";
import { useFormContext } from "react-hook-form";
import { cn } from "@/lib/utils";

interface FormFieldProps {
  name: string;
  label: string;
  type?: string;
  placeholder?: string;
  required?: boolean;
  disabled?: boolean;
  className?: string;
  error?: string;
}

export function FormField({
  name,
  label,
  type = "text",
  placeholder,
  required = false,
  disabled = false,
  className,
  error,
}: FormFieldProps) {
  const {
    register,
    formState: { errors },
  } = useFormContext();
  const fieldError = error || getFieldError(errors, name);
  const isValid = isFieldValid(errors, name);

  return (
    <div className="space-y-2">
      <label htmlFor={name} className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </label>

      <input
        {...register(name)}
        type={type}
        id={name}
        placeholder={placeholder}
        disabled={disabled}
        className={cn(
          "block w-full px-3 py-2 border rounded-md shadow-sm",
          "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "disabled:bg-gray-50 disabled:text-gray-500",
          fieldError
            ? "border-red-300 focus:ring-red-500 focus:border-red-500"
            : isValid
            ? "border-green-300 focus:ring-green-500 focus:border-green-500"
            : "border-gray-300",
          className
        )}
      />

      {fieldError && <p className="text-sm text-red-600">{fieldError}</p>}
    </div>
  );
}

// src/components/ui/FormTextarea.tsx
interface FormTextareaProps {
  name: string;
  label: string;
  placeholder?: string;
  required?: boolean;
  disabled?: boolean;
  rows?: number;
  className?: string;
  error?: string;
}

export function FormTextarea({
  name,
  label,
  placeholder,
  required = false,
  disabled = false,
  rows = 4,
  className,
  error,
}: FormTextareaProps) {
  const {
    register,
    formState: { errors },
  } = useFormContext();
  const fieldError = error || getFieldError(errors, name);
  const isValid = isFieldValid(errors, name);

  return (
    <div className="space-y-2">
      <label htmlFor={name} className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </label>

      <textarea
        {...register(name)}
        id={name}
        placeholder={placeholder}
        disabled={disabled}
        rows={rows}
        className={cn(
          "block w-full px-3 py-2 border rounded-md shadow-sm",
          "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          "disabled:bg-gray-50 disabled:text-gray-500",
          fieldError
            ? "border-red-300 focus:ring-red-500 focus:border-red-500"
            : isValid
            ? "border-green-300 focus:ring-green-500 focus:border-green-500"
            : "border-gray-300",
          className
        )}
      />

      {fieldError && <p className="text-sm text-red-600">{fieldError}</p>}
    </div>
  );
}
```

### Step 4: Form Implementation

```typescript
// src/features/auth/forms/LoginForm.tsx
import React from "react";
import { useForm, FormProvider } from "react-hook-form";
import { FormField } from "@/components/ui/FormField";
import { Button } from "@/components/ui/Button";
import { loginSchema, type LoginForm } from "@/lib/validationSchemas";
import { createZodResolver } from "@/lib/formUtils";

export function LoginForm() {
  const methods = useForm<LoginForm>({
    resolver: createZodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
      rememberMe: false,
    },
  });

  const {
    handleSubmit,
    formState: { isSubmitting, errors },
  } = methods;

  const onSubmit = async (data: LoginForm) => {
    try {
      // Handle form submission
      console.log("Form data:", data);
    } catch (error) {
      console.error("Form error:", error);
    }
  };

  return (
    <FormProvider {...methods}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          name="email"
          label="Email"
          type="email"
          placeholder="Enter your email"
          required
        />

        <FormField
          name="password"
          label="Password"
          type="password"
          placeholder="Enter your password"
          required
        />

        <div className="flex items-center">
          <input
            {...methods.register("rememberMe")}
            type="checkbox"
            id="rememberMe"
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label
            htmlFor="rememberMe"
            className="ml-2 block text-sm text-gray-900"
          >
            Remember me
          </label>
        </div>

        <Button type="submit" disabled={isSubmitting} className="w-full">
          {isSubmitting ? "Signing in..." : "Sign in"}
        </Button>

        {Object.keys(errors).length > 0 && (
          <div className="bg-red-50 border border-red-200 rounded-md p-4">
            <h3 className="text-sm font-medium text-red-800">
              Please fix the following errors:
            </h3>
            <ul className="mt-2 text-sm text-red-700 list-disc list-inside">
              {getFormErrors(errors).map((error, index) => (
                <li key={index}>{error}</li>
              ))}
            </ul>
          </div>
        )}
      </form>
    </FormProvider>
  );
}
```

## Best Practices

### 1. Form Performance

- Use React Hook Form for optimal performance
- Implement debounced validation where appropriate
- Avoid unnecessary re-renders
- Use proper memoization

### 2. Validation Strategy

- Validate on blur and submit
- Provide immediate feedback
- Use descriptive error messages
- Implement progressive validation

### 3. Accessibility

- Proper label associations
- Error message announcements
- Keyboard navigation support
- Screen reader compatibility

### 4. User Experience

- Clear error messages
- Loading states
- Success feedback
- Form persistence

## Quality Gates

### 1. Form Functionality

- All form fields work correctly
- Validation triggers appropriately
- Error messages are displayed
- Form submission works

### 2. Type Safety

- TypeScript types are correct
- Zod schemas are properly typed
- Form data is type-safe
- No type errors

### 3. Performance

- Forms render efficiently
- Validation is performant
- No unnecessary re-renders
- Bundle size is optimized

### 4. Accessibility

- Labels are properly associated
- Error messages are announced
- Keyboard navigation works
- Screen readers are supported

## Next Steps

After completing forms setup:

1. Add form testing
2. Implement form persistence
3. Add advanced validation rules
4. Create form templates
5. Add form analytics
