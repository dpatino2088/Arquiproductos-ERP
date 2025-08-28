# Instruction: Scaffold Structure

## Overview

Create the initial project structure following a feature-based architecture pattern. This structure should support scalability, maintainability, and clear separation of concerns.

## Core Structure

### 1. Root Directory

```
REMO-FRONTEND/
├── src/
├── public/
├── agent-os/
├── .cursor/
├── package.json
├── tsconfig.json
├── vite.config.ts
├── tailwind.config.ts
├── postcss.config.cjs
└── README.md
```

### 2. Source Directory Structure

```
src/
├── app/                    # Application bootstrap
│   ├── ErrorFallback.tsx
│   └── index.ts
├── assets/                 # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
├── components/             # Reusable components
│   ├── layout/            # Layout components
│   │   ├── Container.tsx
│   │   ├── Stack.tsx
│   │   ├── Inline.tsx
│   │   ├── Grid.tsx
│   │   └── SidebarLayout.tsx
│   └── ui/                # UI components
│       ├── Button.tsx
│       ├── Card.tsx
│       ├── Input.tsx
│       ├── Badge.tsx
│       ├── Alert.tsx
│       ├── Skeleton.tsx
│       └── Table.tsx
├── config/                 # Configuration
│   ├── index.ts
│   └── env.ts
├── features/               # Feature modules
│   └── auth/              # Authentication feature
│       ├── api/
│       ├── components/
│       ├── forms/
│       │   ├── schemas.ts
│       │   └── components/
│       ├── hooks/
│       ├── pages/
│       ├── types/
│       └── index.ts
├── hooks/                  # Custom hooks
│   ├── api/               # API-related hooks
│   │   ├── useApiQuery.ts
│   │   └── useApiMutation.ts
│   ├── useRouteFocus.ts
│   ├── usePageMeta.ts
│   └── index.ts
├── lib/                    # Utility libraries
│   ├── utils.ts
│   ├── formUtils.ts
│   ├── idUtils.ts
│   ├── env.ts
│   ├── webVitals.ts
│   └── index.ts
├── routes/                 # Routing
│   ├── layouts/
│   │   ├── RootLayout.tsx
│   │   ├── PublicLayout.tsx
│   │   └── AuthLayout.tsx
│   ├── pages/
│   │   ├── Home.tsx
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx
│   │   ├── Forbidden.tsx
│   │   ├── NotFound.tsx
│   │   └── DesignSystemDemo.tsx
│   ├── guards.ts
│   └── router.tsx
├── services/               # External services
│   ├── apiClient.ts
│   └── logger.ts
├── stores/                 # State management
│   ├── authStore.ts
│   └── uiStore.ts
├── styles/                 # Styling
│   ├── tailwind.css
│   └── globals.css
├── test/                   # Testing
│   ├── setup.ts
│   ├── utils.tsx
│   ├── types.ts
│   ├── mocks/
│   │   ├── browser.ts
│   │   ├── server.ts
│   │   └── handlers.ts
│   └── index.ts
├── types/                  # TypeScript types
│   ├── index.ts
│   └── env.d.ts
├── main.tsx               # Application entry point
└── App.tsx                # Root component
```

## Implementation Steps

### Step 1: Create Directory Structure

1. Create all directories using `mkdir -p`
2. Ensure proper nesting and organization
3. Create placeholder files where needed

### Step 2: Initialize Core Files

1. Set up `package.json` with dependencies
2. Configure `tsconfig.json` with path aliases
3. Set up `vite.config.ts` with build configuration
4. Configure Tailwind CSS with PostCSS

### Step 3: Create Component Placeholders

1. Create basic component files with export statements
2. Implement layout components with basic structure
3. Create UI components with placeholder content
4. Set up routing structure

### Step 4: Configure Build Tools

1. Set up TypeScript configuration
2. Configure Vite build process
3. Set up Tailwind CSS processing
4. Configure testing environment

## Best Practices

### 1. File Naming

- Use PascalCase for component files
- Use camelCase for utility files
- Use kebab-case for directories
- Use descriptive names that indicate purpose

### 2. Import Organization

- Group imports by type (React, third-party, local)
- Use absolute imports with `@/` alias
- Maintain consistent import ordering
- Remove unused imports

### 3. Component Structure

- One component per file
- Export components as named exports
- Use TypeScript interfaces for props
- Include proper JSDoc comments

### 4. Directory Organization

- Group related files together
- Use feature-based organization for complex features
- Keep common utilities in `lib/`
- Maintain clear separation of concerns

## Quality Gates

### 1. Structure Validation

- All directories exist and are properly nested
- All placeholder files are created
- Import/export statements are correct
- No circular dependencies

### 2. Build Validation

- Project builds without errors
- TypeScript compilation succeeds
- Tailwind CSS processes correctly
- All imports resolve properly

### 3. Testing Validation

- Test environment is properly configured
- Basic tests can run
- Mocking setup is functional
- Coverage reporting works

## Next Steps

After completing the scaffold structure:

1. Implement basic routing
2. Set up state management
3. Create core components
4. Implement authentication flow
5. Add testing coverage
