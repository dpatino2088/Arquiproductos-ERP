# Instruction: Tailwind Design System Setup

## Overview

Implement a comprehensive design system using Tailwind CSS that provides consistent, reusable components and utilities. This setup should include component patterns, design tokens, and a systematic approach to building user interfaces.

## Core Requirements

### 1. Design System Foundation

- Design tokens and variables
- Component patterns and variants
- Utility-first approach
- Consistent spacing and typography

### 2. Component Library

- Base components (Button, Input, Card)
- Layout components (Container, Grid, Stack)
- Complex components (Modal, Dropdown, Table)
- Component variants and states

### 3. Design Patterns

- Consistent spacing system
- Typography scale
- Color palette
- Shadow and elevation system

## Implementation Steps

### Step 1: Design Tokens and Configuration

```typescript
// tailwind.config.ts
import type { Config } from "tailwindcss";
import plugin from "tailwindcss/plugin";

export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Primary color palette
        primary: {
          50: "#eff6ff",
          100: "#dbeafe",
          200: "#bfdbfe",
          300: "#93c5fd",
          400: "#60a5fa",
          500: "#3b82f6",
          600: "#2563eb",
          700: "#1d4ed8",
          800: "#1e40af",
          900: "#1e3a8a",
          950: "#172554",
        },
        // Secondary color palette
        secondary: {
          50: "#f8fafc",
          100: "#f1f5f9",
          200: "#e2e8f0",
          300: "#cbd5e1",
          400: "#94a3b8",
          500: "#64748b",
          600: "#475569",
          700: "#334155",
          800: "#1e293b",
          900: "#0f172a",
          950: "#020617",
        },
        // Success, warning, error colors
        success: {
          50: "#f0fdf4",
          100: "#dcfce7",
          200: "#bbf7d0",
          300: "#86efac",
          400: "#4ade80",
          500: "#22c55e",
          600: "#16a34a",
          700: "#15803d",
          800: "#166534",
          900: "#14532d",
        },
        warning: {
          50: "#fffbeb",
          100: "#fef3c7",
          200: "#fde68a",
          300: "#fcd34d",
          400: "#fbbf24",
          500: "#f59e0b",
          600: "#d97706",
          700: "#b45309",
          800: "#92400e",
          900: "#78350f",
        },
        error: {
          50: "#fef2f2",
          100: "#fee2e2",
          200: "#fecaca",
          300: "#fca5a5",
          400: "#f87171",
          500: "#ef4444",
          600: "#dc2626",
          700: "#b91c1c",
          800: "#991b1b",
          900: "#7f1d1d",
        },
      },
      spacing: {
        // Custom spacing scale
        "18": "4.5rem",
        "88": "22rem",
        "128": "32rem",
      },
      fontSize: {
        // Custom typography scale
        xs: ["0.75rem", { lineHeight: "1rem" }],
        sm: ["0.875rem", { lineHeight: "1.25rem" }],
        base: ["1rem", { lineHeight: "1.5rem" }],
        lg: ["1.125rem", { lineHeight: "1.75rem" }],
        xl: ["1.25rem", { lineHeight: "1.75rem" }],
        "2xl": ["1.5rem", { lineHeight: "2rem" }],
        "3xl": ["1.875rem", { lineHeight: "2.25rem" }],
        "4xl": ["2.25rem", { lineHeight: "2.5rem" }],
        "5xl": ["3rem", { lineHeight: "1" }],
        "6xl": ["3.75rem", { lineHeight: "1" }],
        "7xl": ["4.5rem", { lineHeight: "1" }],
        "8xl": ["6rem", { lineHeight: "1" }],
        "9xl": ["8rem", { lineHeight: "1" }],
      },
      fontFamily: {
        // Custom font families
        sans: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "monospace"],
      },
      boxShadow: {
        // Custom shadow system
        sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
        DEFAULT:
          "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
        md: "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
        lg: "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
        xl: "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)",
        "2xl": "0 25px 50px -12px rgb(0 0 0 / 0.25)",
        inner: "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)",
        none: "none",
      },
      borderRadius: {
        // Custom border radius scale
        "4xl": "2rem",
        "5xl": "2.5rem",
      },
      animation: {
        // Custom animations
        "fade-in": "fadeIn 0.5s ease-in-out",
        "slide-up": "slideUp 0.3s ease-out",
        "slide-down": "slideDown 0.3s ease-out",
        "scale-in": "scaleIn 0.2s ease-out",
        "bounce-in": "bounceIn 0.6s ease-out",
      },
      keyframes: {
        // Custom keyframes
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        slideUp: {
          "0%": { transform: "translateY(10px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        slideDown: {
          "0%": { transform: "translateY(-10px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        scaleIn: {
          "0%": { transform: "scale(0.95)", opacity: "0" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
        bounceIn: {
          "0%": { transform: "scale(0.3)", opacity: "0" },
          "50%": { transform: "scale(1.05)" },
          "70%": { transform: "scale(0.9)" },
          "100%": { transform: "scale(1)", opacity: "1" },
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/line-clamp"),
    require("@tailwindcss/aspect-ratio"),
    // Custom plugin for design system utilities
    plugin(({ addUtilities, addComponents, theme }) => {
      // Add custom utilities
      addUtilities({
        ".text-balance": {
          "text-wrap": "balance",
        },
        ".text-pretty": {
          "text-wrap": "pretty",
        },
        ".scrollbar-hide": {
          "-ms-overflow-style": "none",
          "scrollbar-width": "none",
          "&::-webkit-scrollbar": {
            display: "none",
          },
        },
      });

      // Add custom components
      addComponents({
        ".btn": {
          display: "inline-flex",
          "align-items": "center",
          "justify-content": "center",
          "border-radius": theme("borderRadius.md"),
          "font-weight": theme("fontWeight.medium"),
          "transition-property":
            "color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, filter, backdrop-filter",
          "transition-timing-function": "cubic-bezier(0.4, 0, 0.2, 1)",
          "transition-duration": "150ms",
          "&:focus-visible": {
            outline: "2px solid transparent",
            "outline-offset": "2px",
            "box-shadow":
              "0 0 0 2px rgb(255 255 255), 0 0 0 4px rgb(59 130 246)",
          },
        },
        ".btn-primary": {
          "background-color": theme("colors.primary.600"),
          color: theme("colors.white"),
          "&:hover": {
            "background-color": theme("colors.primary.700"),
          },
          "&:active": {
            "background-color": theme("colors.primary.800"),
          },
        },
        ".btn-secondary": {
          "background-color": theme("colors.secondary.100"),
          color: theme("colors.secondary.900"),
          border: `1px solid ${theme("colors.secondary.300")}`,
          "&:hover": {
            "background-color": theme("colors.secondary.200"),
          },
        },
        ".card": {
          "background-color": theme("colors.white"),
          "border-radius": theme("borderRadius.lg"),
          "box-shadow": theme("boxShadow.DEFAULT"),
          border: `1px solid ${theme("colors.secondary.200")}`,
        },
        ".input": {
          width: "100%",
          "border-radius": theme("borderRadius.md"),
          border: `1px solid ${theme("colors.secondary.300")}`,
          padding: `${theme("spacing.3")} ${theme("spacing.4")}`,
          "font-size": theme("fontSize.base"),
          "line-height": theme("fontSize.base.lineHeight"),
          "transition-property":
            "color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, filter, backdrop-filter",
          "transition-timing-function": "cubic-bezier(0.4, 0, 0.2, 1)",
          "transition-duration": "150ms",
          "&:focus": {
            outline: "2px solid transparent",
            "outline-offset": "2px",
            "border-color": theme("colors.primary.500"),
            "box-shadow": `0 0 0 3px ${theme("colors.primary.100")}`,
          },
        },
      });
    }),
  ],
} satisfies Config;
```

