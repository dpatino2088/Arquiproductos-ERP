import { useState } from 'react';
import { useWorkCenters, type WorkCenter, type WorkCenterInput } from '../../hooks/useWorkCenters';
import { usePermissions } from '../../hooks/usePermissions';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Plus, Edit2, Trash2, X, Check, Factory } from 'lucide-react';

const ROUTING_PRESETS: Record<string, { label: string; rule: Record<string, unknown> }> = {
  'cut-profile': { label: 'Profiles', rule: { category_parent_names: ['Profiles'] } },
  'cut-roll': { label: 'Rolls / Fabric', rule: { category_parent_names: ['Rolls'], part_roles: ['fabric'] } },
  'assembly': { label: 'Assembly (all)', rule: { is_assembly: true } },
};

function ruleToLabel(rule: Record<string, unknown>): string {
  if ((rule as any).is_assembly) return 'Assembly (all)';
  const parts: string[] = [];
  if (Array.isArray(rule.category_parent_names)) {
    parts.push((rule.category_parent_names as string[]).join(', '));
  }
  if (Array.isArray(rule.part_roles)) parts.push(`roles: ${(rule.part_roles as string[]).join(', ')}`);
  if (rule.measure_basis) parts.push(`${rule.measure_basis}`);
  if (rule.is_roll === true) parts.push('roll');
  if (rule.is_roll === false) parts.push('non-roll');
  return parts.length > 0 ? parts.join(' + ') : 'Custom';
}

