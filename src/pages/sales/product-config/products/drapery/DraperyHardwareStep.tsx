import React, { useCallback, useEffect, useState } from 'react';
import { Image as ImageIcon } from 'lucide-react';
import Label from '../../../../../components/ui/Label';
import { supabase } from '../../../../../lib/supabase/client';
import { useOrganizationContext } from '../../../../../context/OrganizationContext';

interface DraperyHardwareStepProps {
  config: any;
  onUpdate: (updates: Record<string, any>) => void;
}

const getImageUrl = (path: string) => {
  const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '') || '';
  return `${base}${path.startsWith('/') ? path : '/' + path}`;
};

const OPENING_DIRECTION_OPTIONS = [
  { id: 'left' as const, name: 'Left', imagePath: '/images/DR_Left.png' },
  { id: 'center' as const, name: 'Center', imagePath: '/images/DR_Center.png' },
  { id: 'right' as const, name: 'Right', imagePath: '/images/DR_Right.png' },
];

const DRIVE_SIDE_OPTIONS = [
  { id: 'left' as const, name: 'Left', imagePath: '/images/DR_Drive_Left.png' },
  { id: 'right' as const, name: 'Right', imagePath: '/images/DR_Drive_Right.png' },
];

const HARDWARE_COLOR_OPTIONS = [
  { id: 'White', name: 'White', color: '#FFFFFF', border: '#E5E7EB' },
  { id: 'Black', name: 'Black', color: '#1F2937', border: '#1F2937' },
  { id: 'Silver', name: 'Silver', color: '#C0C0C0', border: '#9CA3AF' },
  { id: 'Bronze', name: 'Bronze', color: '#8B6914', border: '#8B6914' },
  { id: 'Grey', name: 'Grey', color: '#6B7280', border: '#6B7280' },
];


