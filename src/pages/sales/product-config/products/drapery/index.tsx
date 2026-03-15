/**
 * Drapery Product Module
 * Complete configuration flow for Drapery (Wave/Ripple Fold/Pinch Pleat) products
 */

import { ProductType, DraperyConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import ProductLineStepComponent from './ProductLineStep';
import DraperyHardwareStepComponent from './DraperyHardwareStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const DRAPERY_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'product-line', label: 'PRODUCT LINE', component: ProductLineStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'drapery-hardware', label: 'HARDWARE', component: DraperyHardwareStepComponent, isRequired: true },
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
    case 'product-line': {
      const pl = cfg.productLine || cfg.product_line;
      const sc = cfg.styleCode || cfg.style_code;
      if (!pl || !sc) return false;
      const needsSize = pl === 'wave_drapery' || pl === 'ripple_fold';
      return needsSize ? !!(cfg.systemSize || cfg.system_size) : true;
    }
    case 'measurements':
      return !!(cfg.width_mm && cfg.height_mm);
    case 'drapery-hardware': {
      const od = cfg.openingDirection || cfg.opening_direction;
      const hc = cfg.hardwareColor || cfg.hardware_color;
      if (!od || !hc) return false;
      const needsDriveSide = od === 'center';
      return needsDriveSide ? !!(cfg.driveSide || cfg.drive_side) : true;
    }
    case 'variants':
      return !!(cfg.track_only || cfg.variantId || cfg.fabric_catalog_item_id);
    case 'operating-system': {
      const op = cfg.operation_type || cfg.drive_type || cfg.operatingSystem;
      if (!op) return false;
      const isMotor = op === 'motor' || op === 'motorized';
      const isManual = op === 'manual';
      if (isMotor) return !!(cfg.motor_item_id || cfg.motor_sku);
      if (isManual) return true;
      return false;
    }
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

