/**
 * Awning Product Module
 * Complete configuration flow for Awning products
 */

import { ProductType, AwningConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';
import { validateMeasurements } from '../../measurementValidation';

const AWNING_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'awning') return false;
  const awningConfig = config as AwningConfig;
  switch (stepId) {
    case 'manufacturer':
      return !!(awningConfig as any).manufacturer;

    case 'measurements':
      return !!(awningConfig.width_mm && awningConfig.height_mm) && validateMeasurements(awningConfig as any).valid;
    case 'variants':
      return !!(awningConfig.fabric?.collectionId && awningConfig.fabric?.variantId);
    case 'operating-system': {
      const hasDriveType = !!((awningConfig as any).drive_type || awningConfig.operatingSystem);
      const hasDriveSide = !!((awningConfig as any).driveSide || (awningConfig as any).drive_side);
      return hasDriveType && hasDriveSide;
    }
    default:
      return true;
  }
}

// Register Awning product
registerProduct({
  type: 'awning',
  name: 'Awning',
  steps: AWNING_STEPS,
  validateStep,
});

