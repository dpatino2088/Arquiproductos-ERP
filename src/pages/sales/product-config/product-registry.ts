/**
 * Product Registry
 * Central registry for product type definitions, steps, and builders
 */

import React from 'react';
import { ProductType, ProductConfig } from './types';

export interface ProductStep {
  id: string;
  label: string;
  component: React.ComponentType<any>;
  isRequired?: boolean;
}

export interface ProductDefinition {
  type: ProductType;
  name: string;
  steps: ProductStep[];
  validateStep?: (stepId: string, config: ProductConfig) => boolean;
}

// This will be populated by product-specific modules
export const PRODUCT_REGISTRY = new Map<ProductType, ProductDefinition>();

/**
 * Register a product type definition
 */
export function registerProduct(definition: ProductDefinition) {
  PRODUCT_REGISTRY.set(definition.type, definition);
}

/**
 * Get product definition by type
 */
export function getProductDefinition(type: ProductType): ProductDefinition | undefined {
  return PRODUCT_REGISTRY.get(type);
}

/**
 * Get steps for a product type
 */
export function getProductSteps(type: ProductType): ProductStep[] {
  const definition = getProductDefinition(type);
  return definition?.steps || [];
}

/**
 * Validate if a step can proceed for a product type
 */
export function canProceedToNext(stepId: string, type: ProductType, config: ProductConfig): boolean {
  const definition = getProductDefinition(type);
  if (!definition?.validateStep) return true;
  return definition.validateStep(stepId, config);
}

