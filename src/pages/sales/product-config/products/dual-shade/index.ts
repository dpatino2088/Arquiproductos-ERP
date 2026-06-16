/**
 * Dual Shade Product Module
 * Complete configuration flow for Dual Shade products
 */

import { ProductType, DualShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';
import { validateMeasurements } from '../../measurementValidation';

const DUAL_SHADE_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'dual-shade') return false;
  const dualConfig = config as DualShadeConfig;

  switch (stepId) {
    case 'manufacturer':
      return !!(dualConfig as any).manufacturer;

    case 'measurements':
      return !!(dualConfig.width_mm && dualConfig.height_mm) && validateMeasurements(dualConfig as any).valid;

    case 'variants': {
      // Dealer-supplied (ghost) fabric: no fabric selection required
      if ((dualConfig as any).dealer_supply_fabric) return true;
      const hasCollection = !!(
        (dualConfig as any).collectionName ||
        (dualConfig as any).collection_name ||
        (dualConfig as any).collectionId
      );
      const hasVariant = !!(
        (dualConfig as any).variantId ||
        (dualConfig as any).fabric_catalog_item_id ||
        (dualConfig as any).fabric_variant_id
      );
      return hasCollection && hasVariant;
    }

    case 'hardware': {
      const hasColor = !!((dualConfig as any).hardwareColor || (dualConfig as any).hardware_color);
      const hasBottomBar = !!((dualConfig as any).bottom_bar_item_id || (dualConfig as any).bottom_bar_sku);
      const hbPolicy: string = (dualConfig as any)._headboxPolicy ?? 'optional';
      const hasHeadbox = hbPolicy === 'none' || (dualConfig as any).headbox_item_id != null;
      return hasColor && hasBottomBar && hasHeadbox;
    }

    case 'operating-system':
      // ✅ NUEVO FLUJO: Operating system + drive/motor específico + tube obligatorios
      const op =
        (dualConfig as any).operation_type ||
        (dualConfig as any).drive_type ||
        (dualConfig as any).operatingSystem ||
        (dualConfig as any).operating_system;
      const isManual = op === 'manual';
      const isMotorized = op === 'motor' || op === 'motorized';

      const hasOperatingSystem = !!op;
      const hasTube = !!((dualConfig as any).tube_item_id || (dualConfig as any).tube_sku || (dualConfig as any).tube_type);

      const hasManualDrive = !!(
        (dualConfig as any).drive_item_id ||
        (dualConfig as any).drive_sku ||
        (dualConfig as any).manual_drive
      );
      const hasMotor = !!(
        (dualConfig as any).motor_item_id ||
        (dualConfig as any).motor_sku ||
        (dualConfig as any).motor_family
      );

      const hasSpecificSelection = isManual ? hasManualDrive : isMotorized ? hasMotor : false;
      const hasDriveSide = !!((dualConfig as any).driveSide || (dualConfig as any).drive_side);
      return hasOperatingSystem && hasTube && hasSpecificSelection && hasDriveSide;

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

