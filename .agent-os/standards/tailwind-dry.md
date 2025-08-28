# Standard: Tailwind DRY

## Overview

Implement DRY (Don't Repeat Yourself) principles with Tailwind CSS through component composition, utility classes, and design system patterns.

## Core Requirements

### 1. Component Composition

- Create reusable component patterns
- Implement consistent spacing and sizing
- Use compound components for complex UIs
- Maintain design system consistency

### 2. Utility Classes

- Create custom utility classes
- Implement consistent color schemes
- Use consistent spacing scales
- Maintain typography hierarchy

### 3. Design System

- Implement consistent component variants
- Use design tokens for values
- Maintain accessibility standards
- Implement responsive design patterns

### 4. Layout Patterns

- Create reusable layout components
- Implement consistent grid systems
- Use consistent spacing patterns
- Maintain responsive behavior

## Implementation Guidelines

### Component Patterns

```typescript
// Button component with variants
interface ButtonProps {
  variant?: "primary" | "secondary" | "outline" | "ghost";
  size?: "sm" | "md" | "lg";
  children: React.ReactNode;
  className?: string;
}

export function Button({
  variant = "primary",
  size = "md",
  children,
  className,
}: ButtonProps) {
  const baseClasses =
    "inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2";

  const variantClasses = {
    primary: "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500",
    secondary: "bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500",
    outline:
      "border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 focus:ring-blue-500",
    ghost: "text-gray-700 hover:bg-gray-100 focus:ring-gray-500",
  };

  const sizeClasses = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base",
  };

  return (
    <button
      className={`${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
    >
      {children}
    </button>
  );
}
```

### Layout Components

```typescript
// Container component
interface ContainerProps {
  children: React.ReactNode;
  maxWidth?: "sm" | "md" | "lg" | "xl" | "2xl";
  className?: string;
}

export function Container({
  children,
  maxWidth = "xl",
  className,
}: ContainerProps) {
  const maxWidthClasses = {
    sm: "max-w-screen-sm",
    md: "max-w-screen-md",
    lg: "max-w-screen-lg",
    xl: "max-w-screen-xl",
    "2xl": "max-w-screen-2xl",
  };

  return (
    <div
      className={`mx-auto px-4 sm:px-6 lg:px-8 ${maxWidthClasses[maxWidth]} ${className}`}
    >
      {children}
    </div>
  );
}

// Stack component for vertical spacing
interface StackProps {
  children: React.ReactNode;
  spacing?: "xs" | "sm" | "md" | "lg" | "xl";
  className?: string;
}

export function Stack({ children, spacing = "md", className }: StackProps) {
  const spacingClasses = {
    xs: "space-y-1",
    sm: "space-y-2",
    md: "space-y-4",
    lg: "space-y-6",
    xl: "space-y-8",
  };

  return (
    <div className={`flex flex-col ${spacingClasses[spacing]} ${className}`}>
      {children}
    </div>
  );
}
```

### Design Tokens

```typescript
// Design tokens for consistent values
export const tokens = {
  colors: {
    primary: {
      50: "#eff6ff",
      500: "#3b82f6",
      600: "#2563eb",
      700: "#1d4ed8",
    },
    gray: {
      50: "#f9fafb",
      100: "#f3f4f6",
      500: "#6b7280",
      600: "#4b5563",
      700: "#374151",
    },
  },
  spacing: {
    xs: "0.25rem",
    sm: "0.5rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
  },
  borderRadius: {
    sm: "0.125rem",
    md: "0.375rem",
    lg: "0.5rem",
    xl: "0.75rem",
  },
} as const;
```

### Responsive Patterns

```typescript
// Responsive grid component
interface GridProps {
  children: React.ReactNode;
  cols?: 1 | 2 | 3 | 4 | 6 | 12;
  gap?: "sm" | "md" | "lg";
  className?: string;
}

export function Grid({ children, cols = 1, gap = "md", className }: GridProps) {
  const colsClasses = {
    1: "grid-cols-1",
    2: "grid-cols-1 sm:grid-cols-2",
    3: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3",
    4: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4",
    6: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6",
    12: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6",
  };

  const gapClasses = {
    sm: "gap-2",
    md: "gap-4",
    lg: "gap-6",
  };

  return (
    <div
      className={`grid ${colsClasses[cols]} ${gapClasses[gap]} ${className}`}
    >
      {children}
    </div>
  );
}
```

## Best Practices

- Use consistent spacing scales throughout
- Implement component variants systematically
- Maintain consistent color schemes
- Use responsive design patterns consistently
- Implement accessibility features
- Document component usage patterns
- Use TypeScript for component props
- Implement proper error boundaries
