import { X } from 'lucide-react';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import { CANONICAL_COMPONENT_ROLES, getRoleLabel, isValidRole } from '../../../lib/bom/roles';
import { useUIStore } from '../../../stores/ui-store';

const CUT_AXIS_OPTIONS = [
  { value: 'none', label: 'None' },
  { value: 'length', label: 'Length' },
  { value: 'width', label: 'Width' },
  { value: 'height', label: 'Height' },
] as const;

const DELTA_SCOPE_OPTIONS = [
  { value: 'none', label: 'None' },
  { value: 'per_item', label: 'Per item' },
  { value: 'per_side', label: 'Per side' },
] as const;

export interface BOMEngineeringModalProps {
  showEngineeringModal: boolean;
  engineeringData: {
    depends_on_role: string;
    cut_axis: 'length' | 'width' | 'height' | 'none';
    cut_delta_mm: number | null;
    cut_delta_scope: 'per_side' | 'per_item' | 'none';
  };
  setEngineeringData: (data: any) => void;
  onSave: () => void;
  onClose: () => void;
}

export default function BOMEngineeringModal({
  showEngineeringModal,
  engineeringData,
  setEngineeringData,
  onSave,
  onClose,
}: BOMEngineeringModalProps) {
  useUIStore();
  if (!showEngineeringModal) return null;

  const isDependsOnRoleDisabled = engineeringData.cut_axis === 'none';

  const handleCutAxisChange = (value: string) => {
    const next = value as 'length' | 'width' | 'height' | 'none';
    setEngineeringData({
      ...engineeringData,
      cut_axis: next,
      ...(next === 'none' ? { depends_on_role: '' } : {}),
    });
  };

  const handleDependsOnRoleChange = (value: string) => {
    if (!isValidRole(value)) return;
    setEngineeringData({ ...engineeringData, depends_on_role: value });
  };

  const handleDeltaChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const v = e.target.value;
    const num = v === '' ? null : parseFloat(v);
    setEngineeringData({ ...engineeringData, cut_delta_mm: isNaN(num as number) ? null : num });
  };

  const handleDeltaScopeChange = (value: string) => {
    setEngineeringData({
      ...engineeringData,
      cut_delta_scope: value as 'per_side' | 'per_item' | 'none',
    });
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white max-w-md w-full rounded shadow-lg"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200">
          <h3 className="text-sm font-semibold text-gray-900">Engineering Rules</h3>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded hover:bg-gray-100 text-gray-500 hover:text-gray-700"
            aria-label="Close"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="px-4 py-4 space-y-4">
          <div>
            <Label htmlFor="cut-axis">Cut Axis</Label>
            <SelectShadcn
              value={engineeringData.cut_axis}
              onValueChange={handleCutAxisChange}
            >
              <SelectTrigger id="cut-axis">
                <SelectValue placeholder="Select axis" />
              </SelectTrigger>
              <SelectContent>
                {CUT_AXIS_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>

          <div>
            <Label htmlFor="depends-on-role">Depends on Role</Label>
            <SelectShadcn
              value={engineeringData.depends_on_role || 'none'}
              onValueChange={(v) => handleDependsOnRoleChange(v === 'none' ? '' : v)}
              disabled={isDependsOnRoleDisabled}
            >
              <SelectTrigger id="depends-on-role">
                <SelectValue placeholder="Select role" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">— None —</SelectItem>
                {CANONICAL_COMPONENT_ROLES.map((role) => (
                  <SelectItem key={role} value={role}>
                    {getRoleLabel(role)}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            <p className="mt-1 text-xs text-gray-500">
              {isDependsOnRoleDisabled
                ? 'Select a cut axis first to enable this field'
                : 'Role that this component depends on'}
            </p>
          </div>

          <div>
            <Label htmlFor="delta-mm">Delta (mm)</Label>
            <Input
              id="delta-mm"
              type="number"
              step="0.01"
              value={engineeringData.cut_delta_mm ?? ''}
              onChange={handleDeltaChange}
              placeholder="0"
            />
          </div>

          <div>
            <Label htmlFor="delta-scope">Delta Scope</Label>
            <SelectShadcn
              value={engineeringData.cut_delta_scope}
              onValueChange={handleDeltaScopeChange}
            >
              <SelectTrigger id="delta-scope">
                <SelectValue placeholder="Select scope" />
              </SelectTrigger>
              <SelectContent>
                {DELTA_SCOPE_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
          </div>
        </div>

        <div className="flex justify-end gap-2 px-4 py-3 border-t border-gray-200">
          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onSave}
            className="px-3 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
