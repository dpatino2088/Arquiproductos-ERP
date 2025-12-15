import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';

interface GeometryStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

export default function GeometryStep({ config, onUpdate }: GeometryStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <Label className="text-sm font-medium mb-4 block">GEOMETRY</Label>
        <p className="text-sm text-gray-600">
          Geometry configuration is handled in the Chain / CORD step.
        </p>
      </div>
    </div>
  );
}