export default function DraperyHardwareStep({ config, onUpdate }: DraperyHardwareStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [imageLoadErrors, setImageLoadErrors] = useState<Set<string>>(new Set());
  const markImageError = useCallback((key: string) => {
    setImageLoadErrors((prev) => new Set(prev).add(key));
  }, []);

  const productTypeId = config.productTypeId || config.product_type_id;
  const productLine = config.productLine || config.product_line || null;
  const systemSize = config.systemSize || config.system_size || null;
  const currentOpeningDirection = config.openingDirection ?? config.opening_direction ?? null;
  const currentDriveSide = config.driveSide ?? config.drive_side ?? null;
  const currentHardwareColor = config.hardwareColor ?? config.hardware_color ?? null;
  const totalWidthMm = config.width_mm || 0;
  const isOver4m = totalWidthMm > 4000;
  const currentForceTrackJoin = config.forceTrackJoin ?? config.force_track_join ?? false;

  useEffect(() => {
    if (isOver4m && !currentForceTrackJoin) {
      onUpdate({ forceTrackJoin: true, force_track_join: true });
    }
  }, [isOver4m]);

  // Filter BOMTemplates progressively as user makes selections
  useEffect(() => {
    if (!activeOrganizationId || !productTypeId) return;

    let cancelled = false;
    (async () => {
      let query = supabase
        .from('BOMTemplates')
        .select('id')
        .eq('product_type_id', productTypeId)
        .eq('is_active', true)
        .eq('deleted', false)
        .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

      if (productLine) {
        query = query.eq('product_line', productLine);
      }
      if (systemSize) {
        query = query.or(`system_size.eq.${systemSize},system_size.is.null`);
      }
      if (currentOpeningDirection) {
        query = query.or(`opening_direction.eq.${currentOpeningDirection},opening_direction.is.null`);
      }
      if (currentDriveSide) {
        query = query.or(`drive_side.eq.${currentDriveSide},drive_side.is.null`);
      }
      if (currentHardwareColor) {
        query = query.or(`hardware_color.eq.${currentHardwareColor},hardware_color.is.null`);
      }

      const { data, error } = await query;
      if (cancelled) return;

      if (error) {
        console.error('[DraperyHardwareStep] Template filter error:', error);
        return;
      }

      const templateIds = (data || []).map((t: { id: string }) => t.id);
      onUpdate({ _hardware_filtered_templates: templateIds.length > 0 ? templateIds : undefined } as any);
    })();

    return () => { cancelled = true; };
  }, [activeOrganizationId, productTypeId, productLine, systemSize, currentOpeningDirection, currentDriveSide, currentHardwareColor]);

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-8">
        {/* 1. HARDWARE COLOR */}
        <div>
          <Label className="text-sm font-medium mb-4 block">HARDWARE COLOR</Label>
          <div className="flex gap-3">
            {HARDWARE_COLOR_OPTIONS.map((option) => {
              const isSelected = currentHardwareColor === option.id;
              return (
                <button
                  key={option.id}
                  type="button"
                  onClick={() => onUpdate({ hardwareColor: isSelected ? undefined : option.id, hardware_color: isSelected ? undefined : option.id })}
                  className={`flex flex-col items-center gap-2 p-3 rounded-lg border-2 transition-all ${
                    isSelected
                      ? 'border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:border-gray-300 hover:shadow'
                  }`}
                  title={option.name}
                >
                  <div
                    className="w-10 h-10 rounded-full border-2"
                    style={{ backgroundColor: option.color, borderColor: option.border }}
                  />
                  <span className="text-xs font-medium text-gray-700">{option.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* 2. OPENING DIRECTION */}
        <div>
          <Label className="text-sm font-medium mb-5 block">OPENING DIRECTION</Label>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {OPENING_DIRECTION_OPTIONS.map((option) => {
              const isSelected = currentOpeningDirection === option.id;
              const imgKey = `opening-${option.id}`;
              return (
                <div
                  key={option.id}
                  onClick={() => {
                    const updates: Record<string, unknown> = {
                      openingDirection: isSelected ? undefined : option.id,
                    };
                    if (isSelected) {
                      updates.driveSide = undefined;
                    } else if (option.id === 'center') {
                      updates.driveSide = undefined;
                    } else {
                      updates.driveSide = option.id;
                    }
                    onUpdate(updates);
                  }}
                  className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                    isSelected
                      ? 'border-2 border-gray-900 shadow-lg'
                      : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                  }`}
                >
                  <div className="aspect-square bg-white flex items-center justify-center overflow-hidden p-3">
                    {option.imagePath && !imageLoadErrors.has(imgKey) ? (
                      <img
                        src={getImageUrl(option.imagePath)}
                        alt={option.name}
                        className="max-h-full max-w-full object-contain"
                        onError={() => markImageError(imgKey)}
                      />
                    ) : (
                      <ImageIcon className="w-16 h-16 text-gray-300" />
                    )}
                  </div>
                  <div className="p-4 bg-gray-100 flex-1">
                    <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={option.name}>
                      {option.name}
                    </h3>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* 3. DRIVE SIDE — only when Opening = Center */}
        {currentOpeningDirection === 'center' && (
          <div>
            <Label className="text-sm font-medium mb-2 block">DRIVE SIDE</Label>
            <p className="text-xs text-gray-500 mb-4">
              With center opening, select which side the drive mechanism goes.
            </p>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {DRIVE_SIDE_OPTIONS.map((option) => {
                const isSelected = currentDriveSide === option.id;
                const imgKey = `drive-${option.id}`;
                return (
                  <div
                    key={option.id}
                    onClick={() => {
                      onUpdate({ driveSide: isSelected ? undefined : option.id });
                    }}
                    className={`bg-white border rounded-lg overflow-hidden flex flex-col transition-all cursor-pointer ${
                      isSelected
                        ? 'border-2 border-gray-900 shadow-lg'
                        : 'border-gray-200 hover:shadow-lg hover:border-gray-300'
                    }`}
                  >
                    <div className="aspect-square bg-white flex items-center justify-center overflow-hidden p-3">
                      {option.imagePath && !imageLoadErrors.has(imgKey) ? (
                        <img
                          src={getImageUrl(option.imagePath)}
                          alt={option.name}
                          className="max-h-full max-w-full object-contain"
                          onError={() => markImageError(imgKey)}
                        />
                      ) : (
                        <ImageIcon className="w-16 h-16 text-gray-300" />
                      )}
                    </div>
                    <div className="p-4 bg-gray-100 flex-1">
                      <h3 className="font-semibold text-sm truncate text-center text-gray-900" title={option.name}>
                        {option.name}
                      </h3>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* 4. TRACK SPLIT */}
        {totalWidthMm > 0 && (
          <div>
            {isOver4m ? (
              <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
                <Label className="text-sm font-medium mb-1 block">TRACK JOINT</Label>
                <p className="text-sm text-amber-800">
                  Width exceeds 4m — the track will be split into {Math.ceil(totalWidthMm / 4000)} pieces
                  with {Math.max(0, Math.ceil(totalWidthMm / 4000) - 1)} joint{Math.ceil(totalWidthMm / 4000) > 2 ? 's' : ''} (automatic).
                </p>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div>
                  <Label className="text-sm font-medium mb-1 block">SPLIT TRACK (OPTIONAL)</Label>
                  <p className="text-xs text-gray-500">
                    Width is under 4m. You can optionally split the track into 2 pieces with a joint.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => onUpdate({ forceTrackJoin: !currentForceTrackJoin })}
                  className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out ${
                    currentForceTrackJoin ? 'bg-gray-900' : 'bg-gray-200'
                  }`}
                  role="switch"
                  aria-checked={currentForceTrackJoin}
                >
                  <span
                    className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                      currentForceTrackJoin ? 'translate-x-5' : 'translate-x-0'
                    }`}
                  />
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