### Step 2: Base Components

```typescript
// src/components/ui/Button.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "outline" | "ghost" | "danger";
  size?: "sm" | "md" | "lg" | "xl";
  loading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export function Button({
  variant = "primary",
  size = "md",
  loading = false,
  leftIcon,
  rightIcon,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  const baseClasses =
    "btn inline-flex items-center justify-center font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none";

  const variantClasses = {
    primary: "btn-primary",
    secondary: "btn-secondary",
    outline:
      "border border-secondary-300 bg-white text-secondary-900 hover:bg-secondary-50",
    ghost: "text-secondary-700 hover:bg-secondary-100",
    danger: "bg-error-600 text-white hover:bg-error-700",
  };

  const sizeClasses = {
    sm: "h-8 px-3 text-sm",
    md: "h-10 px-4 text-sm",
    lg: "h-11 px-8 text-base",
    xl: "h-12 px-10 text-base",
  };

  const classes = cn(
    baseClasses,
    variantClasses[variant],
    sizeClasses[size],
    className
  );

  return (
    <button className={classes} disabled={disabled || loading} {...props}>
      {loading && (
        <svg
          className="animate-spin -ml-1 mr-2 h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
      )}
      {!loading && leftIcon && <span className="mr-2">{leftIcon}</span>}
      {children}
      {!loading && rightIcon && <span className="ml-2">{rightIcon}</span>}
    </button>
  );
}

// src/components/ui/Input.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  helperText?: string;
}

export function Input({
  label,
  error,
  leftIcon,
  rightIcon,
  helperText,
  className,
  id,
  ...props
}: InputProps) {
  const inputId = id || `input-${Math.random().toString(36).substr(2, 9)}`;

  const inputClasses = cn(
    "input",
    "w-full",
    leftIcon && "pl-10",
    rightIcon && "pr-10",
    error && "border-error-500 focus:border-error-500 focus:ring-error-200",
    className
  );

  return (
    <div className="space-y-2">
      {label && (
        <label
          htmlFor={inputId}
          className="block text-sm font-medium text-secondary-700"
        >
          {label}
        </label>
      )}

      <div className="relative">
        {leftIcon && (
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <span className="text-secondary-400">{leftIcon}</span>
          </div>
        )}

        <input id={inputId} className={inputClasses} {...props} />

        {rightIcon && (
          <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
            <span className="text-secondary-400">{rightIcon}</span>
          </div>
        )}
      </div>

      {error && <p className="text-sm text-error-600">{error}</p>}

      {helperText && !error && (
        <p className="text-sm text-secondary-500">{helperText}</p>
      )}
    </div>
  );
}

// src/components/ui/Card.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: "default" | "elevated" | "outlined";
  padding?: "none" | "sm" | "md" | "lg";
}

export function Card({
  variant = "default",
  padding = "md",
  className,
  children,
  ...props
}: CardProps) {
  const baseClasses = "card";

  const variantClasses = {
    default: "bg-white border border-secondary-200",
    elevated: "bg-white shadow-lg border-0",
    outlined: "bg-transparent border-2 border-secondary-200",
  };

  const paddingClasses = {
    none: "",
    sm: "p-4",
    md: "p-6",
    lg: "p-8",
  };

  const classes = cn(
    baseClasses,
    variantClasses[variant],
    paddingClasses[padding],
    className
  );

  return (
    <div className={classes} {...props}>
      {children}
    </div>
  );
}

// Card sub-components
Card.Header = function CardHeader({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("flex flex-col space-y-1.5 pb-4", className)}
      {...props}
    />
  );
};

Card.Title = function CardTitle({
  className,
  ...props
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={cn(
        "text-lg font-semibold leading-none tracking-tight",
        className
      )}
      {...props}
    />
  );
};

Card.Description = function CardDescription({
  className,
  ...props
}: React.HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p className={cn("text-sm text-secondary-600", className)} {...props} />
  );
};

Card.Content = function CardContent({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("pt-0", className)} {...props} />;
};

Card.Footer = function CardFooter({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("flex items-center pt-4", className)} {...props} />;
};
```

