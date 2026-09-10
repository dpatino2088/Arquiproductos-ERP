/**
 * Awning Product Module — VERTICAL (drop screen)
 * Width × Height system, roller-like. Uses the standard MeasurementsStep
 * (fabric drop cards are hidden for this product type).
 */

import { AwningConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import AwningVerticalMeasurementsStepComponent from '../../../curtain-config/AwningVerticalMeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';
import { validateMeasurements } from '../../measurementValidation';

const AWNING_VERTICAL_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: AwningVerticalMeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'awning-vertical') return false;
  const awningConfig = config as AwningConfig;
  const cfg = awningConfig as any;

  switch (stepId) {
    case 'manufacturer':
      return !!cfg.manufacturer;

    case 'measurements':
      return !!(awningConfig.width_mm && awningConfig.height_mm) && validateMeasurements(cfg).valid;

    case 'variants': {
      if (cfg.dealer_supply_fabric) return true;
      const hasCollection = !!(cfg.collectionName || cfg.collection_name || cfg.collectionId);
      const hasVariant = !!(cfg.variantId || cfg.fabric_catalog_item_id || cfg.fabric_variant_id);
      return hasCollection && hasVariant;
    }

    case 'operating-system': {
      const op = cfg.operation_type || cfg.drive_type || cfg.operatingSystem || cfg.operating_system;
      const isManual = op === 'manual';
      const isMotorized = op === 'motor' || op === 'motorized';
      const hasTube = !!(cfg.tube_item_id || cfg.tube_sku || cfg.tube_type);
      const hasManualDrive = !!(cfg.drive_item_id || cfg.drive_sku || cfg.manual_drive);
      const hasMotor = !!(cfg.motor_item_id || cfg.motor_sku || cfg.motor_family);
      const hasSpecificSelection = isManual ? hasManualDrive : isMotorized ? hasMotor : false;
      const hasDriveSide = !!(cfg.driveSide || cfg.drive_side);
      return !!op && hasTube && hasSpecificSelection && hasDriveSide;
    }

    default:
      return true;
  }
}

// Register Vertical Awning product
registerProduct({
  type: 'awning-vertical',
  name: 'Vertical Awning',
  steps: AWNING_VERTICAL_STEPS,
  validateStep,
});
