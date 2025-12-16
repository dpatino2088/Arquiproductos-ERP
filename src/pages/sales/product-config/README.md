# Product Configuration Architecture

## Overview

This is a **product-type-driven architecture** where each product type (Roller Shade, Drapery, Window Film, etc.) has its own independent configuration flow, schema, and BOM builder.

## Key Principles

1. **Product Type is the ROOT decision** - Once selected, it defines everything
2. **No generic forms** - Each product type has its own components and logic
3. **Scalable** - Adding a new product type doesn't break existing ones
4. **Type-safe** - Each product type has its own TypeScript interface

## Architecture

```
product-config/
├── types.ts                    # Product type definitions and schemas
├── product-registry.ts         # Central registry for product definitions
├── adapters.ts                # Compatibility adapters
├── bom/
│   └── builders.ts            # Product-specific BOM builders
└── products/
    ├── index.ts               # Entry point (imports all products)
    ├── roller-shade/          # Roller Shade module
    │   └── index.ts
    ├── drapery/               # Drapery module
    │   └── index.ts
    └── window-film/           # Window Film module
        └── index.ts
```

## Adding a New Product Type

### Step 1: Define the Configuration Schema

In `types.ts`, add a new interface:

```typescript
export interface MyNewProductConfig extends BaseProductConfig {
  productType: 'my-new-product';
  // Add product-specific fields
  customField?: string;
}
```

Add it to the union type:

```typescript
export type ProductConfig = 
  | RollerShadeConfig
  | MyNewProductConfig
  | ...
```

### Step 2: Create Product Module

Create `products/my-new-product/index.ts`:

```typescript
import { registerProduct, ProductStep } from '../../product-registry';
import MyStep1Component from './steps/MyStep1';
import MyStep2Component from './steps/MyStep2';

const MY_PRODUCT_STEPS: ProductStep[] = [
  { id: 'step1', label: 'STEP 1', component: MyStep1Component },
  { id: 'step2', label: 'STEP 2', component: MyStep2Component },
];

function validateStep(stepId: string, config: MyNewProductConfig): boolean {
  switch (stepId) {
    case 'step1':
      return !!config.customField;
    default:
      return true;
  }
}

registerProduct({
  type: 'my-new-product',
  name: 'My New Product',
  steps: MY_PRODUCT_STEPS,
  validateStep,
});
```

### Step 3: Create BOM Builder

In `bom/builders.ts`, add:

```typescript
export async function buildMyNewProductBOM(
  config: MyNewProductConfig,
  organizationId: string
): Promise<BOMResult> {
  const items: BOMItem[] = [];
  // Implement BOM logic
  return { items, subtotal: 0, total: 0 };
}
```

Add to the dispatcher:

```typescript
case 'my-new-product':
  return buildMyNewProductBOM(config as MyNewProductConfig, organizationId);
```

### Step 4: Register the Module

In `products/index.ts`, add:

```typescript
import './my-new-product';
```

## Product Types

### Roller Shade
- Steps: Product, Measurements, Variants, Operating System, Accessories, Review
- Uses existing curtain-config components

### Drapery
- Steps: Product, Track System, Fabric & Fullness, Confection Type, Mounting, Accessories, Review
- TODO: Create specific step components

### Window Film
- Steps: Product, Film Type, Opacity & Properties, Glass Measurements, Installation Type, Review
- TODO: Create specific step components

## Usage

```typescript
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';

<ProductConfigurator
  quoteId={quoteId}
  onComplete={(config: ProductConfig) => {
    // Handle completion
  }}
  onClose={() => {}}
/>
```

## Migration Notes

- Old `CurtainConfiguration` is still supported via adapters
- `ProductConfigurator` replaces `CurtainConfigurator`
- Each product type can have completely different steps and fields