### Step 3: Layout Components

```typescript
// src/components/layout/Container.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface ContainerProps extends React.HTMLAttributes<HTMLDivElement> {
  size?: "sm" | "md" | "lg" | "xl" | "full";
  centered?: boolean;
}

export function Container({
  size = "lg",
  centered = true,
  className,
  children,
  ...props
}: ContainerProps) {
  const sizeClasses = {
    sm: "max-w-3xl",
    md: "max-w-4xl",
    lg: "max-w-6xl",
    xl: "max-w-7xl",
    full: "max-w-none",
  };

  const classes = cn(
    "w-full mx-auto px-4 sm:px-6 lg:px-8",
    sizeClasses[size],
    centered && "text-center",
    className
  );

  return (
    <div className={classes} {...props}>
      {children}
    </div>
  );
}

// src/components/layout/Stack.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface StackProps extends React.HTMLAttributes<HTMLDivElement> {
  direction?: "vertical" | "horizontal";
  spacing?: "none" | "xs" | "sm" | "md" | "lg" | "xl";
  align?: "start" | "center" | "end" | "stretch";
  justify?: "start" | "center" | "end" | "between" | "around" | "evenly";
  wrap?: boolean;
}

export function Stack({
  direction = "vertical",
  spacing = "md",
  align = "start",
  justify = "start",
  wrap = false,
  className,
  children,
  ...props
}: StackProps) {
  const directionClasses = {
    vertical: "flex flex-col",
    horizontal: "flex flex-row",
  };

  const spacingClasses = {
    none: "",
    xs: direction === "vertical" ? "space-y-1" : "space-x-1",
    sm: direction === "vertical" ? "space-y-2" : "space-x-2",
    md: direction === "vertical" ? "space-y-4" : "space-x-4",
    lg: direction === "vertical" ? "space-y-6" : "space-x-6",
    xl: direction === "vertical" ? "space-y-8" : "space-x-8",
  };

  const alignClasses = {
    start: "items-start",
    center: "items-center",
    end: "items-end",
    stretch: "items-stretch",
  };

  const justifyClasses = {
    start: "justify-start",
    center: "justify-center",
    end: "justify-end",
    between: "justify-between",
    around: "justify-around",
    evenly: "justify-evenly",
  };

  const classes = cn(
    directionClasses[direction],
    spacingClasses[spacing],
    alignClasses[align],
    justifyClasses[justify],
    wrap && "flex-wrap",
    className
  );

  return (
    <div className={classes} {...props}>
      {children}
    </div>
  );
}

// src/components/layout/Grid.tsx
import React from "react";
import { cn } from "@/lib/utils";

interface GridProps extends React.HTMLAttributes<HTMLDivElement> {
  cols?: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12;
  gap?: "none" | "xs" | "sm" | "md" | "lg" | "xl";
  responsive?: boolean;
}

export function Grid({
  cols = 12,
  gap = "md",
  responsive = true,
  className,
  children,
  ...props
}: GridProps) {
  const gapClasses = {
    none: "",
    xs: "gap-1",
    sm: "gap-2",
    md: "gap-4",
    lg: "gap-6",
    xl: "gap-8",
  };

  const responsiveClasses = responsive
    ? {
        1: "grid-cols-1",
        2: "grid-cols-1 sm:grid-cols-2",
        3: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3",
        4: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4",
        5: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-5",
        6: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6",
        7: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7",
        8: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-8",
        9: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-9",
        10: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 xl:grid-cols-10",
        11: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-6 2xl:grid-cols-11",
        12: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-6 2xl:grid-cols-12",
      }
    : {
        1: "grid-cols-1",
        2: "grid-cols-2",
        3: "grid-cols-3",
        4: "grid-cols-4",
        5: "grid-cols-5",
        6: "grid-cols-6",
        7: "grid-cols-7",
        8: "grid-cols-8",
        9: "grid-cols-9",
        10: "grid-cols-10",
        11: "grid-cols-11",
        12: "grid-cols-12",
      };

  const classes = cn(
    "grid",
    responsiveClasses[cols],
    gapClasses[gap],
    className
  );

  return (
    <div className={classes} {...props}>
      {children}
    </div>
  );
}

// Grid item component
Grid.Item = function GridItem({
  span = 1,
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & {
  span?: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12;
}) {
  const spanClasses = {
    1: "col-span-1",
    2: "col-span-2",
    3: "col-span-3",
    4: "col-span-4",
    5: "col-span-5",
    6: "col-span-6",
    7: "col-span-7",
    8: "col-span-8",
    9: "col-span-9",
    10: "col-span-10",
    11: "col-span-11",
    12: "col-span-12",
  };

  const classes = cn(spanClasses[span], className);

  return (
    <div className={classes} {...props}>
      {children}
    </div>
  );
};
```

