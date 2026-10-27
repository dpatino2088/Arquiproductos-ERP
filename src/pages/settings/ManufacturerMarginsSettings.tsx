import React, { useMemo, useState } from 'react';
import { Check, ChevronDown, ChevronRight, Search, X } from 'lucide-react';
import Input from '../../components/ui/Input';
import { useManufacturerMargins } from '../../hooks/useCostEngineSettings';

type EditTarget =
  | { kind: 'manufacturer'; manufacturerId: string }
  | { kind: 'category'; manufacturerId: string; categoryId: string };

function pctLabel(value: number | null | undefined, fallback: string) {
  if (value == null) return fallback;
  return `${Math.round(value * 100)}%`;
}

export default function ManufacturerMarginsSettings() {
  const {
    manufacturers,
    margins,
    categoryMargins,
    categories,
    loading,
    saveManufacturerMargin,
    clearManufacturerMargin,
    saveManufacturerCategoryMargin,
    clearManufacturerCategoryMargin,
  } = useManufacturerMargins();

  const [search, setSearch] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [editing, setEditing] = useState<EditTarget | null>(null);
  const [draft, setDraft] = useState('');
  const [saving, setSaving] = useState(false);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return manufacturers;
    return manufacturers.filter((m) => m.name.toLowerCase().includes(q));
  }, [manufacturers, search]);

  const startEdit = (target: EditTarget, current: number | null) => {
    setEditing(target);
    setDraft(current == null ? '' : String(Math.round(current * 100)));
  };

  const save = async () => {
    if (!editing) return;
    const marginPct = parseFloat(draft);
    if (Number.isNaN(marginPct) || marginPct < 0 || marginPct >= 100) {
      alert('Minimum margin must be between 0 and 99');
      return;
    }
    setSaving(true);
    try {
      if (editing.kind === 'manufacturer') {
        await saveManufacturerMargin(editing.manufacturerId, marginPct / 100);
      } else {
        await saveManufacturerCategoryMargin(editing.manufacturerId, editing.categoryId, marginPct / 100);
      }
      setEditing(null);
      setDraft('');
    } catch (err: any) {
      alert(err?.message || 'Could not save the margin.');
    } finally {
      setSaving(false);
    }
  };

  const clear = async (target: EditTarget) => {
    setSaving(true);
    try {
      if (target.kind === 'manufacturer') {
        await clearManufacturerMargin(target.manufacturerId);
      } else {
        await clearManufacturerCategoryMargin(target.manufacturerId, target.categoryId);
      }
      setEditing(null);
      setDraft('');
    } catch (err: any) {
      alert(err?.message || 'Could not clear the margin.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div className="text-center py-8 text-sm text-gray-500">Loading manufacturers...</div>;
  }

  return (
    <div>
      <div className="mb-4">
        <h3 className="text-sm font-semibold text-gray-900 mb-1">Manufacturer Margins</h3>
        <p className="text-xs text-gray-500">
          Set the minimum margin for a manufacturer. It replaces the category margin for every item of that manufacturer.
          Open a manufacturer to set a different margin on one of its categories.
        </p>
      </div>

      <div className="mb-4 bg-white border border-gray-200 rounded-lg py-4 px-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search manufacturers..."
            className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
          />
        </div>
      </div>

      <div className="space-y-2">
        {filtered.map((manufacturer) => {
          const margin = margins.find((row) => row.manufacturer_id === manufacturer.id);
          const isOpen = openId === manufacturer.id;
          const isEditingMfr = editing?.kind === 'manufacturer' && editing.manufacturerId === manufacturer.id;
          const mfrCategories = categories.filter((row) => row.manufacturer_id === manufacturer.id);

          return (
            <div key={manufacturer.id} className="bg-white border border-gray-200 rounded-lg">
              <div className="flex items-center gap-3 p-4">
                <button
                  type="button"
                  onClick={() => setOpenId(isOpen ? null : manufacturer.id)}
                  className="p-1 text-gray-500 hover:text-gray-800"
                  title="Categories"
                >
                  {isOpen ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                </button>
                <div className="min-w-0 flex-1">
                  <div className="font-medium text-gray-900 truncate">{manufacturer.name}</div>
                  <div className="text-xs text-gray-500">
                    {margin ? 'Applies to all of its items' : 'Uses each item category'}
                  </div>
                </div>
                {isEditingMfr ? (
                  <div className="flex items-center gap-2">
                    <Input
                      type="number"
                      min="0"
                      max="99"
                      step="1"
                      value={draft}
                      onChange={(e) => setDraft(e.target.value)}
                      className="w-16 py-1 text-xs text-right"
                    />
                    <span className="text-xs text-gray-500">%</span>
                    <button type="button" onClick={save} disabled={saving} className="p-1.5 hover:bg-green-50 rounded text-green-600" title="Save">
                      <Check className="w-4 h-4" />
                    </button>
                    <button type="button" onClick={() => setEditing(null)} className="p-1.5 hover:bg-gray-100 rounded text-gray-600" title="Cancel">
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center gap-3">
                    <span className="text-sm font-medium text-gray-800 w-28 text-right">
                      {pctLabel(margin?.minimum_margin_pct, 'Category')}
                    </span>
                    <button
                      type="button"
                      className="text-sm text-primary hover:underline"
                      onClick={() => startEdit({ kind: 'manufacturer', manufacturerId: manufacturer.id }, margin?.minimum_margin_pct ?? null)}
                    >
                      Edit
                    </button>
                    {margin && (
                      <button
                        type="button"
                        className="text-sm text-gray-500 hover:underline"
                        onClick={() => clear({ kind: 'manufacturer', manufacturerId: manufacturer.id })}
                      >
                        Clear
                      </button>
                    )}
                  </div>
                )}
              </div>

              {isOpen && (
                <div className="border-t border-gray-100 px-4 py-3 bg-gray-50">
                  {mfrCategories.length === 0 ? (
                    <p className="text-xs text-gray-500">This manufacturer has no catalog items.</p>
                  ) : (
                    <div className="space-y-2">
                      {mfrCategories.map((category) => {
                        const catMargin = categoryMargins.find(
                          (row) => row.manufacturer_id === manufacturer.id && row.category_id === category.category_id
                        );
                        const isEditingCat =
                          editing?.kind === 'category' &&
                          editing.manufacturerId === manufacturer.id &&
                          editing.categoryId === category.category_id;
                        const fallback = margin
                          ? `Uses manufacturer (${Math.round(margin.minimum_margin_pct * 100)}%)`
                          : 'Uses category';

                        return (
                          <div key={category.category_id} className="flex items-center gap-3 pl-8">
                            <div className="flex-1 text-sm text-gray-800">{category.name}</div>
                            {isEditingCat ? (
                              <div className="flex items-center gap-2">
                                <Input
                                  type="number"
                                  min="0"
                                  max="99"
                                  step="1"
                                  value={draft}
                                  onChange={(e) => setDraft(e.target.value)}
                                  className="w-16 py-1 text-xs text-right"
                                />
                                <span className="text-xs text-gray-500">%</span>
                                <button type="button" onClick={save} disabled={saving} className="p-1.5 hover:bg-green-50 rounded text-green-600" title="Save">
                                  <Check className="w-4 h-4" />
                                </button>
                                <button type="button" onClick={() => setEditing(null)} className="p-1.5 hover:bg-gray-100 rounded text-gray-600" title="Cancel">
                                  <X className="w-4 h-4" />
                                </button>
                              </div>
                            ) : (
                              <div className="flex items-center gap-3">
                                <span className="text-sm text-gray-700 w-44 text-right">
                                  {catMargin ? pctLabel(catMargin.minimum_margin_pct, '') : fallback}
                                </span>
                                <button
                                  type="button"
                                  className="text-sm text-primary hover:underline"
                                  onClick={() =>
                                    startEdit(
                                      { kind: 'category', manufacturerId: manufacturer.id, categoryId: category.category_id },
                                      catMargin?.minimum_margin_pct ?? margin?.minimum_margin_pct ?? null
                                    )
                                  }
                                >
                                  Edit
                                </button>
                                {catMargin && (
                                  <button
                                    type="button"
                                    className="text-sm text-gray-500 hover:underline"
                                    onClick={() =>
                                      clear({
                                        kind: 'category',
                                        manufacturerId: manufacturer.id,
                                        categoryId: category.category_id,
                                      })
                                    }
                                  >
                                    Clear
                                  </button>
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
