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

import { useEffect, useState, useMemo, useRef } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useBOMTemplateQuestions } from '../../../hooks/useBOMTemplateQuestions';
import { useBOMTemplateOptionsSimple, RoleOption } from '../../../hooks/useBOMTemplateOptionsSimple';
import { Image as ImageIcon, X } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';

interface OperatingSystemStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (updates: Partial<CurtainConfiguration | ProductConfig>) => void;
  /** Templates filtrados desde HardwareStep */
  filteredTemplateIds?: string[];
}

export default function OperatingSystemStep({
  config,
  onUpdate,
}: OperatingSystemStepProps) {
  const bomTemplateId = (config as any).bom_template_id;
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  
  // ✅ Templates filtrados desde HardwareStep
  const hardwareFilteredTemplates = (config as any)._hardware_filtered_templates as string[] | undefined;
  
  // ✅ NUEVO: Guardar los templates BASE del Hardware step (antes de cualquier selección de Motor/Drive)
  // Esto evita que al seleccionar Motor, los templates de Manual desaparezcan
  const baseTemplatesRef = useRef<string[] | null>(null);
  
  // Get BOM template questions to determine what to show
  const questions = useBOMTemplateQuestions(bomTemplateId);
  const showOperatingSystem = questions.requiredSteps.operatingSystem;
  const showDriveType = questions.selectQuestions.drive_type;
  
  // Get current selections (CAPITALIZED colors to match DB)
  const operationType = (config as any).operation_type || (config as any).drive_type || undefined;
  const hardwareColor = (config as any).hardware_color || (config as any).hardwareColor || (config as any).operatingSystemColor || null;
  const motorItemId = (config as any).motor_item_id || undefined;
  const driveItemId = (config as any).drive_item_id || undefined;
  const tubeItemId = (config as any).tube_item_id || undefined;
  
  // ✅ CRÍTICO: Determinar si ya hay CUALQUIER selección de operación
  // Incluir operationType para que cuando el usuario clickea Manual/Motor,
  // los templates base NO se sobreescriban
  const hasAnyOperationSelection = !!(operationType || motorItemId || driveItemId);
  
  // ✅ Capturar templates base en MONTAJE INICIAL o cuando no hay selección
  // Si ya hay selección pero no tenemos base capturado, intentar recuperar de HardwareStep
  useEffect(() => {
    // Capturar solo si NO tenemos base capturado O si no hay selección
    if (hardwareFilteredTemplates && hardwareFilteredTemplates.length > 0) {
      if (!hasAnyOperationSelection) {
        // Sin selección: capturar como templates puros del Hardware step
        baseTemplatesRef.current = [...hardwareFilteredTemplates];
        if (import.meta.env.DEV) {
          console.debug('[OperatingSystemStep] Captured base templates (no selection):', hardwareFilteredTemplates.length);
        }
      } else if (!baseTemplatesRef.current || baseTemplatesRef.current.length === 0) {
        // Con selección pero sin base: usar los actuales como fallback inicial
        // Esto puede pasar al volver a este step después de navegar
        baseTemplatesRef.current = [...hardwareFilteredTemplates];
        if (import.meta.env.DEV) {
          console.debug('[OperatingSystemStep] Captured base templates (fallback on mount):', hardwareFilteredTemplates.length);
        }
      }
    }
  }, [hardwareFilteredTemplates, hasAnyOperationSelection]);
  
  // ✅ Los templates base para calcular opciones de Manual y Motor
  // Usa los capturados, o si no hay, usa los actuales
  const baseTemplatesForOptions = baseTemplatesRef.current && baseTemplatesRef.current.length > 0
    ? baseTemplatesRef.current
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

  // ✅ FILTRADO PROGRESIVO: Usar templates filtrados de Hardware step
  const canLoadOptions = !!productTypeId;

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
    // ✅ Usar baseTemplatesForOptions en lugar de hardwareFilteredTemplates
    // Esto asegura que aunque Motor esté seleccionado, Manual todavía muestre sus opciones
    if (!baseTemplatesForOptions || baseTemplatesForOptions.length === 0) {
      setManualTemplateIds(null);
      setMotorTemplateIds(null);
      return;
    }

    let cancelled = false;
    const loadRolePresence = async () => {
      try {
        const { data, error } = await supabase
          .from('BOMComponents')
          .select('bom_template_id, component_role')
          .in('bom_template_id', baseTemplatesForOptions)
          .is('parent_component_id', null)
          .eq('deleted', false)
          .eq('archived', false);

        if (error) throw error;

        const hasMotor = new Set<string>();
        const hasDrive = new Set<string>();

        (data || []).forEach((row: any) => {
          const tid = row.bom_template_id as string;
          const role = String(row.component_role || '').toLowerCase().trim();
          if (role === 'motor') hasMotor.add(tid);
          if (role === 'drive') hasDrive.add(tid);
        });

        // ✅ SIMPLIFICADO: Templates que tienen el rol correspondiente
        // NO excluir templates que tienen ambos roles - dejar que el matching final decida
        const manualIds = baseTemplatesForOptions.filter(tid => hasDrive.has(tid));
        const motorIds = baseTemplatesForOptions.filter(tid => hasMotor.has(tid));
        
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
              base: baseTemplatesForOptions.length,
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
  }, [canLoadOptions, baseTemplatesForOptions?.join(',')]); // ✅ Dependencia correcta

  const templatesForManual = useMemo(() => {
    // ✅ si split no aplica, usar base templates (no los filtrados actuales)
    return manualTemplateIds && manualTemplateIds.length > 0 ? manualTemplateIds : baseTemplatesForOptions;
  }, [manualTemplateIds, baseTemplatesForOptions]);

  const templatesForMotor = useMemo(() => {
    // ✅ si split no aplica, usar base templates (no los filtrados actuales)
    return motorTemplateIds && motorTemplateIds.length > 0 ? motorTemplateIds : baseTemplatesForOptions;
  }, [motorTemplateIds, baseTemplatesForOptions]);
  
  // ✅ Motor: desde templates filtrados (motor NO depende de color)
  const { options: motorOptions, loading: loadingMotor, error: motorError } = useBOMTemplateOptionsSimple(
    canLoadOptions ? productTypeId : null,
    null, // Motor no depende de color
    'motor',
    templatesForMotor // ✅ solo templates motor cuando aplica
  );
  
  // ✅ Drive: desde templates filtrados (drive SÍ depende de color)
  const { options: driveOptions, loading: loadingDrive, error: driveError } = useBOMTemplateOptionsSimple(
    canLoadOptions ? productTypeId : null,
    canLoadOptions ? hardwareColor : null,
    'drive',
    templatesForManual // ✅ solo templates manual cuando aplica
  );
  
  // ✅ Calcular templates filtrados por motor/drive seleccionado
  const selectedMotor = motorOptions.find(opt => opt.id === motorItemId);
  const selectedDrive = driveOptions.find(opt => opt.id === driveItemId);
  
  const templatesAfterOperation = useMemo(() => {
    // ✅ Usar baseTemplatesForOptions como fallback cuando no hay operationType
    const base =
      operationType === 'motor'
        ? (templatesForMotor || null)
        : operationType === 'manual'
        ? (templatesForManual || null)
        : (baseTemplatesForOptions || null);
    
    if (operationType === 'motor' && selectedMotor?.templateIds) {
      if (base) {
        const set = new Set(selectedMotor.templateIds);
        return base.filter(tid => set.has(tid));
      }
      return selectedMotor.templateIds;
    }
    
    if (operationType === 'manual' && selectedDrive?.templateIds) {
      if (base) {
        const set = new Set(selectedDrive.templateIds);
        return base.filter(tid => set.has(tid));
      }
      return selectedDrive.templateIds;
    }
    
    return base;
  }, [operationType, selectedMotor, selectedDrive, baseTemplatesForOptions, templatesForMotor, templatesForManual]);
  
  // ✅ Tube: desde templates filtrados por motor/drive (tube NO depende de color)
  const { options: tubeOptions, loading: loadingTube, error: tubeError } = useBOMTemplateOptionsSimple(
    canLoadOptions ? productTypeId : null,
    null, // Tube no depende de color
    'tube',
    templatesAfterOperation
  );

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
  const [imageSources, setImageSources] = useState<Record<string, string>>({
    manual: '/images/drive-manual.png',
    motor: '/images/drive-motor.png',
  });

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

  const handleOperatingSystemChange = (value: 'manual' | 'motor') => {
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
      updates.manual_drive = undefined;
      updates.drive_item_id = undefined;
      updates.drive_sku = null;
      // ✅ Resetear a templates de Motor (usando baseTemplatesForOptions como origen)
      updates._hardware_filtered_templates = uniq(templatesForMotor) ?? uniq(baseTemplatesForOptions) ?? null;
    } else {
      updates.motor_family = undefined;
      updates.motor_item_id = undefined;
      updates.motor_sku = null;
      updates.remote_control = undefined;
      // ✅ Resetear a templates de Manual (usando baseTemplatesForOptions como origen)
      updates._hardware_filtered_templates = uniq(templatesForManual) ?? uniq(baseTemplatesForOptions) ?? null;
    }
    
    // Clear tube when switching operation type
    updates.tube_item_id = undefined;
    updates.tube_sku = null;
    updates.tube_type = undefined;
    
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Switching to:', value, {
        templatesForMotor: templatesForMotor?.length,
        templatesForManual: templatesForManual?.length,
        baseTemplatesForOptions: baseTemplatesForOptions?.length,
      });
    }
    
    onUpdate(updates);
  };

  const handleMotorSelect = (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    
    // ✅ Calcular templates filtrados usando templatesForMotor
    let newFilteredTemplates = item.templateIds || [];
    const motorBase = templatesForMotor || baseTemplatesForOptions;
    if (motorBase && motorBase.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = motorBase.filter(tid => set.has(tid));
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
      // ✅ Guardar templates filtrados
      _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : uniq(templatesForMotor) ?? uniq(baseTemplatesForOptions) ?? null,
    } as any);
  };

  const handleDriveSelect = (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    
    // ✅ Calcular templates filtrados usando templatesForManual
    let newFilteredTemplates = item.templateIds || [];
    const manualBase = templatesForManual || baseTemplatesForOptions;
    if (manualBase && manualBase.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = manualBase.filter(tid => set.has(tid));
    }
    newFilteredTemplates = uniq(newFilteredTemplates) || [];
    
    if (import.meta.env.DEV) {
      console.debug('[OperatingSystemStep] Drive selected:', {
        sku: item.sku,
        templateIds: newFilteredTemplates.length,
      });
    }
    
    onUpdate({
      drive_item_id: isVirtual ? null : item.id,
      drive_sku: item.sku,
      manual_drive: item.name,
      motor_item_id: undefined,
      motor_sku: null,
      motor_family: undefined,
      remote_control: undefined,
      // Clear tube when drive changes
      tube_item_id: undefined,
      tube_sku: null,
      tube_type: undefined,
      // ✅ Guardar templates filtrados
      _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : uniq(templatesForManual) ?? uniq(baseTemplatesForOptions) ?? null,
    } as any);
  };

  const handleTubeSelect = (item: RoleOption) => {
    const isVirtual = String(item.id).startsWith('sku:');
    
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

  const clearOperationType = () => {
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
      // ✅ Usar baseTemplatesForOptions para restaurar al estado original
      _hardware_filtered_templates: uniq(baseTemplatesForOptions) ?? null,
    } as any);
  };

  // Don't render if operating system step is not required
  if (!showOperatingSystem) {
    return null;
  }
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        <div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Operating System</h3>
          <p className="text-sm text-gray-600">
            Select the operating system type and choose the specific components.
          </p>
        </div>

        {/* Operating System Type (Manual/Motor) */}
        {showDriveType && (
          <div>
            <Label className="text-sm font-medium mb-4 block">OPERATION TYPE</Label>
            <p className="text-xs text-gray-500 mb-2">Determines which drive block components are included in the BOM</p>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
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
                    onClick={() => handleOperatingSystemChange(option.value)}
                    className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer relative ${
                      isSelected
                        ? 'border-2 border-primary shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    {/* X to deselect */}
                    {isSelected && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          clearOperationType();
                        }}
                        className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div className="aspect-square bg-gray-100 flex items-center justify-center overflow-hidden relative">
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
                    
                    <div className="p-4">
                      <h3 className={`font-semibold text-sm truncate text-center ${
                        isSelected ? 'text-primary' : 'text-gray-900'
                      }`} title={option.label}>
                        {option.label}
                      </h3>
                      {!hasOptions && !loading && (
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
            <Label className="text-sm font-medium mb-4 block">MOTORS</Label>
            {loadingMotor ? (
              <div className="text-sm text-gray-500 mt-2">Loading motors...</div>
            ) : motorOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {motorOptions.map((item) => {
                  const isSelected = motorItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={() => handleMotorSelect(item)}
                      className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onUpdate({
                              motor_item_id: undefined,
                              motor_sku: null,
                              motor_family: undefined,
                              remote_control: undefined,
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              // ✅ Volver a templatesForMotor (no afecta opciones de Manual)
                              _hardware_filtered_templates: uniq(templatesForMotor as any) ?? uniq(baseTemplatesForOptions) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-gray-50 border-b border-gray-200">
                        {item.image_url ? (
                          <img
                            src={item.image_url}
                            alt={item.name || item.sku}
                            className="w-full h-full object-contain p-2"
                          />
                        ) : (
                          <ImageIcon className="w-12 h-12 text-gray-400" />
                        )}
                      </div>
                      <div className="p-4">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-primary' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        {import.meta.env.DEV && item.templateIds && (
                          <p className="text-xs text-blue-500 mt-1">
                            {relevantTemplateCount(item.templateIds, templatesAfterOperation as any)} template(s)
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No motors available for ProductType
                {import.meta.env.DEV && (
                  <div className="text-xs text-red-500 mt-1">
                    Debug: productTypeId={productTypeId}, filteredTemplates={hardwareFilteredTemplates?.length ?? 'none'}, error={motorError}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Manual Drive Selection (only if manual) */}
        {operationType === 'manual' && (
          <div>
            <Label className="text-sm font-medium mb-4 block">MECHANISM / MANUAL DRIVE</Label>
            {loadingDrive ? (
              <div className="text-sm text-gray-500 mt-2">Loading drive options...</div>
            ) : driveOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {driveOptions.map((item) => {
                  const isSelected = driveItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={() => handleDriveSelect(item)}
                      className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onUpdate({
                              drive_item_id: undefined,
                              drive_sku: null,
                              manual_drive: undefined,
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              // ✅ Volver a templatesForManual (no afecta opciones de Motor)
                              _hardware_filtered_templates: uniq(templatesForManual as any) ?? uniq(baseTemplatesForOptions) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-gray-50 border-b border-gray-200">
                        {item.image_url ? (
                          <img
                            src={item.image_url}
                            alt={item.name || item.sku}
                            className="w-full h-full object-contain p-2"
                          />
                        ) : (
                          <ImageIcon className="w-12 h-12 text-gray-400" />
                        )}
                      </div>
                      <div className="p-4">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-primary' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        {import.meta.env.DEV && item.templateIds && (
                          <p className="text-xs text-blue-500 mt-1">
                            {relevantTemplateCount(item.templateIds, templatesAfterOperation as any)} template(s)
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No manual drive options available
                {import.meta.env.DEV && (
                  <div className="text-xs text-red-500 mt-1">
                    Debug: productTypeId={productTypeId}, hardwareColor={hardwareColor}, filteredTemplates={hardwareFilteredTemplates?.length ?? 'none'}, error={driveError}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Tube Selection (show when motor or drive is selected) */}
        {((operationType === 'motor' && motorItemId) || (operationType === 'manual' && driveItemId)) && (
          <div>
            <Label className="text-sm font-medium mb-4 block">TUBE TYPE</Label>
            {loadingTube ? (
              <div className="text-sm text-gray-500 mt-2">Loading tube options...</div>
            ) : tubeOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {tubeOptions.map((item) => {
                  const isSelected = tubeItemId === item.id;
                  return (
                    <div
                      key={item.id}
                      onClick={() => handleTubeSelect(item)}
                      className={`bg-white border rounded-lg overflow-hidden transition-all cursor-pointer relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {/* X to deselect */}
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            // ✅ Volver al estado antes de seleccionar tube
                            // templatesAfterOperation ya tiene en cuenta motor/drive seleccionado
                            const targetTemplates = operationType === 'motor'
                              ? (selectedMotor?.templateIds ? 
                                  (templatesForMotor || []).filter(tid => new Set(selectedMotor.templateIds).has(tid)) 
                                  : templatesForMotor)
                              : operationType === 'manual'
                              ? (selectedDrive?.templateIds ?
                                  (templatesForManual || []).filter(tid => new Set(selectedDrive.templateIds).has(tid))
                                  : templatesForManual)
                              : baseTemplatesForOptions;
                            
                            onUpdate({
                              tube_item_id: undefined,
                              tube_sku: null,
                              tube_type: undefined,
                              _hardware_filtered_templates: uniq(targetTemplates as any) ?? uniq(baseTemplatesForOptions) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div className="aspect-square flex items-center justify-center bg-gray-50 border-b border-gray-200">
                        {item.image_url ? (
                          <img
                            src={item.image_url}
                            alt={item.name || item.sku}
                            className="w-full h-full object-contain p-2"
                          />
                        ) : (
                          <ImageIcon className="w-12 h-12 text-gray-400" />
                        )}
                      </div>
                      <div className="p-4">
                        <h3 className={`font-semibold text-sm ${isSelected ? 'text-primary' : 'text-gray-900'}`}>
                          {item.name || item.sku}
                        </h3>
                        <p className="text-xs text-gray-500 mt-1">{item.sku}</p>
                        {import.meta.env.DEV && item.templateIds && (
                          <p className="text-xs text-blue-500 mt-1">
                            {relevantTemplateCount(item.templateIds, templatesAfterOperation as any)} template(s)
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">
                No tube options available for current selection
                {import.meta.env.DEV && (
                  <div className="text-xs text-red-500 mt-1">
                    Debug: templatesAfterOperation={templatesAfterOperation?.length ?? 'none'}, error={tubeError}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
        
        {/* Debug: Templates filtrados */}
        {import.meta.env.DEV && (
          <div className="mt-4 p-3 bg-blue-50 rounded-lg">
            <p className="text-xs text-blue-700">
              <strong>Templates after Operation step:</strong>{' '}
              {templatesAfterOperation?.length ?? 'not filtered'} template(s) match current selection
            </p>
            {hardwareFilteredTemplates && (
              <p className="text-xs text-blue-600 mt-1">
                From Hardware step: {hardwareFilteredTemplates.length} template(s)
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
