/**
 * Roller Shade Product Module
 * Complete configuration flow for Roller Shade products
 */

import { ProductType, RollerShadeConfig, ProductConfig } from '../../types';
import { registerProduct, ProductStep } from '../../product-registry';
import ManufacturerStepComponent from '../../../curtain-config/ManufacturerStep';
import MeasurementsStepComponent from '../../../curtain-config/MeasurementsStep';
import VariantsStepComponent from '../../../curtain-config/VariantsStep';
import OperatingSystemStepComponent from '../../../curtain-config/OperatingSystemStep';
import HardwareStepComponent from '../../../curtain-config/HardwareStep';
import ReviewStepComponent from '../../../curtain-config/ReviewStep';

const ROLLER_SHADE_STEPS: ProductStep[] = [
  { id: 'manufacturer', label: 'MANUFACTURER', component: ManufacturerStepComponent, isRequired: true },
  { id: 'measurements', label: 'MEASUREMENTS', component: MeasurementsStepComponent, isRequired: true },
  { id: 'variants', label: 'VARIANTS', component: VariantsStepComponent },
  { id: 'hardware', label: 'HARDWARE', component: HardwareStepComponent },
  { id: 'operating-system', label: 'OPERATING SYSTEM', component: OperatingSystemStepComponent },
  { id: 'review', label: 'REVIEW', component: ReviewStepComponent },
];

function validateStep(stepId: string, config: ProductConfig): boolean {
  if (config.productType !== 'roller-shade') return false;
  const rollerConfig = config as RollerShadeConfig;

  switch (stepId) {
    case 'manufacturer':
      return !!(rollerConfig as any).manufacturer;

    case 'measurements':
      return !!(rollerConfig.width_mm && rollerConfig.height_mm);

    case 'variants': {
      // Catalog path: collection + variantId
      const hasCollection = !!(
        (rollerConfig as any).collectionName ||
        (rollerConfig as any).collection_name ||
        (rollerConfig as any).collectionId
      );
      const hasVariant = !!(
        (rollerConfig as any).variantId ||
        (rollerConfig as any).fabric_catalog_item_id ||
        (rollerConfig as any).fabric_variant_id
      );
      return hasCollection && hasVariant;
    }

    case 'hardware': {
      const hasColor = !!((rollerConfig as any).hardwareColor || (rollerConfig as any).hardware_color);
      const hasBottomBar = !!((rollerConfig as any).bottom_bar_item_id || (rollerConfig as any).bottom_bar_sku);
      const hbPolicy: string = (rollerConfig as any)._headboxPolicy ?? 'optional';
      const scPolicy: string = (rollerConfig as any)._sideChannelPolicy ?? 'optional';
      const hasHeadboxExplicit = hbPolicy === 'none' || (rollerConfig as any).headbox_item_id != null;
      const hasSideChannelExplicit = scPolicy === 'none' || (rollerConfig as any).side_channel_item_id != null;

      return hasColor && hasBottomBar && hasHeadboxExplicit && hasSideChannelExplicit;
    }

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
      const hasDriveSide = !!((rollerConfig as any).driveSide || (rollerConfig as any).drive_side);
      return hasOperatingSystem && hasTube && hasSpecificSelection && hasDriveSide;

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

