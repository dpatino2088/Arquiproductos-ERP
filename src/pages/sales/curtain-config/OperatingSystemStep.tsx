/**
 * Operating System Step - FILTRADO PROGRESIVO
 * 
 * Step 4: Configure operating system
 * - Operating system (manual/motor) - cards
 * - Motor item selection (cards, only if motor)
 * - Manual drive item selection (cards, only if manual)
 * - Tube item selection (cards)
 * 
 * ✅ NUEVA ARQUITECTURA (Filtrado progresivo):
 * - Opciones se cargan desde templates filtrados por Hardware Step
 * - Motor y Tube NO dependen de color, pero SÍ de templates filtrados
 * - El matching de template se hace AL FINAL con matchBOMTemplate()
 */

import { useEffect, useState, useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useBOMTemplateQuestions } from '../../../hooks/useBOMTemplateQuestions';
import { useBOMTemplateOptionsSimple, RoleOption } from '../../../hooks/useBOMTemplateOptionsSimple';
import { Image as ImageIcon, X } from 'lucide-react';
import CatalogItemImage from '../../../components/ui/CatalogItemImage';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useUIStore } from '../../../stores/ui-store';

interface OperatingSystemStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
  /** Templates filtrados desde HardwareStep */
  filteredTemplateIds?: string[];
}

