/**
 * Triple Shade Product Module
 * Complete configuration flow for Triple Shade products
 */

import { ProductType, TripleShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';
import { validateMeasurements } from '../../measurementValidation';

const TRIPLE_SHADE_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'triple-shade') return false;
  const tripleConfig = config as TripleShadeConfig;

  switch (stepId) {
    case 'manufacturer':
      return !!(tripleConfig as any).manufacturer;

    case 'measurements':
      return !!(tripleConfig.width_mm && tripleConfig.height_mm) && validateMeasurements(tripleConfig as any).valid;

    case 'variants': {
      // Dealer-supplied (ghost) fabric: no fabric selection required
      if ((tripleConfig as any).dealer_supply_fabric) return true;
      const hasCollection = !!(
        (tripleConfig as any).collectionName ||
        (tripleConfig as any).collection_name ||
        (tripleConfig as any).collectionId
      );
      const hasVariant = !!(
        (tripleConfig as any).variantId ||
        (tripleConfig as any).fabric_catalog_item_id ||
        (tripleConfig as any).fabric_variant_id
      );
      return hasCollection && hasVariant;
    }

    case 'hardware': {
      const hasColor = !!((tripleConfig as any).hardwareColor || (tripleConfig as any).hardware_color);
      const hasBottomBar = !!((tripleConfig as any).bottom_bar_item_id || (tripleConfig as any).bottom_bar_sku);
      const hbPolicy: string = (tripleConfig as any)._headboxPolicy ?? 'optional';
      const hasHeadbox = hbPolicy === 'none' || (tripleConfig as any).headbox_item_id != null;
      return hasColor && hasBottomBar && hasHeadbox;
    }

    case 'operating-system':
      // ✅ NUEVO FLUJO: Operating system + drive/motor específico + tube obligatorios
      const op =
        (tripleConfig as any).operation_type ||
        (tripleConfig as any).drive_type ||
        (tripleConfig as any).operatingSystem ||
        (tripleConfig as any).operating_system;
      const isManual = op === 'manual';
      const isMotorized = op === 'motor' || op === 'motorized';

      const hasOperatingSystem = !!op;
      const hasTube = !!((tripleConfig as any).tube_item_id || (tripleConfig as any).tube_sku || (tripleConfig as any).tube_type);

      const hasManualDrive = !!(
        (tripleConfig as any).drive_item_id ||
        (tripleConfig as any).drive_sku ||
        (tripleConfig as any).manual_drive
      );
      const hasMotor = !!(
        (tripleConfig as any).motor_item_id ||
        (tripleConfig as any).motor_sku ||
        (tripleConfig as any).motor_family
      );

      const hasSpecificSelection = isManual ? hasManualDrive : isMotorized ? hasMotor : false;
      const hasDriveSide = !!((tripleConfig as any).driveSide || (tripleConfig as any).drive_side);
      return hasOperatingSystem && hasTube && hasSpecificSelection && hasDriveSide;

    default:
      return true;
  }
}

// Register Triple Shade product
registerProduct({
  type: 'triple-shade',
  name: 'Triple Shade',
  steps: TRIPLE_SHADE_STEPS,
  validateStep,
});