### Step 4: Complex Components

```typescript
// src/components/ui/Modal.tsx
import React, { useEffect, useRef } from "react";
import { createPortal } from "react-dom";
import { cn } from "@/lib/utils";
import { Button } from "./Button";

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  size?: "sm" | "md" | "lg" | "xl" | "full";
  closeOnOverlayClick?: boolean;
  closeOnEscape?: boolean;
  showCloseButton?: boolean;
}

export function Modal({
  isOpen,
  onClose,
  title,
  children,
  size = "md",
  closeOnOverlayClick = true,
  closeOnEscape = true,
  showCloseButton = true,
}: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isOpen) return;

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape" && closeOnEscape) {
        onClose();
      }
    };

    document.addEventListener("keydown", handleEscape);
    document.body.style.overflow = "hidden";

    return () => {
      document.removeEventListener("keydown", handleEscape);
      document.body.style.overflow = "unset";
    };
  }, [isOpen, onClose, closeOnEscape]);

  const handleOverlayClick = (event: React.MouseEvent) => {
    if (event.target === event.currentTarget && closeOnOverlayClick) {
      onClose();
    }
  };

  const sizeClasses = {
    sm: "max-w-md",
    md: "max-w-lg",
    lg: "max-w-2xl",
    xl: "max-w-4xl",
    full: "max-w-none mx-4",
  };

  if (!isOpen) return null;

  const modalContent = (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Overlay */}
      <div
        className="fixed inset-0 bg-black/50 backdrop-blur-sm"
        onClick={handleOverlayClick}
      />

      {/* Modal */}
      <div
        ref={modalRef}
        className={cn(
          "relative bg-white rounded-lg shadow-xl w-full",
          sizeClasses[size]
        )}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? "modal-title" : undefined}
      >
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between p-6 border-b border-secondary-200">
            {title && (
              <h2
                id="modal-title"
                className="text-lg font-semibold text-secondary-900"
              >
                {title}
              </h2>
            )}
            {showCloseButton && (
              <Button
                variant="ghost"
                size="sm"
                onClick={onClose}
                className="ml-auto"
                aria-label="Close modal"
              >
                <svg
                  className="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </Button>
            )}
          </div>
        )}

        {/* Content */}
        <div className="p-6">{children}</div>
      </div>
    </div>
  );

  return createPortal(modalContent, document.body);
}

// src/components/ui/Dropdown.tsx
import React, { useState, useRef, useEffect } from "react";
import { cn } from "@/lib/utils";
import { Button } from "./Button";

interface DropdownProps {
  trigger: React.ReactNode;
  children: React.ReactNode;
  align?: "left" | "right" | "center";
  className?: string;
}

export function Dropdown({
  trigger,
  children,
  align = "left",
  className,
}: DropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const alignClasses = {
    left: "left-0",
    right: "right-0",
    center: "left-1/2 transform -translate-x-1/2",
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <div onClick={() => setIsOpen(!isOpen)}>{trigger}</div>

      {isOpen && (
        <div
          className={cn(
            "absolute top-full mt-2 z-50 min-w-48 bg-white rounded-md shadow-lg border border-secondary-200 py-1",
            alignClasses[align],
            className
          )}
        >
          {children}
        </div>
      )}
    </div>
  );
}

// Dropdown sub-components
Dropdown.Item = function DropdownItem({
  children,
  onClick,
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { onClick?: () => void }) {
  return (
    <div
      className={cn(
        "px-4 py-2 text-sm text-secondary-700 hover:bg-secondary-100 cursor-pointer",
        className
      )}
      onClick={onClick}
      {...props}
    >
      {children}
    </div>
  );
};

Dropdown.Separator = function DropdownSeparator({
  className,
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn("border-t border-secondary-200 my-1", className)} />
  );
};
```