function DriveSideCard({
  value,
  label,
  imagePaths,
  isSelected,
  onSelect,
}: {
  value: string;
  label: string;
  imagePaths: string[];
  isSelected: boolean;
  onSelect: () => void;
}) {
  const [imgSrcIndex, setImgSrcIndex] = useState(0);
  const [imgError, setImgError] = useState(false);

  const handleError = () => {
    if (imgSrcIndex < imagePaths.length - 1) {
      setImgSrcIndex(imgSrcIndex + 1);
    } else {
      setImgError(true);
    }
  };

  return (
    <div
      onClick={onSelect}
      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
        isSelected
          ? 'border-2 border-gray-900 shadow-lg'
          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
      }`}
    >
      {isSelected && (
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); onSelect(); }}
          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
          title="Remove selection"
        >
          <X className="w-4 h-4 text-gray-600" />
        </button>
      )}
      <div className="aspect-square bg-white flex items-center justify-center overflow-hidden relative">
        {imgError ? (
          <ImageIcon className="w-16 h-16 text-gray-300" />
        ) : (
          <img
            src={imagePaths[imgSrcIndex]}
            alt={label}
            className="w-full h-full object-cover"
            style={{ display: 'block' }}
            onError={handleError}
          />
        )}
      </div>
      <div className="p-4 bg-gray-100 flex-1">
        <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={label}>
          {label}
        </h3>
      </div>
    </div>
  );
}

export default function OperatingSystemStep({
  config,
  onUpdate,
}: OperatingSystemStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const bomTemplateId = (config as any).bom_template_id;
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  
  // ✅ Templates filtrados desde HardwareStep
  const hardwareFilteredTemplates = (config as any)._hardware_filtered_templates as string[] | undefined;

  // ✅ Manufacturer filter (from ManufacturerStep) — used as fallback constraint
  const mfrFilteredTemplates = (config as any)._manufacturer_filtered_templates as string[] | undefined;
  const configManufacturer: string | undefined = (config as any).manufacturer;
  
  // ✅ Templates BASE del Hardware step (persistidos en config para sobrevivir al volver/desmontar)
  // Si no hay selección de operación, _hardware_filtered_templates ES la base.
  // Si ya hay selección, la base se guardó en _operating_system_base_templates al entrar sin selección.
  const operatingSystemBaseFromConfig = (config as any)._operating_system_base_templates as string[] | undefined;
  
  // Get BOM template questions to determine what to show
  const questions = useBOMTemplateQuestions(bomTemplateId);
  const showOperatingSystem = questions.requiredSteps.operatingSystem;
  const showDriveType = questions.selectQuestions.drive_type;
  
  const panelCount = (config as any).measurements?.panel_count ?? (config as any).panels?.length ?? 1;
  const operationType = (config as any).operation_type || (config as any).drive_type || undefined;
  const hardwareColor = (config as any).hardware_color || (config as any).hardwareColor || (config as any).operatingSystemColor || null;
  const motorItemId = (config as any).motor_item_id || undefined;
  const driveItemId = (config as any).drive_item_id || undefined;
  const tubeItemId = (config as any).tube_item_id || undefined;
  const selectedGearRatio: 'standard' | '1:1.5' | '1:3' = (config as any).gear_ratio || 'standard';

  const productType = (config as any).productType;
  const isDrapery = productType === 'drapery';
  
  // ✅ CRÍTICO: Determinar si ya hay CUALQUIER selección de operación
  const hasAnyOperationSelection = !!(operationType || motorItemId || driveItemId);
  
  // ✅ Persistir en config la base del Operating System (solo cuando no hay selección)
  // Así al volver al step o cambiar Manual↔Motor seguimos teniendo la base correcta
  useEffect(() => {
    if (!hardwareFilteredTemplates || hardwareFilteredTemplates.length === 0) return;
    if (hasAnyOperationSelection) return;
    const currentBase = operatingSystemBaseFromConfig;
    const newBase = [...new Set(hardwareFilteredTemplates)].sort();
    const same = currentBase && currentBase.length === newBase.length
      && newBase.every((id, i) => id === currentBase[i]);
    if (!same) {
      onUpdate({ _operating_system_base_templates: newBase } as any);
      if (import.meta.env.DEV) {
        console.debug('[OperatingSystemStep] Saved _operating_system_base_templates:', newBase.length);
      }
    }
  }, [hardwareFilteredTemplates, hasAnyOperationSelection]);
  
  // ✅ Base para opciones Manual/Motor: la guardada en config (entrada del step) o la actual
  const baseTemplatesForOptions = (operatingSystemBaseFromConfig && operatingSystemBaseFromConfig.length > 0)
    ? operatingSystemBaseFromConfig
    : hardwareFilteredTemplates;

  const uniq = (ids: string[] | null | undefined): string[] | null => {
    if (!ids) return null;
    const u = Array.from(new Set(ids.filter(Boolean)));
    return u.length > 0 ? u : null;
  };

  const relevantTemplateCount = (optionTemplateIds: string[] | undefined, currentIds: string[] | null | undefined) => {
    const a = optionTemplateIds ? Array.from(new Set(optionTemplateIds.filter(Boolean))) : [];
    if (!currentIds) return a.length;
    const s = new Set(currentIds);
    return a.filter(t => s.has(t)).length;
  };

  const notifyError = (message: string) => {
    useUIStore.getState().addNotification({
      type: 'error',
      title: 'BOM Selection',
      message,
    });
  };

  // ✅ ConfiguredProduct-based flow: selections are local until "Add to Quote".
  // Only require an organization context (quote_line_id is not needed anymore).
  const selectionDisabled = !activeOrganizationId;

  const ensurePersistable = (): boolean => {
    if (!activeOrganizationId) {
      notifyError('Organization not ready. Please select an organization before configuring products.');
      return false;
    }
    return true;
  };

  const persistSelection = async (componentRole: string, catalogItemId: string) => {
    if (!ensurePersistable()) return false;
    // No-op (ConfiguredProduct snapshot will be created at completion).
    return true;
  };

  const removeSelection = async (componentRole: string) => {
    if (!ensurePersistable()) return false;
    // No-op (ConfiguredProduct snapshot will be created at completion).
    return true;
  };

  // ✅ FILTRADO PROGRESIVO: Usar templates filtrados de Hardware step
  const canLoadOptions = !!productTypeId;

  // ✅ State para templates de fallback cuando hardwareFilteredTemplates está vacío
  const [loadedFallbackTemplates, setLoadedFallbackTemplates] = useState<string[] | null>(null);

  // ✅ Cargar templates de fallback cuando hardwareFilteredTemplates está vacío
  useEffect(() => {
    if (!canLoadOptions || !activeOrganizationId || !productTypeId) {
      setLoadedFallbackTemplates(null);
      return;
    }

    // Solo cargar fallback si no hay templates filtrados del Hardware step
    if (hardwareFilteredTemplates && hardwareFilteredTemplates.length > 0) {
      setLoadedFallbackTemplates(null);
      return;
    }

    let cancelled = false;
    const loadFallback = async () => {
      try {
        let query = supabase
          .from('BOMTemplates')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('product_type_id', productTypeId)
          .eq('is_active', true)
          .eq('archived', false);

        // ✅ FASE 1b: Aplicar AMBOS filtros cuando estén disponibles.
        // Antes: usaba else-if; si _manufacturer_filtered_templates estaba vacío
        // durante la hidratación, se perdía el scope del manufacturer y
        // aparecían motores de OTROS fabricantes (p.ej. Coulisse en escena Lutron).
        if (mfrFilteredTemplates && mfrFilteredTemplates.length > 0) {
          query = query.in('id', mfrFilteredTemplates);
        }
        if (configManufacturer) {
          query = query.ilike('manufacturer', configManufacturer);
        }

        const { data, error } = await query;

        if (error) throw error;

        if (!cancelled) {
          const templateIds = (data || []).map((t: { id: string }) => t.id);
          setLoadedFallbackTemplates(templateIds.length > 0 ? templateIds : null);
          if (import.meta.env.DEV) {
            console.debug('[OperatingSystemStep] Loaded fallback templates:', {
              count: templateIds.length,
              mfrFiltered: mfrFilteredTemplates?.length ?? 'none',
            });
          }
        }
      } catch (e: any) {
        if (!cancelled) {
          console.warn('[OperatingSystemStep] Failed to load fallback templates', e?.message || e);
          setLoadedFallbackTemplates(null);
        }
      }
    };

    loadFallback();
    return () => {
      cancelled = true;
    };
  }, [canLoadOptions, activeOrganizationId, productTypeId, hardwareFilteredTemplates, mfrFilteredTemplates?.join(','), configManufacturer]);

  // ✅ effectiveBaseTemplates: usa baseTemplatesForOptions o loadedFallbackTemplates como fallback
  const effectiveBaseTemplates = useMemo(() => baseTemplatesForOptions || loadedFallbackTemplates || null, [baseTemplatesForOptions, loadedFallbackTemplates]);

  // ✅ NUEVO: Separar templates por operación para evitar opciones “fantasma”
  // Regla: motor/tube NO filtran por color, PERO manual vs motor debe separar templates:
  // - manual: tiene drive y NO tiene motor
  // - motor: tiene motor y NO tiene drive (si existen templates mixtos, se resolverán por selección SKU)
  const [manualTemplateIds, setManualTemplateIds] = useState<string[] | null>(null);
  const [motorTemplateIds, setMotorTemplateIds] = useState<string[] | null>(null);

  useEffect(() => {
    if (!canLoadOptions) {
      setManualTemplateIds(null);
      setMotorTemplateIds(null);
      return;
    }
    // ✅ MEJORADO: Usar effectiveBaseTemplates
    if (!effectiveBaseTemplates || effectiveBaseTemplates.length === 0) {
      setManualTemplateIds(null);
      setMotorTemplateIds(null);
      return;
    }

    let cancelled = false;
    const loadRolePresence = async () => {
      try {
        // Load component roles AND template drive_type for drapery support
        const [compResult, templateResult] = await Promise.all([
          supabase
            .from('BOMComponents')
            .select('bom_template_id, component_role')
            .in('bom_template_id', effectiveBaseTemplates)
            .is('parent_component_id', null)
            .eq('deleted', false)
            .eq('archived', false),
          supabase
            .from('BOMTemplates')
            .select('id, drive_type')
            .in('id', effectiveBaseTemplates),
        ]);

        if (compResult.error) throw compResult.error;

        const hasMotor = new Set<string>();
        const hasDrive = new Set<string>();

        (compResult.data || []).forEach((row: any) => {
          const tid = row.bom_template_id as string;
          const role = String(row.component_role || '').toLowerCase().trim();
          if (role === 'motor') hasMotor.add(tid);
          if (role === 'drive') hasDrive.add(tid);
        });

        // For drapery: manual templates have wand (not drive), so use drive_type field
        const templateDriveTypes = new Map<string, string>();
        (templateResult.data || []).forEach((t: any) => {
          if (t.drive_type) templateDriveTypes.set(t.id, t.drive_type);
        });

        const manualIds = effectiveBaseTemplates.filter((tid: string) =>
          hasDrive.has(tid) || templateDriveTypes.get(tid) === 'manual'
        );
        const motorIds = effectiveBaseTemplates.filter((tid: string) =>
          hasMotor.has(tid) || templateDriveTypes.get(tid) === 'motor'
        );
        
        if (import.meta.env.DEV) {
          console.debug('[OperatingSystemStep] Role presence:', {
            templatesWithDrive: hasDrive.size,
            templatesWithMotor: hasMotor.size,
            driveTemplateIds: Array.from(hasDrive).slice(0, 3),
            motorTemplateIds: Array.from(hasMotor).slice(0, 3),
          });
        }

        if (!cancelled) {
          setManualTemplateIds(manualIds);
          setMotorTemplateIds(motorIds);
          if (import.meta.env.DEV) {
            console.debug('[OperatingSystemStep] operation template split', {
              effectiveBase: effectiveBaseTemplates.length,
              manualIds: manualIds.length,
              motorIds: motorIds.length,
            });
          }
        }
      } catch (e: any) {
        if (!cancelled) {
          // fallback: no split
          setManualTemplateIds(null);
          setMotorTemplateIds(null);
          if (import.meta.env.DEV) {
            console.warn('[OperatingSystemStep] failed to split templates by operation', e?.message || e);
          }
        }
      }
    };

    loadRolePresence();
    return () => {
      cancelled = true;
    };
  }, [canLoadOptions, effectiveBaseTemplates?.join(',')]); // ✅ Dependencia correcta

  const templatesForManual = useMemo(() => {
    // ✅ si split no aplica, usar effective base (incluye fallback)
    return manualTemplateIds && manualTemplateIds.length > 0 ? manualTemplateIds : effectiveBaseTemplates;
  }, [manualTemplateIds, effectiveBaseTemplates]);

  const templatesForMotor = useMemo(() => {
    // ✅ si split no aplica, usar effective base (incluye fallback)
    return motorTemplateIds && motorTemplateIds.length > 0 ? motorTemplateIds : effectiveBaseTemplates;
  }, [motorTemplateIds, effectiveBaseTemplates]);
  
  // ✅ Motor: desde templates filtrados (motor NO depende de color)
  const { options: motorOptions, loading: loadingMotor, error: motorError } = useBOMTemplateOptionsSimple(
    canLoadOptions ? productTypeId : null,
    null,
    'motor',
    templatesForMotor,
    panelCount
  );
  
  // ✅ Drive: desde templates filtrados (drive SÍ depende de color)
  const { options: driveOptions, loading: loadingDrive, error: driveError } = useBOMTemplateOptionsSimple(
    canLoadOptions ? productTypeId : null,
    canLoadOptions ? hardwareColor : null,
    'drive',
    templatesForManual,
    panelCount
  );
  
  // Gear ratio: determine which ratios are available from drive options
  const availableGearRatios = useMemo(() => {
    const ratios = new Set<string>();
    driveOptions.forEach(opt => ratios.add(opt.gear_ratio || 'standard'));
    return ratios;
  }, [driveOptions]);

  // Filter drive options by selected gear ratio (only when there are multiple ratios)
  const filteredDriveOptions = useMemo(() => {
    if (availableGearRatios.size <= 1) return driveOptions;
    return driveOptions.filter(opt => (opt.gear_ratio || 'standard') === selectedGearRatio);
  }, [driveOptions, selectedGearRatio, availableGearRatios]);

  // ✅ Calcular templates filtrados por motor/drive seleccionado
  const selectedMotor = motorOptions.find(opt => opt.id === motorItemId);
  const selectedDrive = driveOptions.find(opt => opt.id === driveItemId);
  
  const templatesAfterOperation = useMemo(() => {
    // ✅ Usar effectiveBaseTemplates como fallback cuando no hay operationType
    const base =
      operationType === 'motor'
        ? (templatesForMotor || null)
        : operationType === 'manual'
        ? (templatesForManual || null)
        : (effectiveBaseTemplates || null);
    
    if (operationType === 'motor' && selectedMotor?.templateIds) {
      if (base) {
        const set = new Set(selectedMotor.templateIds);
        return base.filter((tid: string) => set.has(tid));
      }
      return selectedMotor.templateIds;
    }
    
    if (operationType === 'manual' && selectedDrive?.templateIds) {
      if (base) {
        const set = new Set(selectedDrive.templateIds);
        return base.filter((tid: string) => set.has(tid));
      }
      return selectedDrive.templateIds;
    }
    
    return base;
  }, [operationType, selectedMotor, selectedDrive, effectiveBaseTemplates, templatesForMotor, templatesForManual]);
  
  // ✅ FASE 2: Bloquear carga de tubos hasta que selectedMotor/selectedDrive esté hidratado.
  // Si motorItemId/driveItemId está seteado pero la opción todavía no se cargó, evitamos
  // mostrar tubos del set amplio (LUT + LUT64) que permitirían seleccionar combinaciones
  // inválidas (ej. EDU-64 + LUT-63). Cuando selectedMotor llega, templatesAfterOperation
  // se reduce al template real del motor y los tubos correctos aparecen.
  const isMotorReady = operationType !== 'motor' || !motorItemId || (!!selectedMotor && (selectedMotor.templateIds?.length ?? 0) > 0);
  const isDriveReady = operationType !== 'manual' || !driveItemId || (!!selectedDrive && (selectedDrive.templateIds?.length ?? 0) > 0);
  const operationCascadeReady = isMotorReady && isDriveReady;

  // ✅ Tube: desde templates filtrados por motor/drive (tube NO depende de color) — skip for drapery
  const { options: tubeOptionsRaw, loading: loadingTube, error: tubeError } = useBOMTemplateOptionsSimple(
    canLoadOptions && !isDrapery && operationCascadeReady ? productTypeId : null,
    null,
    'tube',
    isDrapery ? null : templatesAfterOperation,
    panelCount
  );

  // ✅ FASE 2: Filtrado estricto de compatibilidad.
  // Aún si templatesAfterOperation se ensanchó por algún edge case, garantizamos que
  // SOLO se muestren tubos cuyos templateIds intersecten con los del motor/drive
  // realmente seleccionado. Es la última línea de defensa contra combinaciones inválidas.
  const tubeOptions = useMemo(() => {
    if (operationType === 'motor' && motorItemId) {
      const motorTemplates = selectedMotor?.templateIds || [];
      if (motorTemplates.length === 0) return [];
      const motorTids = new Set(motorTemplates);
      return tubeOptionsRaw.filter(opt =>
        (opt.templateIds || []).some(t => motorTids.has(t))
      );
    }
    if (operationType === 'manual' && driveItemId) {
      const driveTemplates = selectedDrive?.templateIds || [];
      if (driveTemplates.length === 0) return [];
      const driveTids = new Set(driveTemplates);
      return tubeOptionsRaw.filter(opt =>
        (opt.templateIds || []).some(t => driveTids.has(t))
      );
    }
    return tubeOptionsRaw;
  }, [tubeOptionsRaw, operationType, motorItemId, driveItemId, selectedMotor, selectedDrive]);

  const loading = loadingMotor || loadingDrive || loadingTube;

  // ✅ Calcular templates finales después de seleccionar tube
  const selectedTube = tubeOptions.find(opt => opt.id === tubeItemId);
  const finalFilteredTemplates = useMemo(() => {
    if (!selectedTube || !selectedTube.templateIds) {
      return templatesAfterOperation;
    }
    if (templatesAfterOperation) {
      const set = new Set(selectedTube.templateIds);
      return templatesAfterOperation.filter(tid => set.has(tid));
    }
    return selectedTube.templateIds;
  }, [selectedTube, templatesAfterOperation]);

  // ✅ Guardar templates finales en config para el matcher
  useEffect(() => {
    if (finalFilteredTemplates && finalFilteredTemplates.length > 0) {
      const currentSaved = (config as any)._hardware_filtered_templates;
      const deduped = [...new Set(finalFilteredTemplates)];
      const newValue = JSON.stringify([...deduped].sort());
      const oldValue = currentSaved ? JSON.stringify(currentSaved.sort()) : '';

      if (newValue !== oldValue) {
        onUpdate({
          _hardware_filtered_templates: deduped,
        } as any);

        if (import.meta.env.DEV) {
          console.debug('[OperatingSystemStep] Updated filtered templates:', deduped.length);
        }
      }
    }
  }, [finalFilteredTemplates]);

  // ✅ FASE 2: Auto-corregir tube_item_id stale cuando es incompatible con el motor/drive.
  // Edge case: una línea fue guardada (en una versión previa sin esta validación) con un
  // tube que NO existe en el template del motor/drive. Al detectar el mismatch, lo limpiamos
  // para forzar al usuario a re-elegir un tube compatible y evitar instabilidad downstream.
  useEffect(() => {
    if (!tubeItemId) return;
    if (loadingTube) return;
    if (!operationCascadeReady) return;
    if (tubeOptionsRaw.length === 0) return;
    const stillExistsInRaw = tubeOptionsRaw.some(opt => opt.id === tubeItemId);
    const isCompatible = tubeOptions.some(opt => opt.id === tubeItemId);
    if (stillExistsInRaw && !isCompatible) {
      if (import.meta.env.DEV) {
        console.warn('[OperatingSystemStep] Auto-clearing stale tube_item_id (incompatible with motor/drive):', tubeItemId);
      }
      onUpdate({
        tube_item_id: undefined,
        tube_sku: null,
        tube_type: undefined,
      } as any);
    }
  }, [tubeItemId, loadingTube, operationCascadeReady, tubeOptions, tubeOptionsRaw]);

  // Debug logging for results
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Progressive filtering', {
        productTypeId,
        hardwareColor,
        hardwareFilteredTemplates: hardwareFilteredTemplates?.length ?? 'none',
        operationType,
        motorCount: motorOptions.length,
        driveCount: driveOptions.length,
        templatesAfterOperation: templatesAfterOperation?.length ?? 'all',
        tubeCount: tubeOptions.length,
        finalFilteredTemplates: finalFilteredTemplates?.length ?? 'all',
      });
    }
  }, [productTypeId, hardwareColor, hardwareFilteredTemplates, operationType, motorOptions.length, driveOptions.length, templatesAfterOperation, tubeOptions.length, finalFilteredTemplates]);

  // Operating system type options
  const operatingSystemOptions: Array<{ value: 'manual' | 'motor'; label: string }> = [
    { value: 'manual', label: 'Manual' },
    { value: 'motor', label: 'Motor' },
  ];

  // ✅ Track image load errors
  const [imageErrors, setImageErrors] = useState<Record<string, boolean>>({});
  const defaultImageSources = useMemo(() => ({
    manual: isDrapery ? '/images/DR_Manual.png' : '/images/drive-manual.png',
    motor: isDrapery ? '/images/DR_Motor.png' : '/images/drive-motor.png',
  }), [isDrapery]);
  const [imageSources, setImageSources] = useState<Record<string, string>>(defaultImageSources);

  useEffect(() => {
    setImageSources(defaultImageSources);
    setImageErrors({});
  }, [defaultImageSources]);

  const handleImageError = (optionValue: string, currentSrc: string) => {
    const formats = ['png', 'jpg', 'jpeg', 'webp'];
    const basePath = currentSrc.replace(/\.(jpg|jpeg|png|webp)$/i, '');
    const currentFormat = currentSrc.match(/\.(jpg|jpeg|png|webp)$/i)?.[1]?.toLowerCase();
    const currentFormatIndex = currentFormat ? formats.indexOf(currentFormat) : -1;
    
    if (currentFormatIndex >= 0 && currentFormatIndex < formats.length - 1) {
      const nextFormat = formats[currentFormatIndex + 1];
      setImageSources(prev => ({
        ...prev,
        [optionValue]: `${basePath}.${nextFormat}`,
      }));
    } else {
      setImageErrors(prev => ({ ...prev, [optionValue]: true }));
    }
  };

  const handleOperatingSystemChange = async (value: 'manual' | 'motor') => {
    if (!ensurePersistable()) return;
    // ✅ REMOVIDO: guardrail que bloqueaba el cambio
    // El usuario debe poder cambiar libremente entre Manual y Motor
    // Si no hay opciones, verá el mensaje "No options available"

    const updates: any = {
      operation_type: value,
      drive_type: value,
      operatingSystem: value === 'manual' ? 'manual' : 'motorized',
    };
    
    // Clear selections when switching
    if (value === 'motor') {
      const okDrive = await removeSelection('drive');
      const okTube = await removeSelection('tube');
      if (!okDrive || !okTube) return;
      updates.manual_drive = undefined;
      updates.drive_item_id = undefined;
      updates.drive_sku = null;
      // ✅ Resetear a templates de Motor (usando effectiveBaseTemplates como origen)
      updates._hardware_filtered_templates = uniq(templatesForMotor) ?? uniq(effectiveBaseTemplates) ?? null;
    } else {
      const okMotor = await removeSelection('motor');
      const okTube = await removeSelection('tube');
      if (!okMotor || !okTube) return;
      updates.motor_family = undefined;
      updates.motor_item_id = undefined;
      updates.motor_sku = null;
      updates.remote_control = undefined;
      // ✅ Resetear a templates de Manual (usando effectiveBaseTemplates como origen)
      updates._hardware_filtered_templates = uniq(templatesForManual) ?? uniq(effectiveBaseTemplates) ?? null;
    }
    
    // Clear tube when switching operation type
    updates.tube_item_id = undefined;
    updates.tube_sku = null;
    updates.tube_type = undefined;
    
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Switching to:', value, {
        templatesForMotor: templatesForMotor?.length,
        templatesForManual: templatesForManual?.length,
        effectiveBaseTemplates: effectiveBaseTemplates?.length,
      });
    }
    
    onUpdate(updates);
  };

  const handleMotorSelect = async (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    if (isVirtual) {
      notifyError('Invalid motor selection (virtual SKU).');
      return;
    }
    const ok = await persistSelection('motor', String(item.id));
    if (!ok) return;
    
    // ✅ Calcular templates filtrados usando templatesForMotor
    let newFilteredTemplates = item.templateIds || [];
    const motorBase = templatesForMotor || effectiveBaseTemplates;
    if (motorBase && motorBase.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = motorBase.filter((tid: string) => set.has(tid));
    }
    newFilteredTemplates = uniq(newFilteredTemplates) || [];
    
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Motor selected:', {
        sku: item.sku,
        templateIds: newFilteredTemplates.length,
      });
    }
    
    onUpdate({
      motor_item_id: isVirtual ? null : item.id,
      motor_sku: item.sku,
      motor_family: item.name,
      drive_item_id: undefined,
      drive_sku: null,
      manual_drive: undefined,
      // Clear tube when motor changes
      tube_item_id: undefined,
      tube_sku: null,
      tube_type: undefined,
      // ✅ Guardar templates filtrados con fallback a effectiveBaseTemplates
      _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : uniq(templatesForMotor) ?? uniq(effectiveBaseTemplates) ?? null,
    } as any);
  };

  const handleDriveSelect = async (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    if (isVirtual) {
      notifyError('Invalid drive selection (virtual SKU).');
      return;
    }
    const ok = await persistSelection('drive', String(item.id));
    if (!ok) return;
    
    // ✅ Calcular templates filtrados usando templatesForManual
    let newFilteredTemplates = item.templateIds || [];
    const manualBase = templatesForManual || effectiveBaseTemplates;
    if (manualBase && manualBase.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = manualBase.filter((tid: string) => set.has(tid));
    }
    newFilteredTemplates = uniq(newFilteredTemplates) || [];
    
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Drive selected:', {
        sku: item.sku,
        templateIds: newFilteredTemplates.length,
      });
    }
    
    const gearRatio = item.gear_ratio || 'standard';

    onUpdate({
      drive_item_id: isVirtual ? null : item.id,
      drive_sku: item.sku,
      manual_drive: item.name,
      gear_ratio: gearRatio,
      motor_item_id: undefined,
      motor_sku: null,
      motor_family: undefined,
      remote_control: undefined,
      tube_item_id: undefined,
      tube_sku: null,
      tube_type: undefined,
      _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : uniq(templatesForManual) ?? uniq(effectiveBaseTemplates) ?? null,
    } as any);
  };

  const handleTubeSelect = async (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    if (isVirtual) {
      notifyError('Invalid tube selection (virtual SKU).');
      return;
    }

    // ✅ FASE 2: Validar compatibilidad motor/drive ↔ tube ANTES de aplicar.
    // Bloquea selección de combinaciones inválidas (ej. EDU-64 + LUT-63 que no comparten template).
    const tubeTids = item.templateIds || [];
    if (operationType === 'motor' && motorItemId && selectedMotor) {
      const motorTids = new Set(selectedMotor.templateIds || []);
      const overlap = tubeTids.some(t => motorTids.has(t));
      if (!overlap) {
        notifyError(`Tube "${item.name || item.sku}" is not compatible with motor "${selectedMotor.name || selectedMotor.sku}". Please choose a tube available in the same template.`);
        return;
      }
    }
    if (operationType === 'manual' && driveItemId && selectedDrive) {
      const driveTids = new Set(selectedDrive.templateIds || []);
      const overlap = tubeTids.some(t => driveTids.has(t));
      if (!overlap) {
        notifyError(`Tube "${item.name || item.sku}" is not compatible with drive "${selectedDrive.name || selectedDrive.sku}". Please choose a tube available in the same template.`);
        return;
      }
    }

    const ok = await persistSelection('tube', String(item.id));
    if (!ok) return;
    
    // ✅ Calcular templates finales después de seleccionar tube
    let finalTemplates = templatesAfterOperation;
    if (item.templateIds && item.templateIds.length > 0) {
      if (templatesAfterOperation) {
        const set = new Set(item.templateIds);
        finalTemplates = templatesAfterOperation.filter(tid => set.has(tid));
      } else {
        finalTemplates = item.templateIds;
      }
    }
    
    onUpdate({
      tube_item_id: isVirtual ? null : item.id,
      tube_type: item.sku,
      tube_sku: item.sku,
      // ✅ Guardar templates finales
      _hardware_filtered_templates: uniq(finalTemplates as any) ?? null,
    } as any);
  };

  const clearOperationType = async () => {
    if (!ensurePersistable()) return;
    const okMotor = await removeSelection('motor');
    const okDrive = await removeSelection('drive');
    const okTube = await removeSelection('tube');
    if (!okMotor || !okDrive || !okTube) return;
    
    onUpdate({
      operation_type: undefined,
      drive_type: undefined,
      operatingSystem: undefined,
      drive_item_id: undefined,
      drive_sku: null,
      manual_drive: undefined,
      motor_item_id: undefined,
      motor_sku: null,
      motor_family: undefined,
      remote_control: undefined,
      tube_item_id: undefined,
      tube_sku: null,
      tube_type: undefined,
      // ✅ Usar effectiveBaseTemplates para restaurar al estado original
      _hardware_filtered_templates: uniq(effectiveBaseTemplates) ?? null,
    } as any);
  };

  // Don't render if operating system step is not required
  if (!showOperatingSystem) {
    return null;
  }
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        {selectionDisabled && (
          <div className="bg-amber-50 border border-amber-200 rounded p-3">
            <p className="text-xs text-amber-800">
              Save the quote first to enable BOM selections.
            </p>
          </div>
        )}
        <div className={`space-y-8 ${selectionDisabled ? 'pointer-events-none opacity-50' : ''}`}>
        <div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Operating System</h3>
          <p className="text-sm text-gray-600">
            Select the operating system type and choose the specific components.
          </p>
        </div>

        {/* Drive Side (Left/Right) — hidden for drapery since it's in MeasurementsStep */}
        {(() => {
          const pt = (config as any).productType || '';
          const isDrapery = pt === 'drapery';
          if (isDrapery) return null;
          const currentDriveSide = (config as any).driveSide || (config as any).drive_side || null;
          const driveSideOptions: Array<{ value: 'left' | 'right'; label: string; imagePaths: string[] }> = [
            {
              value: 'left',
              label: 'Left',
              imagePaths: ['/images/Drive Left .png'],
            },
            {
              value: 'right',
              label: 'Right',
              imagePaths: ['/images/Driver Right.png'],
            },
          ];
          return (
            <div>
              <Label className="text-sm font-medium mb-3 block">DRIVE SIDE</Label>
              <p className="text-xs text-gray-500 mb-3">Select where the motor or chain drive will be positioned (facing the window from inside)</p>
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {driveSideOptions.map((side) => {
                  const isSelected = currentDriveSide === side.value;
                  return (
                    <DriveSideCard
                      key={side.value}
                      value={side.value}
                      label={side.label}
                      imagePaths={side.imagePaths}
                      isSelected={isSelected}
                      onSelect={() => {
                        if (isSelected) {
                          onUpdate({ driveSide: undefined } as any);
                        } else {
                          onUpdate({ driveSide: side.value } as any);
                        }
                      }}
                    />
                  );
                })}
              </div>
            </div>
          );
        })()}

        {/* Operating System Type (Manual/Motor) */}
        {showDriveType && (
          <div>
            <Label className="text-sm font-medium mb-5 block">OPERATION TYPE</Label>
            <p className="text-xs text-gray-500 mb-2">Determines which drive block components are included in the BOM</p>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
              {operatingSystemOptions.map((option) => {
                const isSelected = operationType === option.value;
                const imageError = imageErrors[option.value] || false;
                
                // ✅ Verificar si hay opciones disponibles para este tipo
                const hasOptions = option.value === 'motor' 
                  ? motorOptions.length > 0 
                  : driveOptions.length > 0;
                
                return (
                  <div
                    key={option.value}
                    onClick={async () => {
                      if (selectionDisabled) return;
                      await handleOperatingSystemChange(option.value);
                    }}
                    className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    } ${selectionDisabled ? 'opacity-50' : ''}`}
                  >
                    {/* X to deselect */}
                    {isSelected && (
                      <button
                        type="button"
                        onClick={async (e) => {
                          e.stopPropagation();
                          if (selectionDisabled) return;
                          await clearOperationType();
                        }}
                        className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div className="aspect-square bg-white flex items-center justify-center overflow-hidden relative">
                      {imageError ? (
                        <ImageIcon className="w-16 h-16 text-gray-300" />
                      ) : (
                        <img
                          src={imageSources[option.value]}
                          alt={option.label}
                          className="w-full h-full object-cover"
                          style={{ display: 'block' }}
                          onError={(e) => handleImageError(option.value, (e.target as HTMLImageElement).src)}
                        />
                      )}
                    </div>
                    
                    <div className="p-4 bg-gray-100 flex-1">
                      <h3 className={`font-semibold text-sm truncate text-center ${
                        isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'
                      }`} title={option.label}>
                        {option.label}
                      </h3>
                      {!hasOptions && !loading && !isDrapery && (
                        <p className="text-xs text-gray-400 text-center mt-1">
                          No options available
                        </p>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Motor Selection (only if motor) */}
        {operationType === 'motor' && (
          <div>
            <Label className="text-sm font-medium mb-5 block">MOTORS</Label>
            {loadingMotor ? (
              <div className="text-sm text-gray-500 mt-2">Loading motors...</div>
            ) : motorOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {motorOptions.filter(item => !motorItemId || item.id === motorItemId).map((item) => {
                  const isSelected = motorItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={async () => {
                        if (selectionDisabled) return;
                        await handleMotorSelect(item);
                      }}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            if (selectionDisabled) return;
                            const okMotor = await removeSelection('motor');
                            const okTube = await removeSelection('tube');
                            if (!okMotor || !okTube) return;
                            onUpdate({
                              motor_item_id: undefined,
                              motor_sku: null,
                              motor_family: undefined,
                              remote_control: undefined,
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              // ✅ Volver a templatesForMotor (no afecta opciones de Manual) con fallback
                              _hardware_filtered_templates: uniq(templatesForMotor as any) ?? uniq(effectiveBaseTemplates) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                        <CatalogItemImage
                          src={item.image_url}
                          alt={item.name || item.sku}
                          size="lg"
                          objectFit="contain"
                          className="w-full h-full !rounded-none !border-0"
                        />
                      </div>
                      <div className="p-4 bg-gray-100 flex-1">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No motors available for ProductType
              </div>
            )}
          </div>
        )}

        {/* Gear Ratio Selection (only if manual, not drapery, and multiple ratios available) */}
        {operationType === 'manual' && !isDrapery && availableGearRatios.size > 1 && (
          <div>
            <Label className="text-sm font-medium mb-5 block">GEAR RATIO</Label>
            <div className="grid grid-cols-3 gap-4 max-w-md">
              {(['standard', '1:1.5', '1:3'] as const).filter(r => availableGearRatios.has(r)).map((ratio) => {
                const isSelected = selectedGearRatio === ratio;
                const label = ratio === 'standard' ? 'Standard' : ratio;
                return (
                  <button
                    key={ratio}
                    type="button"
                    onClick={() => {
                      onUpdate({
                        gear_ratio: ratio,
                        drive_item_id: undefined,
                        drive_sku: null,
                        manual_drive: undefined,
                        tube_item_id: undefined,
                        tube_sku: null,
                        tube_type: undefined,
                      } as any);
                    }}
                    className={`px-4 py-3 text-sm font-medium rounded-lg border-2 transition-all ${
                      isSelected
                        ? 'border-gray-900 bg-gray-900 text-white shadow-md'
                        : 'border-gray-200 bg-white text-gray-700 hover:border-gray-400 hover:shadow-sm'
                    }`}
                  >
                    {label}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Manual Drive Selection (only if manual) — drapery uses wand from template, no selection needed */}
        {operationType === 'manual' && !isDrapery && (
          <div>
            <Label className="text-sm font-medium mb-5 block">MECHANISM / MANUAL DRIVE</Label>
            {loadingDrive ? (
              <div className="text-sm text-gray-500 mt-2">Loading drive options...</div>
            ) : filteredDriveOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {filteredDriveOptions.filter(item => !driveItemId || item.id === driveItemId).map((item) => {
                  const isSelected = driveItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={async () => {
                        if (selectionDisabled) return;
                        await handleDriveSelect(item);
                      }}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            if (selectionDisabled) return;
                            const okDrive = await removeSelection('drive');
                            const okTube = await removeSelection('tube');
                            if (!okDrive || !okTube) return;
                            onUpdate({
                              drive_item_id: undefined,
                              drive_sku: null,
                              manual_drive: undefined,
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              // ✅ Volver a templatesForManual (no afecta opciones de Motor) con fallback
                              _hardware_filtered_templates: uniq(templatesForManual as any) ?? uniq(effectiveBaseTemplates) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                        <CatalogItemImage
                          src={item.image_url}
                          alt={item.name || item.sku}
                          size="lg"
                          objectFit="contain"
                          className="w-full h-full !rounded-none !border-0"
                        />
                      </div>
                      <div className="p-4 bg-gray-100 flex-1">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        {item.gear_ratio && item.gear_ratio !== 'standard' && (
                          <span className="inline-block mt-1 px-2 py-0.5 text-xs font-medium bg-blue-100 text-blue-700 rounded">
                            {item.gear_ratio}
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No manual drive options available for {selectedGearRatio !== 'standard' ? `gear ratio ${selectedGearRatio}` : 'current selection'}
              </div>
            )}
          </div>
        )}

        {/* Tube Selection (show when motor or drive is selected) — NOT for drapery */}
        {!isDrapery && ((operationType === 'motor' && motorItemId) || (operationType === 'manual' && driveItemId)) && (
          <div>
            <Label className="text-sm font-medium mb-5 block">TUBE TYPE</Label>
            {loadingTube ? (
              <div className="text-sm text-gray-500 mt-2">Loading tube options...</div>
            ) : tubeOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
                {tubeOptions.filter(item => !tubeItemId || item.id === tubeItemId).map((item) => {
                  const isSelected = tubeItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={async () => {
                        if (selectionDisabled) return;
                        await handleTubeSelect(item);
                      }}
                      className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-gray-900 shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      } ${selectionDisabled ? 'opacity-50' : ''}`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={async (e) => {
                            e.stopPropagation();
                            if (selectionDisabled) return;
                            const okTube = await removeSelection('tube');
                            if (!okTube) return;
                            // ✅ Volver al estado antes de seleccionar tube
                            // templatesAfterOperation ya tiene en cuenta motor/drive seleccionado
                            const targetTemplates = operationType === 'motor'
                              ? (selectedMotor?.templateIds ? 
                                  (templatesForMotor || []).filter((tid: string) => new Set(selectedMotor.templateIds).has(tid)) 
                                  : templatesForMotor)
                              : operationType === 'manual'
                              ? (selectedDrive?.templateIds ?
                                  (templatesForManual || []).filter((tid: string) => new Set(selectedDrive.templateIds).has(tid))
                                  : templatesForManual)
                              : effectiveBaseTemplates;
                            
                            onUpdate({
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              _hardware_filtered_templates: uniq(targetTemplates as any) ?? uniq(effectiveBaseTemplates) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-white border-b border-gray-200">
                        <CatalogItemImage
                          src={item.image_url}
                          alt={item.name || item.sku}
                          size="lg"
                          objectFit="contain"
                          className="w-full h-full !rounded-none !border-0"
                        />
                      </div>
                      <div className="p-4 bg-gray-100 flex-1">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-gray-900 font-semibold' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No tube options available for current selection
              </div>
            )}
          </div>
        )}
        </div>
      </div>
    </div>
  );
}
