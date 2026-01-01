/**
 * Dual Shade Product Module
 * Complete configuration flow for Dual Shade products
 */

import { ProductType, DualShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const DUAL_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'dual-shade') return false;
  const dualConfig = config as DualShadeConfig;
  switch (stepId) {
    case 'measurements':
      return !!(dualConfig.width_mm && dualConfig.height_mm);
    case 'variants':
      return !!(dualConfig.frontFabric?.collectionId && dualConfig.frontFabric?.variantId);
    case 'operating-system':
      // Only require drive_type (or operatingSystem for backward compatibility)
      return !!((dualConfig as any).drive_type || dualConfig.operatingSystem);
    default:
      return true;
  }
}

// Register Dual Shade product
registerProduct({
  type: 'dual-shade',
  name: 'Dual Shade',
  steps: DUAL_SHADE_STEPS,
  validateStep,
});

