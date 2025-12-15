import { CurtainConfiguration } from '../CurtainConfigurator';
import Label from '../../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../../components/ui/SelectShadcn';
import Input from '../../../components/ui/Input';

interface FilmStepProps {
  config: CurtainConfiguration;
  onUpdate: (updates: Partial<CurtainConfiguration>) => void;
}

const FILM_TYPES = [
  { id: '73-silver-anthracite', name: '73 Silver / Anthracite', weight: '110 g/m²' },
  { id: '74-silver-anthracite', name: '74 Silver / Anthracite', weight: '145 g/m²' },
  { id: '81-silver-white', name: '81 Silver / White', weight: '110 g/m²' },
];

const EMBOSSING_OPTIONS = [
  { value: 'flat', label: 'Flat' },
  { value: 'textured', label: 'Textured' },
  { value: 'pattern', label: 'Pattern' },
];

const G_VALUE_OPTIONS = [
  { value: '5%', label: '5%' },
  { value: '10%', label: '10%' },
  { value: '15%', label: '15%' },
  { value: '20%', label: '20%' },
];

export default function FilmStep({ config, onUpdate }: FilmStepProps) {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        {/* Film Type */}
        <div>
          <Label className="text-sm font-medium mb-4 block">FILM TYPE</Label>
          <div className="grid grid-cols-3 gap-4">
            {FILM_TYPES.map((film) => {
              const isSelected = config.filmType === film.id;
              return (
                <button
                  key={film.id}
                  onClick={() => onUpdate({ filmType: film.id })}
                  className={`p-4 border-2 rounded-lg text-center transition-all ${
                    isSelected
                      ? 'border-primary bg-primary/5'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <div className="w-full h-32 bg-gradient-to-r from-gray-300 to-gray-500 rounded mb-2 flex items-center justify-center">
                    <span className="text-xs text-white font-medium">{film.weight}</span>
                  </div>
                  <span className="text-sm font-medium">{film.name}</span>
                  {isSelected && (
                    <div className="mt-2 text-primary text-xs">✓ Selected</div>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Options */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label htmlFor="viewToOutside" className="text-sm mb-2">View To Outside</Label>
            <SelectShadcn
              value={config.viewToOutside ? 'yes' : config.viewToOutside === false ? 'no' : undefined}
              onValueChange={(value) => onUpdate({ viewToOutside: value === 'yes' })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="yes">Yes</SelectItem>
                <SelectItem value="no">No</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="heatProtection" className="text-sm mb-2">Heat Protection</Label>
            <SelectShadcn
              value={config.heatProtection ? 'yes' : config.heatProtection === false ? 'no' : undefined}
              onValueChange={(value) => onUpdate({ heatProtection: value === 'yes' })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="yes">Yes</SelectItem>
                <SelectItem value="no">No</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="glareProtection" className="text-sm mb-2">Glare Protection</Label>
            <SelectShadcn
              value={config.glareProtection ? 'yes' : config.glareProtection === false ? 'no' : undefined}
              onValueChange={(value) => onUpdate({ glareProtection: value === 'yes' })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="yes">Yes</SelectItem>
                <SelectItem value="no">No</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="gValue" className="text-sm mb-2">G-value</Label>
            <SelectShadcn
              value={config.gValue}
              onValueChange={(value) => onUpdate({ gValue: value })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                {G_VALUE_OPTIONS.map(opt => (
                  <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="ralColor" className="text-sm mb-2">RAL Colour</Label>
            <Input
              id="ralColor"
              value={config.ralColor || ''}
              onChange={(e) => onUpdate({ ralColor: e.target.value })}
              placeholder="Other Colour"
            />
          </div>

          <div>
            <Label htmlFor="embossing" className="text-sm mb-2">Embossing</Label>
            <SelectShadcn
              value={config.embossing}
              onValueChange={(value) => onUpdate({ embossing: value })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                {EMBOSSING_OPTIONS.map(opt => (
                  <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="pleating_mm" className="text-sm mb-2">Pleating (mm)</Label>
            <Input
              id="pleating_mm"
              type="number"
              min="0"
              value={config.pleating_mm || ''}
              onChange={(e) => onUpdate({ pleating_mm: parseInt(e.target.value) || undefined })}
              placeholder="80"
            />
          </div>

          <div>
            <Label htmlFor="operationSide" className="text-sm mb-2">Operation Side</Label>
            <SelectShadcn
              value={config.operationSide}
              onValueChange={(value) => onUpdate({ operationSide: value as 'left' | 'right' })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select option" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="left">Left</SelectItem>
                <SelectItem value="right">Right</SelectItem>
              </SelectContent>
            </SelectShadcn>
          </div>
        </div>
      </div>
    </div>
  );
}



