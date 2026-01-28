/**
 * Hardware Step - FILTRADO PROGRESIVO
 * 
 * ✅ NUEVA ARQUITECTURA:
 * - Cards se cargan desde BOMComponents para ProductType + Color
 * - Cada selección FILTRA los templates disponibles para el siguiente paso
 * - El usuario solo puede configurar productos que existen como templates
 * 
 * Componentes:
 * - Hardware Color (White/Black/Silver) - static cards
 * - Bottom Bar - desde templates del ProductType + Color, filtra para siguientes
 * - Headbox/Cassette - desde templates filtrados por Bottom Bar
 * - Side Channel - desde templates filtrados (opcional)
 * - Bottom Channel - desde templates filtrados (opcional)
 * 
 * IMPORTANT:
 * - Colors in DB are CAPITALIZED: 'White', 'Black', 'Silver'
 * - Cada opción incluye templateIds para filtrado progresivo
 */

import { useEffect, useMemo } from 'react';
import { CurtainConfiguration } from '../CurtainConfigurator';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { useBOMTemplateOptionsSimple, filterTemplatesByComponent, RoleOption } from '../../../hooks/useBOMTemplateOptionsSimple';
import { Image as ImageIcon, X } from 'lucide-react';
import { RoleSelection, toRoleSelection } from '../../../lib/bom/selection';

interface HardwareStepProps {
  config: CurtainConfiguration | ProductConfig;
  onUpdate: (
    updates:
      | Partial<CurtainConfiguration | ProductConfig>
      | ((prev: CurtainConfiguration | ProductConfig) => Partial<CurtainConfiguration | ProductConfig>)
  ) => void;
  /** Templates filtrados desde pasos anteriores (opcionales) */
  filteredTemplateIds?: string[];
}

// Hardware Color options (CAPITALIZED to match DB)
const HARDWARE_COLOR_OPTIONS = [
  { id: 'White', name: 'White', color: '#FFFFFF' },
  { id: 'Black', name: 'Black', color: '#000000' },
  { id: 'Silver', name: 'Silver', color: '#C0C0C0' },
];

