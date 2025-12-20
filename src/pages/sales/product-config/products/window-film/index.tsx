/**
 * Window Film Product Module
 * Complete configuration flow for Window Film products
 */

import React from 'react';
import { ProductType, WindowFilmConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';

// Placeholder components (TODO: Create actual Window Film-specific step components)
const PlaceholderStep: React.FC<{ title: string }> = ({ title }) => (
  <div className="max-w-4xl mx-auto">
    <div className="bg-white rounded-lg border border-gray-200 p-6">
      <h2 className="text-lg font-semibold text-gray-900">{title}</h2>
      <p className="text-sm text-gray-500 mt-2">This step is under development.</p>
    </div>
  </div>
);

const WINDOW_FILM_STEPS: ProductStep[] = [
  { id: 'product', label: 'PRODUCT', component: () => <PlaceholderStep title="Product Selection" /> },
  { id: 'film-type', label: 'FILM TYPE', component: () => <PlaceholderStep title="Film Type" /> },
  { id: 'opacity', label: 'OPACITY & PROPERTIES', component: () => <PlaceholderStep title="Opacity & Properties" /> },
  { id: 'measurements', label: 'GLASS MEASUREMENTS', component: () => <PlaceholderStep title="Glass Measurements" /> },
  { id: 'installation', label: 'INSTALLATION TYPE', component: () => <PlaceholderStep title="Installation Type" /> },
  { id: 'review', label: 'QUOTE', component: () => <PlaceholderStep title="Review" /> },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'window-film') return false;
  const filmConfig = config as WindowFilmConfig;
  switch (stepId) {
    case 'film-type':
      return !!filmConfig.filmType;
    case 'opacity':
      return filmConfig.opacity !== undefined;
    case 'measurements':
      return !!(filmConfig.width_mm && filmConfig.height_mm);
    default:
      return true;
  }
}

// Register Window Film product
registerProduct({
  type: 'window-film',
  name: 'Window Film',
  steps: WINDOW_FILM_STEPS,
  validateStep,
});