export default function WorkCentersSettings() {
  const { centers, loading, error, upsert, remove } = useWorkCenters();
  const { can } = usePermissions();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isAdding, setIsAdding] = useState(false);
  const [form, setForm] = useState<WorkCenterInput>({ code: '', name: '', sequence: 0, is_active: true });
  const [saving, setSaving] = useState(false);

  const startEdit = (wc: WorkCenter) => {
    setEditingId(wc.id);
    setIsAdding(false);
    setForm({ code: wc.code, name: wc.name, description: wc.description, sequence: wc.sequence, is_active: wc.is_active, routing_rule: wc.routing_rule, capacity_hours_per_day: wc.capacity_hours_per_day ?? 8 });
  };

  const startAdd = () => {
    setEditingId(null);
    setIsAdding(true);
    setForm({ code: '', name: '', description: '', sequence: (centers.length + 1) * 10, is_active: true, routing_rule: {}, capacity_hours_per_day: 8 });
  };

  const cancel = () => { setEditingId(null); setIsAdding(false); };

  const handleSave = async () => {
    setSaving(true);
    try {
      await upsert(editingId, form);
      cancel();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Error saving');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this work center?')) return;
    try { await remove(id); } catch { /* ignore */ }
  };

  if (loading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4" />
        <p className="text-sm text-gray-600">Loading work centers...</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Work Centers</h2>
          <p className="text-sm text-gray-500 mt-1">Configure manufacturing workstations and routing rules.</p>
        </div>
        {!isAdding && can('settings.write') && (
          <button type="button" onClick={startAdd} className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-primary rounded hover:opacity-90">
            <Plus className="h-3.5 w-3.5" />
            Add Work Center
          </button>
        )}
      </div>

      {error && <p className="text-sm text-red-600 bg-red-50 rounded px-3 py-2">{error}</p>}

      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-200">
              <th className="text-left px-4 py-2.5 font-medium text-gray-700">Code</th>
              <th className="text-left px-4 py-2.5 font-medium text-gray-700">Name</th>
              <th className="text-left px-4 py-2.5 font-medium text-gray-700">Routing</th>
              <th className="text-center px-4 py-2.5 font-medium text-gray-700">Seq</th>
              <th className="text-center px-4 py-2.5 font-medium text-gray-700">Capacity (h/day)</th>
              <th className="text-center px-4 py-2.5 font-medium text-gray-700">Active</th>
              <th className="text-right px-4 py-2.5 font-medium text-gray-700">Actions</th>
            </tr>
          </thead>
          <tbody>
            {centers.map((wc) => {
              const isEditing = editingId === wc.id;
              if (isEditing) {
                return (
                  <tr key={wc.id} className="border-t border-gray-100 bg-blue-50/30">
                    <td className="px-4 py-2"><Input value={form.code} onChange={(e) => setForm((p) => ({ ...p, code: e.target.value }))} className="text-xs" /></td>
                    <td className="px-4 py-2"><Input value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} className="text-xs" /></td>
                    <td className="px-4 py-2">
                      <select className="text-xs border border-gray-200 rounded px-2 py-1 w-full" value={JSON.stringify(form.routing_rule)} onChange={(e) => setForm((p) => ({ ...p, routing_rule: JSON.parse(e.target.value) }))}>
                        {Object.entries(ROUTING_PRESETS).map(([k, v]) => (
                          <option key={k} value={JSON.stringify(v.rule)}>{v.label}</option>
                        ))}
                      </select>
                    </td>
                    <td className="px-4 py-2 text-center"><Input type="number" value={form.sequence} onChange={(e) => setForm((p) => ({ ...p, sequence: parseInt(e.target.value, 10) || 0 }))} className="text-xs w-16 text-center mx-auto" /></td>
                    <td className="px-4 py-2 text-center"><Input type="number" step="1" min="1" max="24" value={form.capacity_hours_per_day ?? 8} onChange={(e) => setForm((p) => ({ ...p, capacity_hours_per_day: parseFloat(e.target.value) || 8 }))} className="text-xs w-16 text-center mx-auto" /></td>
                    <td className="px-4 py-2 text-center">
                      <input type="checkbox" checked={form.is_active} onChange={(e) => setForm((p) => ({ ...p, is_active: e.target.checked }))} />
                    </td>
                    <td className="px-4 py-2 text-right">
                      <div className="inline-flex gap-1">
                        <button type="button" onClick={handleSave} disabled={saving} className="p-1 rounded hover:bg-green-100 text-green-600"><Check className="h-4 w-4" /></button>
                        <button type="button" onClick={cancel} className="p-1 rounded hover:bg-gray-200 text-gray-500"><X className="h-4 w-4" /></button>
                      </div>
                    </td>
                  </tr>
                );
              }
              return (
                <tr key={wc.id} className="border-t border-gray-100 hover:bg-gray-50/50">
                  <td className="px-4 py-2.5 font-mono text-gray-700">{wc.code}</td>
                  <td className="px-4 py-2.5 text-gray-900">{wc.name}</td>
                  <td className="px-4 py-2.5">
                    <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded">{ruleToLabel(wc.routing_rule)}</span>
                  </td>
                  <td className="px-4 py-2.5 text-center text-gray-500">{wc.sequence}</td>
                  <td className="px-4 py-2.5 text-center text-gray-500">{wc.capacity_hours_per_day ?? 8}h</td>
                  <td className="px-4 py-2.5 text-center">
                    {wc.is_active ? <span className="text-green-600 font-medium">Yes</span> : <span className="text-gray-400">No</span>}
                  </td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="inline-flex gap-1">
                      <button type="button" onClick={() => startEdit(wc)} className="p-1 rounded hover:bg-gray-200 text-gray-500"><Edit2 className="h-3.5 w-3.5" /></button>
                      {can('settings.write') && (
                        <button type="button" onClick={() => handleDelete(wc.id)} className="p-1 rounded hover:bg-red-50 text-red-500"><Trash2 className="h-3.5 w-3.5" /></button>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}

            {isAdding && (
              <tr className="border-t border-gray-100 bg-green-50/30">
                <td className="px-4 py-2"><Input value={form.code} onChange={(e) => setForm((p) => ({ ...p, code: e.target.value }))} placeholder="CODE" className="text-xs" /></td>
                <td className="px-4 py-2"><Input value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} placeholder="Name" className="text-xs" /></td>
                <td className="px-4 py-2">
                  <select className="text-xs border border-gray-200 rounded px-2 py-1 w-full" value={JSON.stringify(form.routing_rule)} onChange={(e) => setForm((p) => ({ ...p, routing_rule: JSON.parse(e.target.value) }))}>
                    {Object.entries(ROUTING_PRESETS).map(([k, v]) => (
                      <option key={k} value={JSON.stringify(v.rule)}>{v.label}</option>
                    ))}
                  </select>
                </td>
                <td className="px-4 py-2 text-center"><Input type="number" value={form.sequence} onChange={(e) => setForm((p) => ({ ...p, sequence: parseInt(e.target.value, 10) || 0 }))} className="text-xs w-16 text-center mx-auto" /></td>
                <td className="px-4 py-2 text-center"><Input type="number" step="1" min="1" max="24" value={form.capacity_hours_per_day ?? 8} onChange={(e) => setForm((p) => ({ ...p, capacity_hours_per_day: parseFloat(e.target.value) || 8 }))} className="text-xs w-16 text-center mx-auto" /></td>
                <td className="px-4 py-2 text-center">
                  <input type="checkbox" checked={form.is_active} onChange={(e) => setForm((p) => ({ ...p, is_active: e.target.checked }))} />
                </td>
                <td className="px-4 py-2 text-right">
                  <div className="inline-flex gap-1">
                    <button type="button" onClick={handleSave} disabled={saving} className="p-1 rounded hover:bg-green-100 text-green-600"><Check className="h-4 w-4" /></button>
                    <button type="button" onClick={cancel} className="p-1 rounded hover:bg-gray-200 text-gray-500"><X className="h-4 w-4" /></button>
                  </div>
                </td>
              </tr>
            )}

            {centers.length === 0 && !isAdding && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-400">
                  <Factory className="h-8 w-8 mx-auto mb-2 text-gray-300" />
                  <p className="text-sm">No work centers configured.</p>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