### Step 5: Design System Documentation

```typescript
// src/components/DesignSystem.tsx
import React from "react";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";
import { Card } from "./ui/Card";
import { Container } from "./layout/Container";
import { Stack } from "./layout/Stack";
import { Grid } from "./layout/Grid";
import { Modal } from "./ui/Modal";
import { Dropdown } from "./ui/Dropdown";

export function DesignSystem() {
  const [isModalOpen, setIsModalOpen] = React.useState(false);

  return (
    <Container>
      <Stack spacing="xl">
        <div>
          <h1 className="text-4xl font-bold text-secondary-900 mb-8">
            Design System
          </h1>
          <p className="text-lg text-secondary-600">
            A comprehensive collection of reusable components built with
            Tailwind CSS.
          </p>
        </div>

        {/* Buttons */}
        <section>
          <h2 className="text-2xl font-semibold text-secondary-900 mb-6">
            Buttons
          </h2>
          <Card>
            <Card.Content>
              <Stack direction="horizontal" spacing="md" wrap>
                <Button variant="primary">Primary</Button>
                <Button variant="secondary">Secondary</Button>
                <Button variant="outline">Outline</Button>
                <Button variant="ghost">Ghost</Button>
                <Button variant="danger">Danger</Button>
              </Stack>

              <Stack direction="horizontal" spacing="md" wrap className="mt-6">
                <Button size="sm">Small</Button>
                <Button size="md">Medium</Button>
                <Button size="lg">Large</Button>
                <Button size="xl">Extra Large</Button>
              </Stack>

              <Stack direction="horizontal" spacing="md" wrap className="mt-6">
                <Button loading>Loading</Button>
                <Button disabled>Disabled</Button>
              </Stack>
            </Card.Content>
          </Card>
        </section>

        {/* Inputs */}
        <section>
          <h2 className="text-2xl font-semibold text-secondary-900 mb-6">
            Inputs
          </h2>
          <Card>
            <Card.Content>
              <Grid cols={2} gap="lg">
                <Input label="Default Input" placeholder="Enter text..." />
                <Input label="With Error" error="This field is required" />
                <Input
                  label="With Helper Text"
                  helperText="This is helpful information"
                />
                <Input label="Disabled" disabled placeholder="Disabled input" />
              </Grid>
            </Card.Content>
          </Card>
        </section>

        {/* Cards */}
        <section>
          <h2 className="text-2xl font-semibold text-secondary-900 mb-6">
            Cards
          </h2>
          <Grid cols={3} gap="lg">
            <Card variant="default">
              <Card.Header>
                <Card.Title>Default Card</Card.Title>
                <Card.Description>
                  This is a default card variant.
                </Card.Description>
              </Card.Header>
              <Card.Content>
                <p>Card content goes here.</p>
              </Card.Content>
            </Card>

            <Card variant="elevated">
              <Card.Header>
                <Card.Title>Elevated Card</Card.Title>
                <Card.Description>This card has elevation.</Card.Description>
              </Card.Header>
              <Card.Content>
                <p>Card content goes here.</p>
              </Card.Content>
            </Card>

            <Card variant="outlined">
              <Card.Header>
                <Card.Title>Outlined Card</Card.Title>
                <Card.Description>This card has an outline.</Card.Description>
              </Card.Header>
              <Card.Content>
                <p>Card content goes here.</p>
              </Card.Content>
            </Card>
          </Grid>
        </section>

        {/* Layout Components */}
        <section>
          <h2 className="text-2xl font-semibold text-secondary-900 mb-6">
            Layout Components
          </h2>
          <Card>
            <Card.Content>
              <Stack spacing="lg">
                <div>
                  <h3 className="text-lg font-medium mb-4">Stack (Vertical)</h3>
                  <Stack spacing="md" className="p-4 bg-secondary-50 rounded">
                    <div className="p-2 bg-white rounded border">Item 1</div>
                    <div className="p-2 bg-white rounded border">Item 2</div>
                    <div className="p-2 bg-white rounded border">Item 3</div>
                  </Stack>
                </div>

                <div>
                  <h3 className="text-lg font-medium mb-4">
                    Stack (Horizontal)
                  </h3>
                  <Stack
                    direction="horizontal"
                    spacing="md"
                    className="p-4 bg-secondary-50 rounded"
                  >
                    <div className="p-2 bg-white rounded border">Item 1</div>
                    <div className="p-2 bg-white rounded border">Item 2</div>
                    <div className="p-2 bg-white rounded border">Item 3</div>
                  </Stack>
                </div>

                <div>
                  <h3 className="text-lg font-medium mb-4">Grid</h3>
                  <Grid
                    cols={4}
                    gap="md"
                    className="p-4 bg-secondary-50 rounded"
                  >
                    <Grid.Item
                      span={1}
                      className="p-2 bg-white rounded border text-center"
                    >
                      1
                    </Grid.Item>
                    <Grid.Item
                      span={2}
                      className="p-2 bg-white rounded border text-center"
                    >
                      2
                    </Grid.Item>
                    <Grid.Item
                      span={1}
                      className="p-2 bg-white rounded border text-center"
                    >
                      3
                    </Grid.Item>
                  </Grid>
                </div>
              </Stack>
            </Card.Content>
          </Card>
        </section>

        {/* Interactive Components */}
        <section>
          <h2 className="text-2xl font-semibold text-secondary-900 mb-6">
            Interactive Components
          </h2>
          <Card>
            <Card.Content>
              <Stack direction="horizontal" spacing="md">
                <Button onClick={() => setIsModalOpen(true)}>Open Modal</Button>

                <Dropdown
                  trigger={<Button variant="outline">Dropdown ▼</Button>}
                >
                  <Dropdown.Item onClick={() => console.log("Action 1")}>
                    Action 1
                  </Dropdown.Item>
                  <Dropdown.Item onClick={() => console.log("Action 2")}>
                    Action 2
                  </Dropdown.Item>
                  <Dropdown.Separator />
                  <Dropdown.Item onClick={() => console.log("Action 3")}>
                    Action 3
                  </Dropdown.Item>
                </Dropdown>
              </Stack>
            </Card.Content>
          </Card>
        </section>
      </Stack>

      {/* Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Example Modal"
        size="md"
      >
        <p>This is an example modal. You can put any content here.</p>
        <Stack direction="horizontal" spacing="md" className="mt-6">
          <Button onClick={() => setIsModalOpen(false)}>Close</Button>
          <Button variant="primary">Save Changes</Button>
        </Stack>
      </Modal>
    </Container>
  );
}
```

