/**
 * Window Film Product Module
 * Steps mirror Roller Shade order: Manufacturer → Measurements → Variants → Review
 */

import type { ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import FilmManufacturerStep from './FilmManufacturerStep';
import FilmSellModeStep from './FilmSellModeStep';
import FilmVariantsStep from './FilmVariantsStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const WINDOW_FILM_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: FilmManufacturerStep, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: FilmSellModeStep, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: FilmVariantsStep, isRequired: true },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'window-film') return false;
  const cfg = config as any;
  switch (stepId) {
    case 'manufacturer':
      return !!cfg.manufacturer;
    case 'measurements':
      return !!cfg.sell_mode && !!cfg.film_width;
    case 'variants':
      return !!cfg.film_collection && !!cfg.film_variant && !!cfg.catalog_item_id;
    case 'review':
      return true;
    default:
      return true;
  }
}

registerProduct({
  type: 'window-film',
  name: 'Window Film',
  steps: WINDOW_FILM_STEPS,
  validateStep,
});
