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
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
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

    case 'hardware':
      // ✅ NUEVO FLUJO SECUENCIAL: Hardware requiere color + bottom bar + headbox (obligatorio para dual)
      const hasColor = !!((dualConfig as any).hardwareColor || (dualConfig as any).hardware_color);
      const hasBottomBar = !!((dualConfig as any).bottom_bar_item_id || (dualConfig as any).bottom_bar_sku);
      const hasHeadbox = !!((dualConfig as any).headbox_item_id || (dualConfig as any).headbox_sku);
      return hasColor && hasBottomBar && hasHeadbox;

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
      return hasOperatingSystem && hasTube && hasSpecificSelection;

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