## Best Practices

### 1. Design Tokens

- Use consistent spacing scale
- Maintain color palette consistency
- Define typography hierarchy
- Create reusable shadows and animations

### 2. Component Design

- Follow single responsibility principle
- Use composition over inheritance
- Provide flexible props and variants
- Maintain consistent API patterns

### 3. Utility Classes

- Leverage Tailwind's utility-first approach
- Create custom utilities when needed
- Use consistent naming conventions
- Document custom utilities

### 4. Responsive Design

- Design mobile-first
- Use responsive variants consistently
- Test across different screen sizes
- Maintain accessibility

## Quality Gates

### 1. Component Consistency

- All components follow design tokens
- Consistent spacing and typography
- Unified color usage
- Consistent interaction patterns

### 2. Responsiveness

- Components work on all screen sizes
- Responsive variants are implemented
- Touch targets are appropriate
- Layout adapts properly

### 3. Accessibility

- Proper ARIA labels
- Keyboard navigation support
- Focus management
- Screen reader compatibility

### 4. Performance

- Components render efficiently
- No unnecessary re-renders
- Bundle size is optimized
- Loading states are handled

## Next Steps

After completing design system setup:

1. Add component testing
2. Implement storybook documentation
3. Add accessibility testing
4. Create component playground
5. Set up design token management
