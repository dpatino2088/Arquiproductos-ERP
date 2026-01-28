/**
 * Triple Shade Product Module
 * Complete configuration flow for Triple Shade products
 */

import { ProductType, TripleShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import AccessoriesStepComponent from '../../../curtain-config/AccessoriesStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const TRIPLE_SHADE_STEPS: ProductStep[] = [
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'accessories', label: 'ACCESSORIES', component: AccessoriesStepComponent },
  { id: 'review', label: 'QUOTE', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'triple-shade') return false;
  const tripleConfig = config as TripleShadeConfig;

  switch (stepId) {
    case 'measurements':
      return !!(tripleConfig.width_mm && tripleConfig.height_mm);

    case 'variants':
      return !!(tripleConfig.frontFabric?.collectionId && tripleConfig.frontFabric?.variantId);

    case 'hardware':
      // ✅ NUEVO FLUJO SECUENCIAL: Hardware requiere color + bottom bar + headbox (obligatorio para triple)
      const hasColor = !!((tripleConfig as any).hardwareColor || (tripleConfig as any).hardware_color);
      const hasBottomBar = !!((tripleConfig as any).bottom_bar_item_id || (tripleConfig as any).bottom_bar_sku);
      const hasHeadbox = !!((tripleConfig as any).headbox_item_id || (tripleConfig as any).headbox_sku);
      return hasColor && hasBottomBar && hasHeadbox;

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
      return hasOperatingSystem && hasTube && hasSpecificSelection;

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