export default function HardwareStep({ config, onUpdate, filteredTemplateIds }: HardwareStepProps) {
  const productTypeId = (config as any).product_type_id || (config as any).productTypeId;
  
  const productType = (config as any).productType || (config as any).product_type || '';
  const isRollerShade = productType === 'roller_shade' || productType === 'roller-shade' || productType === 'ROLLER';
  
  // Always show these hardware options
  const showHardwareColor = true;
  const showCassette = true;
  const showSideChannel = isRollerShade;
  
  // Get current selections (CAPITALIZED)
  const currentHardwareColor = (config as any).hardwareColor || (config as any).hardware_color || (config as any).operatingSystemColor || null;
  const cassetteShape = (config as any).cassette_shape || 'none';
  
  // ✅ Helpers para RoleSelection
  const headboxSelection: RoleSelection = toRoleSelection(
    (config as any).headbox_sku,
    (config as any).headbox_item_id
  );
  
  const sideChannelSelection: RoleSelection = toRoleSelection(
    (config as any).side_channel_sku,
    (config as any).side_channel_item_id
  );
  
  const bottomChannelSelection: RoleSelection = toRoleSelection(
    (config as any).bottom_channel_sku,
    (config as any).bottom_channel_item_id
  );

  const uniq = (ids: string[] | null | undefined): string[] | null => {
    if (!ids) return null;
    const u = Array.from(new Set(ids.filter(Boolean)));
    return u.length > 0 ? u : null;
  };
  
  // ✅ Helpers UI para manejar selecciones
  const setHeadboxNone = () => {
    onUpdate({
      headbox_item_id: null,
      headbox_sku: null,
      cassette: false,
      cassette_shape: 'none',
    } as any);
  };
  
  const clearHeadboxSelection = () => {
    onUpdate({
      headbox_item_id: undefined,
      headbox_sku: '',
      cassette: false,
      cassette_shape: 'none',
    } as any);
  };
  
  const setHeadboxSelected = (item: RoleOption) => {
    // ✅ Calcular templates filtrados: intersección con los actuales
    let newFilteredTemplates = item.templateIds || [];
    const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
    
    if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
      const set = new Set(newFilteredTemplates);
      newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
    }
    
    if (import.meta.env.DEV) {
      console.debug('[HardwareStep] Headbox selected:', {
        sku: item.sku,
        templateIds: newFilteredTemplates.length,
      });
    }
    
    onUpdate({
      headbox_item_id: item.id,
      headbox_sku: item.sku ? String(item.sku).trim() : null,
      cassette: true,
      cassette_shape: 'standard',
      cassette_type: 'standard',
      // ✅ Guardar templates filtrados
      _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
    } as any);
  };
  
  // ✅ FILTRADO PROGRESIVO: Calcular templates disponibles basado en selecciones
  const hasHardwareColor = !!currentHardwareColor;
  
  // ✅ Bottom Bar: desde TODOS los templates del ProductType + Color (primer filtro)
  const { options: bottomBarOptions, loading: loadingBottomBar, error: bottomBarError } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'bottom_bar',
    filteredTemplateIds // Puede venir pre-filtrado del paso anterior
  );
  
  // ✅ Calcular templates filtrados por bottom_bar seleccionado
  const selectedBottomBar = bottomBarOptions.find(
    opt => opt.id === (config as any).bottom_bar_item_id
  );
  const templatesAfterBottomBar = useMemo(() => {
    if (!selectedBottomBar || !selectedBottomBar.templateIds) {
      // Si no hay selección, usar todos los templates disponibles
      return filteredTemplateIds || null;
    }
    if (filteredTemplateIds) {
      // Intersectar con templates existentes
      const set = new Set(selectedBottomBar.templateIds);
      return filteredTemplateIds.filter(tid => set.has(tid));
    }
    return selectedBottomBar.templateIds;
  }, [selectedBottomBar, filteredTemplateIds]);
  
  // ✅ Headbox: desde templates filtrados por Bottom Bar
  const { options: headboxOptions, loading: loadingHeadbox } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'headbox',
    templatesAfterBottomBar
  );
  
  // ✅ Calcular templates filtrados por headbox seleccionado
  const selectedHeadbox = headboxOptions.find(
    opt => opt.id === (config as any).headbox_item_id
  );
  const templatesAfterHeadbox = useMemo(() => {
    if (!selectedHeadbox || !selectedHeadbox.templateIds) {
      return templatesAfterBottomBar;
    }
    if (templatesAfterBottomBar) {
      const set = new Set(selectedHeadbox.templateIds);
      return templatesAfterBottomBar.filter(tid => set.has(tid));
    }
    return selectedHeadbox.templateIds;
  }, [selectedHeadbox, templatesAfterBottomBar]);
  
  // ✅ Side Channel: desde templates filtrados
  const { options: sideChannelOptions, loading: loadingSideChannel } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'side_channel',
    templatesAfterHeadbox
  );
  
  // ✅ Calcular templates filtrados por side_channel seleccionado
  const selectedSideChannel = sideChannelOptions.find(
    opt => opt.id === (config as any).side_channel_item_id
  );
  const templatesAfterSideChannel = useMemo(() => {
    if (!selectedSideChannel || !selectedSideChannel.templateIds) {
      return templatesAfterHeadbox;
    }
    if (templatesAfterHeadbox) {
      const set = new Set(selectedSideChannel.templateIds);
      return templatesAfterHeadbox.filter(tid => set.has(tid));
    }
    return selectedSideChannel.templateIds;
  }, [selectedSideChannel, templatesAfterHeadbox]);
  
  // ✅ Bottom Channel: desde templates filtrados
  const { options: bottomChannelOptions, loading: loadingBottomChannel } = useBOMTemplateOptionsSimple(
    productTypeId,
    currentHardwareColor,
    'bottom_channel',
    templatesAfterSideChannel
  );
  
  // ✅ Calcular templates finales para pasar al siguiente step
  const selectedBottomChannel = bottomChannelOptions.find(
    opt => opt.id === (config as any).bottom_channel_item_id
  );
  const finalFilteredTemplates = useMemo(() => {
    if (!selectedBottomChannel || !selectedBottomChannel.templateIds) {
      return templatesAfterSideChannel;
    }
    if (templatesAfterSideChannel) {
      const set = new Set(selectedBottomChannel.templateIds);
      return templatesAfterSideChannel.filter(tid => set.has(tid));
    }
    return selectedBottomChannel.templateIds;
  }, [selectedBottomChannel, templatesAfterSideChannel]);
  
  // ✅ Guardar templates filtrados en config para el siguiente step
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
      }
    }
  }, [finalFilteredTemplates]);
  
  // ✅ DEBUG: Log de opciones cargadas
  if (import.meta.env.DEV && hasHardwareColor && !loadingBottomBar) {
    console.debug("[HardwareStep] Progressive filtering", {
      productTypeId,
      hardwareColor: currentHardwareColor,
      bottomBarCount: bottomBarOptions.length,
      templatesAfterBottomBar: templatesAfterBottomBar?.length ?? 'all',
      headboxCount: headboxOptions.length,
      templatesAfterHeadbox: templatesAfterHeadbox?.length ?? 'all',
      sideChannelCount: sideChannelOptions.length,
      bottomChannelCount: bottomChannelOptions.length,
      finalFilteredTemplates: finalFilteredTemplates?.length ?? 'all',
    });
  }
  
  // ✅ Inicializar valores por defecto
  useEffect(() => {
    const updates: any = {};
    let hasUpdates = false;
    
    if (showCassette && !cassetteShape) {
      updates.cassette_shape = 'none';
      hasUpdates = true;
    }
    
    if (hasUpdates) {
      onUpdate(updates);
    }
  }, []);
  
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Hardware Color */}
        {showHardwareColor && (
          <div>
            <Label className="text-sm font-medium mb-4 block">
              HARDWARE COLOR
              {!currentHardwareColor && (
                <span className="ml-2 text-sm font-normal text-red-600">(Required - Please select)</span>
              )}
            </Label>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {HARDWARE_COLOR_OPTIONS.map((option) => {
                const isSelected = currentHardwareColor === option.id;
                return (
                  <div
                    key={option.id}
                    onClick={() => {
                      // ✅ Limpiar selecciones de componentes cuando cambia el color
                      onUpdate({ 
                        hardwareColor: option.id,
                        hardware_color: option.id,
                        operatingSystemColor: option.id,
                        // Limpiar selecciones de componentes que dependen del color
                        bottom_bar_item_id: null,
                        bottom_bar_sku: null,
                        headbox_item_id: null,
                        headbox_sku: null,
                        side_channel_item_id: null,
                        side_channel_sku: null,
                        bottom_channel_item_id: null,
                        bottom_channel_sku: null,
                        _hardware_filtered_templates: null,
                      } as any);
                    }}
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
                            hardwareColor: undefined,
                            hardware_color: undefined,
                            operatingSystemColor: undefined,
                            bottom_bar_item_id: null,
                            bottom_bar_sku: null,
                            headbox_item_id: null,
                            headbox_sku: null,
                            side_channel_item_id: null,
                            side_channel_sku: null,
                            bottom_channel_item_id: null,
                            bottom_channel_sku: null,
                            _hardware_filtered_templates: null,
                          } as any);
                        }}
                        className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div 
                      className="aspect-square relative flex items-center justify-center overflow-hidden border-b border-gray-200"
                      style={{ backgroundColor: option.color }}
                    >
                      {option.id === 'Silver' && (
                        <div className="absolute inset-0 opacity-20 bg-gradient-to-br from-white to-gray-400" />
                      )}
                    </div>
                    <div className="p-4">
                      <h3 className={`font-semibold text-sm text-center ${
                        isSelected ? 'text-primary' : 'text-gray-900'
                      }`}>
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Bottom Bar - Dynamic from CatalogItems */}
        {currentHardwareColor && (
          <div>
            <Label className="text-sm font-medium mb-4 block">BOTTOM BAR</Label>
            {loadingBottomBar ? (
              <div className="text-sm text-gray-500 mt-2">Loading bottom bar options...</div>
            ) : bottomBarOptions.length > 0 ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {bottomBarOptions.map((item) => {
                const isSelected = (config as any).bottom_bar_item_id === item.id;
                return (
                  <div
                    key={item.id}
                    className={`bg-white border rounded-lg overflow-hidden transition-all relative ${
                      isSelected
                        ? 'border-2 border-primary shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    {isSelected && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          onUpdate({
                            bottom_bar_item_id: null,
                            bottom_bar_sku: null,
                            bottom_rail_type: null,
                            // Limpiar selecciones dependientes
                            headbox_item_id: null,
                            headbox_sku: null,
                            side_channel_item_id: null,
                            side_channel_sku: null,
                            bottom_channel_item_id: null,
                            bottom_channel_sku: null,
                          } as any);
                        }}
                        className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                        title="Remove selection"
                      >
                        <X className="w-4 h-4 text-gray-600" />
                      </button>
                    )}
                    <div
                      onClick={() => {
                        const sku = (item.sku || "").trim();
                        const id = String(item.id);
                        const isVirtual = id.startsWith('sku:');
                        
                        // ✅ Guardar templates filtrados inmediatamente (dedupe)
                        const newFilteredTemplates = uniq(item.templateIds) || [];
                        
                        if (import.meta.env.DEV) {
                          console.debug('[HardwareStep] Bottom bar selected:', {
                            sku,
                            id,
                            templateIds: newFilteredTemplates.length,
                          });
                        }
                        
                        onUpdate({
                          bottom_bar_item_id: isVirtual ? null : id,
                          bottom_bar_sku: sku,
                          bottom_rail_type: 'standard',
                          // Limpiar selecciones dependientes cuando cambia bottom_bar
                          headbox_item_id: null,
                          headbox_sku: null,
                          side_channel_item_id: null,
                          side_channel_sku: null,
                          bottom_channel_item_id: null,
                          bottom_channel_sku: null,
                          // ✅ Guardar templates filtrados (dedupe)
                          _hardware_filtered_templates: newFilteredTemplates.length > 0 ? newFilteredTemplates : null,
                        } as any);
                      }}
                      className="cursor-pointer"
                    >
                      <div className="aspect-square flex items-center justify-center bg-gray-50 border-b border-gray-200">
                        {item.image_url ? (
                          <img
                            src={item.image_url}
                            alt={item.name || item.sku}
                            className="w-full h-full object-contain p-2"
                            onError={(e) => {
                              e.currentTarget.style.display = 'none';
                              const parent = e.currentTarget.parentElement;
                              if (parent) {
                                const fallback = document.createElement('div');
                                fallback.className = 'flex items-center justify-center w-full h-full';
                                fallback.innerHTML = '<svg class="w-12 h-12 text-gray-400" ...></svg>';
                                parent.appendChild(fallback);
                              }
                            }}
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
                            {item.templateIds.length} template(s)
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            ) : (
              <div className="text-sm text-gray-500">
                No bottom bar options available for selected color.
                {import.meta.env.DEV && (
                  <div className="text-xs text-red-500 mt-1">
                    Debug: productTypeId={productTypeId}, hardwareColor={currentHardwareColor}, loading={String(loadingBottomBar)}, error={bottomBarError}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Headbox / Cassette */}
        {showCassette && currentHardwareColor && (config as any).bottom_bar_item_id && (
          <div>
            <Label className="text-sm font-medium mb-4 block">HEADBOX / CASSETTE</Label>
            {loadingHeadbox ? (
              <div className="text-sm text-gray-500 mt-2">Loading headbox options...</div>
            ) : headboxOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {headboxOptions.map((item) => {
                  const isSelected = (config as any).headbox_item_id === item.id;
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden transition-all relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            clearHeadboxSelection();
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={() => setHeadboxSelected(item)}
                        className="cursor-pointer"
                      >
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
                              {item.templateIds.length} template(s)
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">No headbox options available for current selection.</div>
            )}
          </div>
        )}

        {/* Side Channel Items */}
        {showSideChannel && currentHardwareColor && (config as any).bottom_bar_item_id && (
          <div>
            <Label className="text-sm font-medium mb-4 block">SIDE CHANNEL ITEMS</Label>
            {loadingSideChannel ? (
              <div className="text-sm text-gray-500 mt-2">Loading side channel options...</div>
            ) : sideChannelOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {sideChannelOptions.map((item) => {
                  const isSelected = (config as any).side_channel_item_id === item.id;
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden transition-all relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onUpdate({
                              side_channel_item_id: null,
                              side_channel_sku: null,
                              side_channel: false,
                              // ✅ Revertir templates al estado antes de side_channel
                              _hardware_filtered_templates: uniq(templatesAfterHeadbox as any) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={() => {
                          // ✅ Calcular templates filtrados
                          let newFilteredTemplates = item.templateIds || [];
                          const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
                          
                          if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
                            const set = new Set(newFilteredTemplates);
                            newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
                          }
                          
                          onUpdate({
                            side_channel_item_id: item.id,
                            side_channel_sku: item.sku ? String(item.sku).trim() : null,
                            side_channel: true,
                            _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
                          } as any);
                        }}
                        className="cursor-pointer"
                      >
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
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">No side channel options available for current selection.</div>
            )}
          </div>
        )}

        {/* Add Bottom Channel */}
        {currentHardwareColor && (config as any).bottom_bar_item_id && (
          <div>
            <Label className="text-sm font-medium mb-4 block">ADD BOTTOM CHANNEL</Label>
            {loadingBottomChannel ? (
              <div className="text-sm text-gray-500 mt-2">Loading bottom channel options...</div>
            ) : bottomChannelOptions.length > 0 ? (
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                {bottomChannelOptions.map((item) => {
                  const isSelected = (config as any).bottom_channel_item_id === item.id;
                  return (
                    <div
                      key={item.id}
                      className={`bg-white border rounded-lg overflow-hidden transition-all relative ${
                        isSelected
                          ? 'border-2 border-primary shadow-lg'
                          : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                      }`}
                    >
                      {isSelected && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            onUpdate({
                              bottom_channel_item_id: null,
                              bottom_channel_sku: null,
                              bottom_channel: false,
                              // ✅ Revertir templates al estado antes de bottom_channel
                              _hardware_filtered_templates: uniq(templatesAfterSideChannel as any) ?? null,
                            } as any);
                          }}
                          className="absolute top-2 right-2 p-1 bg-white rounded-full shadow-md hover:bg-gray-100 transition-colors z-10"
                          title="Remove selection"
                        >
                          <X className="w-4 h-4 text-gray-600" />
                        </button>
                      )}
                      <div
                        onClick={() => {
                          // ✅ Calcular templates filtrados
                          let newFilteredTemplates = item.templateIds || [];
                          const currentFiltered = (config as any)._hardware_filtered_templates as string[] | undefined;
                          
                          if (currentFiltered && currentFiltered.length > 0 && newFilteredTemplates.length > 0) {
                            const set = new Set(newFilteredTemplates);
                            newFilteredTemplates = currentFiltered.filter(tid => set.has(tid));
                          }
                          
                          onUpdate({
                            bottom_channel_item_id: item.id,
                            bottom_channel_sku: item.sku ? String(item.sku).trim() : null,
                            bottom_channel: true,
                            _hardware_filtered_templates: uniq(newFilteredTemplates) ?? uniq(currentFiltered) ?? null,
                          } as any);
                        }}
                        className="cursor-pointer"
                      >
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
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-sm text-gray-500">No bottom channel options available for current selection.</div>
            )}
          </div>
        )}
        
        {/* Debug: Templates filtrados */}
        {import.meta.env.DEV && finalFilteredTemplates && (
          <div className="mt-4 p-3 bg-blue-50 rounded-lg">
            <p className="text-xs text-blue-700">
              <strong>Templates after Hardware step:</strong> {finalFilteredTemplates.length} template(s) match current selection
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
