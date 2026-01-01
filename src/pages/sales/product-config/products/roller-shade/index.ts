/**
 * Roller Shade Product Module
 * Complete configuration flow for Roller Shade products
 */

import { ProductType, RollerShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const ROLLER_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'roller-shade') return false;
  const rollerConfig = config as RollerShadeConfig;
  switch (stepId) {
    case 'measurements':
      return !!(rollerConfig.width_mm && rollerConfig.height_mm);
    case 'variants':
      return !!(rollerConfig.collectionId && rollerConfig.variantId);
    case 'operating-system':
      // Only require drive_type (or operatingSystem for backward compatibility)
      return !!((rollerConfig as any).drive_type || rollerConfig.operatingSystem);
    default:
      return true;
  }
}

// Register Roller Shade product
registerProduct({
  type: 'roller-shade',
  name: 'Roller Shade',
  steps: ROLLER_SHADE_STEPS,
  validateStep,
});

