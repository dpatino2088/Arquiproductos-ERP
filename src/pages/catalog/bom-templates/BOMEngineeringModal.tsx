import { X, Info } from 'lucide-react';
import Label from '../../../components/ui/Label';
import Input from '../../../components/ui/Input';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../../components/ui/SelectShadcn';
import { getAllRoleOptions } from '../../../lib/bom/roles';
import { useUIStore } from '../../../stores/ui-store';
import type { EngineeringData } from './types';

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

const DELTA_SOURCE_OPTIONS = [
  { value: 'fixed', label: 'Fixed (manual value)' },
  { value: 'derived', label: 'Derived from component (v2)' },
] as const;

const ENG_ATTR_KEY_OPTIONS = [
  { value: 'takeup_mm', label: 'takeup_mm' },
  { value: 'offset_mm', label: 'offset_mm' },
] as const;

const ENG_SCOPE_OPTIONS = [
  { value: 'total', label: 'Total' },
  { value: 'per_side', label: 'Per side' },
] as const;

export interface BOMEngineeringModalProps {
  showEngineeringModal: boolean;
  engineeringData: EngineeringData;
  setEngineeringData: (data: EngineeringData) => void;
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
  const isDerived = engineeringData.engineering_delta_source === 'derived';

  const handleCutAxisChange = (value: string) => {
    const next = value as 'length' | 'width' | 'height' | 'none';
    setEngineeringData({
      ...engineeringData,
      cut_axis: next,
      ...(next === 'none' ? { depends_on_role: '' } : {}),
    });
  };

  const handleDependsOnRoleChange = (value: string) => {
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

  const handleDeltaSourceChange = (value: string) => {
    const src = value as 'fixed' | 'derived';
    setEngineeringData({
      ...engineeringData,
      engineering_delta_source: src,
      ...(src === 'fixed' ? { engineering_attr_key: '', engineering_source_role: '' } : {}),
    });
  };

  const handleSourceRoleChange = (value: string) => {
    setEngineeringData({
      ...engineeringData,
      engineering_source_role: value === 'none' ? '' : value,
    });
  };

  const handleAttrKeyChange = (value: string) => {
    setEngineeringData({ ...engineeringData, engineering_attr_key: value });
  };

  const handleEngScopeChange = (value: string) => {
    setEngineeringData({
      ...engineeringData,
      engineering_scope: value as 'total' | 'per_side',
    });
  };

  const roleOptions = getAllRoleOptions();

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white max-w-md w-full rounded shadow-lg max-h-[90vh] flex flex-col"
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

        <div className="px-4 py-4 space-y-4 overflow-y-auto flex-1">
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
                {roleOptions.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
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

          <div className="border-t border-gray-200 pt-4">
            <p className="text-xs font-semibold text-gray-500 uppercase mb-3">Delta Source (v2 Preparation)</p>

            <div>
              <Label htmlFor="delta-source">Source Type</Label>
              <SelectShadcn
                value={engineeringData.engineering_delta_source}
                onValueChange={handleDeltaSourceChange}
              >
                <SelectTrigger id="delta-source">
                  <SelectValue placeholder="Select source" />
                </SelectTrigger>
                <SelectContent>
                  {DELTA_SOURCE_OPTIONS.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            </div>

            {isDerived && (
              <>
                <div className="mt-3">
                  <Label htmlFor="source-role">Source Role</Label>
                  <SelectShadcn
                    value={engineeringData.engineering_source_role || 'none'}
                    onValueChange={handleSourceRoleChange}
                  >
                    <SelectTrigger id="source-role">
                      <SelectValue placeholder="Select role" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">— None —</SelectItem>
                      {roleOptions.map((opt) => (
                        <SelectItem key={opt.value} value={opt.value}>
                          {opt.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>

                <div className="mt-3">
                  <Label htmlFor="attr-key">Attribute Key</Label>
                  <SelectShadcn
                    value={engineeringData.engineering_attr_key || 'takeup_mm'}
                    onValueChange={handleAttrKeyChange}
                  >
                    <SelectTrigger id="attr-key">
                      <SelectValue placeholder="Select attribute" />
                    </SelectTrigger>
                    <SelectContent>
                      {ENG_ATTR_KEY_OPTIONS.map((o) => (
                        <SelectItem key={o.value} value={o.value}>
                          {o.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>

                <div className="mt-3">
                  <Label htmlFor="eng-scope">Engineering Scope</Label>
                  <SelectShadcn
                    value={engineeringData.engineering_scope}
                    onValueChange={handleEngScopeChange}
                  >
                    <SelectTrigger id="eng-scope">
                      <SelectValue placeholder="Select scope" />
                    </SelectTrigger>
                    <SelectContent>
                      {ENG_SCOPE_OPTIONS.map((o) => (
                        <SelectItem key={o.value} value={o.value}>
                          {o.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                </div>
              </>
            )}
          </div>

          <div className="bg-gray-50 border border-gray-200 rounded p-3 flex gap-2">
            <Info className="h-4 w-4 text-gray-400 flex-shrink-0 mt-0.5" />
            <div className="text-xs text-gray-600">
              {isDerived ? (
                <>
                  <span className="font-medium">Derived delta (v2):</span>{' '}
                  Cut adjustment will be resolved from{' '}
                  <span className="font-mono text-amber-700">
                    {engineeringData.engineering_source_role || '?'}.{engineeringData.engineering_attr_key || '?'}
                  </span>{' '}
                  ({engineeringData.engineering_scope}).{' '}
                  Currently uses <span className="font-mono">cut_delta_mm = {engineeringData.cut_delta_mm ?? 0}</span> as fallback.
                </>
              ) : (
                <>
                  <span className="font-medium">Fixed delta:</span>{' '}
                  Cut adjustment: <span className="font-mono">{engineeringData.cut_delta_mm ?? 0} mm</span> (manual value)
                </>
              )}
            </div>
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
