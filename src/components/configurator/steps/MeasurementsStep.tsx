/**
 * Measurements Step
 * 
 * Step 2: Enter width and height measurements
 * These don't affect template selection but are stored in metadata
 */

import { useState, useEffect } from 'react';
import { RollerBOMConfigState } from '../../../lib/bom/types';
import Label from '../../ui/Label';
import Input from '../../ui/Input';

interface MeasurementsStepProps {
  config: RollerBOMConfigState;
  onUpdate: (updates: Partial<RollerBOMConfigState>) => void;
}

export default function MeasurementsStep({ config, onUpdate }: MeasurementsStepProps) {
  const [widthMm, setWidthMm] = useState<string>(
    config.width_mm ? (config.width_mm / 1000).toFixed(2) : ''
  );
  const [heightMm, setHeightMm] = useState<string>(
    config.height_mm ? (config.height_mm / 1000).toFixed(2) : ''
  );
  const [mountType, setMountType] = useState<string>(config.mount_type || '');
  const [location, setLocation] = useState<string>(config.location || '');

  // Update parent when values change
  useEffect(() => {
    const width = widthMm ? parseFloat(widthMm) * 1000 : null;
    const height = heightMm ? parseFloat(heightMm) * 1000 : null;

    onUpdate({
      width_mm: width,
      height_mm: height,
      mount_type: mountType || null,
      location: location || null,
    });
  }, [widthMm, heightMm, mountType, location, onUpdate]);

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Measurements</h3>
        <p className="text-sm text-gray-600">
          Enter the dimensions for your roller shade. These measurements are stored in the BOM metadata.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <Label htmlFor="width">Width (m)</Label>
          <Input
            id="width"
            type="number"
            step="0.01"
            min="0"
            value={widthMm}
            onChange={(e) => setWidthMm(e.target.value)}
            placeholder="0.00"
          />
        </div>

        <div>
          <Label htmlFor="height">Height (m)</Label>
          <Input
            id="height"
            type="number"
            step="0.01"
            min="0"
            value={heightMm}
            onChange={(e) => setHeightMm(e.target.value)}
            placeholder="0.00"
          />
        </div>

        <div>
          <Label htmlFor="mount-type">Mount Type (optional)</Label>
          <Input
            id="mount-type"
            type="text"
            value={mountType}
            onChange={(e) => setMountType(e.target.value)}
            placeholder="e.g., Inside mount, Outside mount"
          />
        </div>

        <div>
          <Label htmlFor="location">Location (optional)</Label>
          <Input
            id="location"
            type="text"
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="e.g., Living Room, Bedroom"
          />
        </div>
      </div>

      {widthMm && heightMm && (
        <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="text-sm text-blue-800">
            <strong>Area:</strong> {(parseFloat(widthMm) * parseFloat(heightMm)).toFixed(2)} m²
          </div>
        </div>
      )}
    </div>
  );
}
