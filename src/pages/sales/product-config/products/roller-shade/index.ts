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
      // VariantsStep usa collectionName/collection_name + variantId (CatalogItem id).
      // Aceptar también collectionId legacy para compatibilidad.
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

    case 'hardware':
      // Requiere color + bottom bar + headbox explícito + side channel explícito (no avanzar si falta alguna elección)
      const hasColor = !!((rollerConfig as any).hardwareColor || (rollerConfig as any).hardware_color);
      const hasBottomBar = !!((rollerConfig as any).bottom_bar_item_id || (rollerConfig as any).bottom_bar_sku);
      // Headbox: debe estar elegido (UUID o 'NONE'), no puede quedar UNSET
      const hasHeadboxExplicit = (rollerConfig as any).headbox_item_id != null;
      // Side channel: debe estar elegido (UUID o 'NONE') para que el template se resuelva correctamente
      const hasSideChannelExplicit = (rollerConfig as any).side_channel_item_id != null;

      return hasColor && hasBottomBar && hasHeadboxExplicit && hasSideChannelExplicit;

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

