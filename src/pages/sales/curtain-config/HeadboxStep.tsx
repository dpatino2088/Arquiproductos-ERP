import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';

interface HeadboxStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const HEADBOX_FRONTS = [
  { id: 'C1', name: 'C1', dimensions: { width: 44, height: 43, depth: 30, bottom: 8 } },
  { id: 'C2', name: 'C2', dimensions: { width: 57, height: 55, depth: 30, bottom: 8 } },
  { id: 'R1', name: 'R1', dimensions: { width: 42, height: 46, depth: 30, bottom: 8 } },
];

export default function HeadboxStep({ config, onUpdate }: HeadboxStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Mounting Cassette */}
        <div>
          <Label className="text-sm font-medium mb-4 block">MONTAGE CASSETE</Label>
          <div className="grid grid-cols-2 gap-4">
            <button
              onClick={() => onUpdate({ mountingCassette: 'VSL' })}
              className={`p-4 border-2 rounded-lg text-center transition-all ${
                config.mountingCassette === 'VSL'
                  ? 'border-primary bg-primary/5'
                  : 'border-gray-200 bg-white hover:border-gray-300'
              }`}
            >
              <div className="w-full h-32 bg-gray-100 rounded mb-2 flex items-center justify-center">
                <span className="text-xs text-gray-500">VSL - Op De Dag</span>
              </div>
              <span className="text-sm font-medium">VSL — Op De Dag</span>
            </button>
            <button
              onClick={() => onUpdate({ mountingCassette: 'VLO' })}
              className={`p-4 border-2 rounded-lg text-center transition-all ${
                config.mountingCassette === 'VLO'
                  ? 'border-primary bg-primary/5'
                  : 'border-gray-200 bg-white hover:border-gray-300'
              }`}
            >
              <div className="w-full h-32 bg-gray-100 rounded mb-2 flex items-center justify-center">
                <span className="text-xs text-gray-500">VLO - In De Dag</span>
              </div>
              <span className="text-sm font-medium">VLO — In De Dag</span>
            </button>
          </div>
        </div>

        {/* Dimensions */}
        <div>
          <Label className="text-sm font-medium mb-4 block">DIMENSIONS</Label>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="width_mm" className="text-xs mb-1">Width (mm)</Label>
              <Input
                id="width_mm"
                type="number"
                min="0"
                value={config.width_mm || ''}
                onChange={(e) => onUpdate({ width_mm: parseInt(e.target.value) || undefined })}
                placeholder="400"
              />
            </div>
            <div>
              <Label htmlFor="height_mm" className="text-xs mb-1">Height (mm)</Label>
              <Input
                id="height_mm"
                type="number"
                min="0"
                value={config.height_mm || ''}
                onChange={(e) => onUpdate({ height_mm: parseInt(e.target.value) || undefined })}
                placeholder="700"
              />
            </div>
          </div>
        </div>

        {/* Headbox Front */}
        <div>
          <Label className="text-sm font-medium mb-4 block">HEADBOX FRONT</Label>
          <div className="grid grid-cols-3 gap-4">
            {HEADBOX_FRONTS.map((front) => {
              const isSelected = config.headboxFront === front.id;
              return (
                <button
                  key={front.id}
                  onClick={() => onUpdate({ headboxFront: front.id })}
                  className={`p-4 border-2 rounded-lg text-center transition-all ${
                    isSelected
                      ? 'border-primary bg-primary/5'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <div className="w-full h-24 bg-gray-100 rounded mb-2 flex items-center justify-center">
                    <span className="text-xs text-gray-500">{front.name}</span>
                  </div>
                  <span className="text-sm font-medium">{front.name}</span>
                  <p className="text-xs text-gray-500 mt-1">
                    {front.dimensions.width}×{front.dimensions.height}×{front.dimensions.depth}
                  </p>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}



