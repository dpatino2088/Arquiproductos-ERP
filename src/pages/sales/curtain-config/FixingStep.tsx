import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';

interface FixingStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const FIXING_TYPES = [
  { id: 'ST', name: 'ST (Standard)' },
  { id: 'ZA/ZI', name: 'ZA/ZI' },
  { id: 'KT/KTm', name: 'KT/KTm' },
  { id: 'NI', name: 'NI' },
  { id: 'VP', name: 'VP' },
  { id: 'BP-both', name: 'BP (Both Sides)' },
  { id: 'BP-one', name: 'BP (One Side)' },
  { id: 'LA-top', name: 'LA (Top)' },
  { id: 'LA-down', name: 'LA (Down)' },
  { id: 'LA-front', name: 'LA (Front)' },
  { id: 'LA-rear', name: 'LA (Rear)' },
];

export default function FixingStep({ config, onUpdate }: FixingStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">FIXING</Label>
        <div className="grid grid-cols-4 gap-4">
          {FIXING_TYPES.map((fixing) => {
            const isSelected = config.fixingType === fixing.id;
            return (
              <button
                key={fixing.id}
                onClick={() => onUpdate({ fixingType: fixing.id })}
                className={`p-4 border-2 rounded-lg text-center transition-all ${
                  isSelected
                    ? 'border-primary bg-primary/5'
                    : 'border-gray-200 bg-white hover:border-gray-300'
                }`}
              >
                <div className="w-full h-24 bg-gray-100 rounded mb-2 flex items-center justify-center">
                  <span className="text-xs text-gray-500">{fixing.name}</span>
                </div>
                <span className="text-sm font-medium">{fixing.name}</span>
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



