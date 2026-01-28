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
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
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

    case 'hardware':
      // ✅ NUEVO FLUJO SECUENCIAL: Hardware requiere color + bottom bar
      // Headbox: obligatorio para dual/triple, opcional para roller
      const hasColor = !!((rollerConfig as any).hardwareColor || (rollerConfig as any).hardware_color);
      const hasBottomBar = !!((rollerConfig as any).bottom_bar_item_id || (rollerConfig as any).bottom_bar_sku);

      // Headbox requerido solo para dual/triple shades
      const isDualOrTriple = (rollerConfig as any).product_type_id === 'dual-shade' || (rollerConfig as any).product_type_id === 'triple-shade';
      const hasHeadbox = !!((rollerConfig as any).headbox_item_id || (rollerConfig as any).headbox_sku);

      return hasColor && hasBottomBar && (!isDualOrTriple || hasHeadbox);

    case 'operating-system':
      // ✅ NUEVO FLUJO: Operating system + drive/motor específico + tube obligatorios
      // operation_type: 'manual' | 'motor'
      // drive_type / operatingSystem: 'manual' | 'motorized'
      const op =
        (rollerConfig as any).operation_type ||
        (rollerConfig as any).drive_type ||
        (rollerConfig as any).operatingSystem ||
        (rollerConfig as any).operating_system;
      const isManual = op === 'manual';
      const isMotorized = op === 'motor' || op === 'motorized';

      const hasOperatingSystem = !!op;
      const hasTube = !!((rollerConfig as any).tube_item_id || (rollerConfig as any).tube_sku || (rollerConfig as any).tube_type);

      const hasManualDrive = !!(
        (rollerConfig as any).drive_item_id ||
        (rollerConfig as any).drive_sku ||
        (rollerConfig as any).manual_drive
      );
      const hasMotor = !!(
        (rollerConfig as any).motor_item_id ||
        (rollerConfig as any).motor_sku ||
        (rollerConfig as any).motor_family
      );

      const hasSpecificSelection = isManual ? hasManualDrive : isMotorized ? hasMotor : false;
      return hasOperatingSystem && hasTube && hasSpecificSelection;

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

