import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';

interface GuidingStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const GUIDING_PROFILES = [
  { id: 'U12', name: 'U12', dimensions: { top: 14, bottom: 12 } },
  { id: 'U15/U25', name: 'U15 / U25', dimensions: { top: 25, inner: 14, bottom: 15 } },
  { id: 'U25', name: 'U25', dimensions: { top: 14, bottom: 25 } },
  { id: 'U30/U50', name: 'U30 / U50', dimensions: { top: 50, inner: 14, bottom: 30 } },
  { id: 'U27/U60', name: 'U27 / U60', dimensions: { top: 60, inner: 14, bottom: 27 } },
  { id: 'U38', name: 'U38', dimensions: { top: 14, bottom: 38 } },
  { id: 'UI38', name: 'UI38', dimensions: { top: 25, inner: 14, bottom: 38 } },
  { id: 'U50', name: 'U50', dimensions: { top: 14, bottom: 50 } },
  { id: 'UI50', name: 'UI50', dimensions: { top: 25, inner: 14, bottom: 50 } },
  { id: 'L40', name: 'L40', dimensions: { top: 20, vertical: 40 } },
  { id: 'Y32', name: 'Y32', dimensions: { top: 25, inner: 14, main: 32, bottom: 12 } },
];

export default function GuidingStep({ config, onUpdate }: GuidingStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">GUIDING</Label>
        <div className="grid grid-cols-5 gap-4">
          {GUIDING_PROFILES.map((profile) => {
            const isSelected = config.guidingProfile === profile.id;
            return (
              <button
                key={profile.id}
                onClick={() => onUpdate({ guidingProfile: profile.id })}
                className={`p-4 border-2 rounded-lg text-center transition-all ${
                  isSelected
                    ? 'border-primary bg-primary/5'
                    : 'border-gray-200 bg-white hover:border-gray-300'
                }`}
              >
                <div className="w-full h-20 bg-gray-100 rounded mb-2 flex items-center justify-center">
                  <span className="text-xs text-gray-500">{profile.name}</span>
                </div>
                <span className="text-sm font-medium">{profile.name}</span>
                {isSelected && (
                  <div className="mt-2 text-primary text-xs">✓ Selected</div>
                )}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}



