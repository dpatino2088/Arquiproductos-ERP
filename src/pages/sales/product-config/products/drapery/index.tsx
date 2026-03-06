/**
 * Drapery Product Module
 * Complete configuration flow for Drapery (Wave/Ripple Fold/Pinch Pleat) products
 */

import { ProductType, DraperyConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import ProductLineStepComponent from './ProductLineStep';
import DraperyStyleStepComponent from './DraperyStyleStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const DRAPERY_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'product-line', label: 'PRODUCT LINE', component: ProductLineStepComponent, isRequired: true },
  { id: 'drapery-style', label: 'STYLE VARIANT', component: DraperyStyleStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'FABRIC', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'drapery') return false;
  const cfg = config as any;
  switch (stepId) {
    case 'manufacturer':
      return !!cfg.manufacturer;
    case 'product-line':
      return !!cfg.productLine;
    case 'drapery-style':
      return !!(cfg.styleCode);
    case 'measurements':
      return !!(cfg.width_mm && cfg.height_mm && cfg.openingDirection && cfg.driveSide);
    case 'variants':
      return !!(cfg.variantId || cfg.fabric_catalog_item_id);
    case 'operating-system':
      return true;
    default:
      return true;
  }
}

// Register Drapery product
registerProduct({
  type: 'drapery',
  name: 'Drapery Wave / Ripple Fold',
  steps: DRAPERY_STEPS,
  validateStep,
});

