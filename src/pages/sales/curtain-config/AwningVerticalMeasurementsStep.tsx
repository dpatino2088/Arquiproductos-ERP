import { CurtainConfiguration } from '../CurtainConfigurator';
import MeasurementsStep from './MeasurementsStep';
import AwningSystemSelector from './AwningSystemSelector';

interface AwningVerticalMeasurementsStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

/**
 * Measurements step for the VERTICAL awning (drop screen).
 * Same standard Width × Height MeasurementsStep, with the awning system
 * selector on top so the user can switch back to Extensible without
 * leaving the step.
 */
export default function AwningVerticalMeasurementsStep({ config, onUpdate }: AwningVerticalMeasurementsStepProps) {
  return (
    <div className="space-y-6">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <AwningSystemSelector config={config} onUpdate={onUpdate as any} />
        </div>
      </div>
      <MeasurementsStep config={config} onUpdate={onUpdate} />
    </div>
  );
}
