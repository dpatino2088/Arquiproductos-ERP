import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';

interface ChainStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const CHAIN_COLORS = [
  { value: 'white', label: 'White' },
  { value: 'black', label: 'Black' },
  { value: 'grey', label: 'Grey' },
];

export default function ChainStep({ config, onUpdate }: ChainStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-sm font-medium mb-4 block">CHAIN & GEOMETRY</Label>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label htmlFor="chainColor" className="text-sm mb-2">Chain Colour</Label>
              <SelectShadcn
                value={config.chainColor}
                onValueChange={(value) => onUpdate({ chainColor: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select An Option" />
                </SelectTrigger>
                <SelectContent>
                  {CHAIN_COLORS.map(color => (
                    <SelectItem key={color.value} value={color.value}>{color.label}</SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            </div>
            <div>
              <Label htmlFor="geometryType" className="text-sm mb-2">Geometry Type</Label>
              <SelectShadcn
                value={config.geometryType}
                onValueChange={(value) => onUpdate({ geometryType: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select An Option" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="standard">Standard</SelectItem>
                  <SelectItem value="custom">Custom</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}



