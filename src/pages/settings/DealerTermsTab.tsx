/**
 * Dealer Detail - Terms & Conditions tab.
 * Sub-tabs: Quote / Proposal / Sales Order.
 * For each: dropdown default template, Set as default, templates list, editor modal.
 */

import { useState } from 'react';
import { formatDate } from '../../lib/utils';
import { FileText, Plus, Pencil, Copy, Check } from 'lucide-react';
import { useTermsTemplates } from '../../hooks/useTermsTemplates';
import { useDealerTermsDefault } from '../../hooks/useDealerTermsDefault';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';
import { setDealerDefaultTermsTemplate, upsertTermsTemplate } from '../../lib/terms';
import type { DocTypeForTerms, DocumentTermsTemplate } from '../../types/terms';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import {
  Select as SelectShadcn,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../../components/ui/SelectShadcn';

const DOC_TYPES: { value: DocTypeForTerms; label: string }[] = [
  { value: 'quote', label: 'Quote' },
  { value: 'proposal', label: 'Proposal' },
  { value: 'sales_order', label: 'Sales Order' },
];

const tabBtnClass = (active: boolean) =>
  `transition-colors flex items-center justify-start border-r ${
    active ? 'bg-white font-semibold' : 'hover:bg-white/50 font-normal'
  }`;

const tabBtnStyle = (active: boolean) => ({
  fontSize: '12px',
  padding: '0 24px',
  height: '100%',
  minWidth: '100px',
  width: 'auto',
  color: 'var(--graphite-black-hex)',
  borderColor: 'var(--gray-250)',
  borderBottom: active ? '2px solid var(--tab-active-underline)' : 'none',
});

export type DealerTermsMode = 'admin' | 'dealerSelf';

interface DealerTermsTabProps {
  dealerId: string;
  /** admin: org users can create global/dealer templates. dealerSelf: fixed dealer scope, no global. */
  mode?: DealerTermsMode;
}

export default function DealerTermsTab({ dealerId, mode = 'admin' }: DealerTermsTabProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const { isSuperAdmin, isOwner, isAdmin } = useCurrentOrgRole();
  const isDealerSelf = mode === 'dealerSelf';
  const canCreateGlobal = !isDealerSelf && (isSuperAdmin || isOwner || isAdmin);
  /** Dealer (dealerSelf) solo ve Proposal; admin ve Quote / Proposal / Sales Order */
  const docTypesForMode = isDealerSelf
    ? DOC_TYPES.filter((d) => d.value === 'proposal')
    : DOC_TYPES;
  const [termsSubTab, setTermsSubTab] = useState<DocTypeForTerms>(isDealerSelf ? 'proposal' : 'quote');

  const { templates, activeTemplates, isLoading, refetch } = useTermsTemplates(
    dealerId,
    termsSubTab,
    activeOrganizationId
  );
  const { templateId: defaultTemplateId, refetch: refetchDefault } = useDealerTermsDefault(
    dealerId,
    termsSubTab
  );

  const [selectedTemplateId, setSelectedTemplateId] = useState<string>('');
  const [setDefaultLoading, setSetDefaultLoading] = useState(false);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<DocumentTermsTemplate | null>(null);
  const [duplicateFrom, setDuplicateFrom] = useState<DocumentTermsTemplate | null>(null);

  const [editorTitle, setEditorTitle] = useState('');
  const [editorContent, setEditorContent] = useState('');
  const [editorActive, setEditorActive] = useState(true);
  const [editorScope, setEditorScope] = useState<'global' | 'dealer'>('dealer');
  const [editorSaving, setEditorSaving] = useState(false);

  const openNew = () => {
    setEditingTemplate(null);
    setDuplicateFrom(null);
    setEditorTitle('');
    setEditorContent('');
    setEditorActive(true);
    setEditorScope(canCreateGlobal ? 'dealer' : 'dealer');
    setEditorOpen(true);
  };

  const openEdit = (t: DocumentTermsTemplate) => {
    setEditingTemplate(t);
    setDuplicateFrom(null);
    setEditorTitle(t.title);
    setEditorContent(t.content || '');
    setEditorActive(t.is_active);
    setEditorScope(isDealerSelf ? 'dealer' : (t.dealer_id ? 'dealer' : 'global'));
    setEditorOpen(true);
  };

  const openDuplicate = (t: DocumentTermsTemplate) => {
    setEditingTemplate(null);
    setDuplicateFrom(t);
    setEditorTitle(`${t.title} (Copy)`);
    setEditorContent(t.content || '');
    setEditorActive(true);
    setEditorScope(isDealerSelf ? 'dealer' : (t.dealer_id ? 'dealer' : 'global'));
    setEditorOpen(true);
  };

  const handleSetDefault = async () => {
    const displayed = selectedTemplateId || defaultTemplateId || '__none__';
    const tid = displayed === '__none__' ? null : displayed;
    setSetDefaultLoading(true);
    try {
      const { error } = await setDealerDefaultTermsTemplate(dealerId, termsSubTab, tid);
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: error });
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Default set',
          message: tid ? 'Default template updated.' : 'Default cleared.',
        });
        refetchDefault();
        refetch();
      }
    } finally {
      setSetDefaultLoading(false);
    }
  };

  const handleSaveTemplate = async () => {
    if (!activeOrganizationId) return;
    setEditorSaving(true);
    try {
      const dealer_id = (isDealerSelf || editorScope === 'dealer') ? dealerId : null;
      const { id, error } = await upsertTermsTemplate({
        id: editingTemplate?.id,
        organization_id: activeOrganizationId,
        dealer_id,
        doc_type: termsSubTab,
        title: editorTitle.trim(),
        content: editorContent,
        is_active: editorActive,
      });
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: error });
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Template saved',
          message: editingTemplate ? 'Template updated.' : 'Template created.',
        });
        setEditorOpen(false);
        refetch();
      }
    } finally {
      setEditorSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
        <FileText className="w-4 h-4" />
        Terms & Conditions
      </h3>

      {/* Sub-tabs */}
      <div
        className="border-b flex items-stretch"
        style={{ height: '2rem', backgroundColor: 'var(--gray-50)', borderColor: 'var(--gray-250)' }}
      >
        {docTypesForMode.map(({ value, label }) => (
          <button
            key={value}
            onClick={() => setTermsSubTab(value)}
            className={tabBtnClass(termsSubTab === value)}
            style={tabBtnStyle(termsSubTab === value)}
            role="tab"
            aria-selected={termsSubTab === value}
          >
            {label}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="py-8 text-sm text-gray-500">Loading templates…</div>
      ) : (
        <>
          {/* Default template dropdown + Set as default */}
          <div className="flex flex-wrap items-end gap-4">
            <div className="min-w-[240px]">
              <Label className="text-xs">Default template for this dealer</Label>
              <SelectShadcn
                value={selectedTemplateId || defaultTemplateId || '__none__'}
                onValueChange={(v) => setSelectedTemplateId(v === '__none__' ? '' : v)}
              >
                <SelectTrigger className="py-1.5 text-sm">
                  <SelectValue placeholder="No default" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__none__">No default</SelectItem>
                  {activeTemplates.map((t) => (
                    <SelectItem key={t.id} value={t.id}>
                      {t.title} ({t.dealer_id ? 'Dealer' : 'Global'})
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
            </div>
            <button
              type="button"
              onClick={handleSetDefault}
              disabled={setDefaultLoading}
              className="px-4 py-1.5 text-sm bg-gray-800 text-white rounded hover:bg-gray-700 disabled:opacity-50 flex items-center gap-2"
            >
              {setDefaultLoading ? (
                'Saving…'
              ) : (
                <>
                  <Check className="w-4 h-4" />
                  Set as default
                </>
              )}
            </button>
          </div>

          {/* Templates list */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <Label className="text-xs">Templates</Label>
              <button
                type="button"
                onClick={openNew}
                className="text-xs flex items-center gap-1 text-gray-600 hover:text-gray-900"
              >
                <Plus className="w-4 h-4" />
                New
              </button>
            </div>
            <div className="border border-gray-200 rounded overflow-hidden">
              {templates.length === 0 ? (
                <div className="py-6 text-center text-sm text-gray-500">No templates yet. Create one with New.</div>
              ) : (
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="text-left py-2 px-3 font-medium text-gray-700">Title</th>
                      <th className="text-left py-2 px-3 font-medium text-gray-700">Scope</th>
                      <th className="text-left py-2 px-3 font-medium text-gray-700">Updated</th>
                      <th className="text-left py-2 px-3 font-medium text-gray-700">Active</th>
                      <th className="text-right py-2 px-3 font-medium text-gray-700">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {templates.map((t) => (
                      <tr key={t.id} className="border-t border-gray-100 hover:bg-gray-50">
                        <td className="py-2 px-3">{t.title}</td>
                        <td className="py-2 px-3">{t.dealer_id ? 'Dealer' : 'Global'}</td>
                        <td className="py-2 px-3 text-gray-600">
                          {formatDate(t.updated_at)}
                        </td>
                        <td className="py-2 px-3">{t.is_active ? 'Yes' : 'No'}</td>
                        <td className="py-2 px-3 text-right">
                          {(!isDealerSelf || t.dealer_id) && (
                            <>
                              <button
                                type="button"
                                onClick={() => openEdit(t)}
                                className="text-gray-600 hover:text-gray-900 p-1"
                                title="Edit"
                              >
                                <Pencil className="w-4 h-4" />
                              </button>
                              <button
                                type="button"
                                onClick={() => openDuplicate(t)}
                                className="text-gray-600 hover:text-gray-900 p-1 ml-1"
                                title="Duplicate"
                              >
                                <Copy className="w-4 h-4" />
                              </button>
                            </>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        </>
      )}

      {/* Editor modal */}
      {editorOpen && (
        <div
          className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center"
          onClick={() => !editorSaving && setEditorOpen(false)}
        >
          <div
            className="bg-white rounded-lg shadow-lg max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="p-6">
              <h4 className="text-base font-semibold mb-4">
                {editingTemplate ? 'Edit Template' : duplicateFrom ? 'Duplicate Template' : 'New Template'}
              </h4>
              <div className="space-y-4">
                <div>
                  <Label className="text-xs">Title</Label>
                  <Input
                    value={editorTitle}
                    onChange={(e) => setEditorTitle(e.target.value)}
                    className="mt-1"
                  />
                </div>
                <div>
                  <Label className="text-xs">Content</Label>
                  <textarea
                    value={editorContent}
                    onChange={(e) => setEditorContent(e.target.value)}
                    rows={8}
                    className="w-full border border-gray-200 rounded px-3 py-2 text-sm"
                  />
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    id="editor_active"
                    checked={editorActive}
                    onChange={(e) => setEditorActive(e.target.checked)}
                    className="h-4 w-4"
                  />
                  <Label htmlFor="editor_active">Active</Label>
                </div>
                {canCreateGlobal && !isDealerSelf && (
                  <div>
                    <Label className="text-xs">Scope</Label>
                    <SelectShadcn value={editorScope} onValueChange={(v) => setEditorScope(v as 'global' | 'dealer')}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="global">Global (factory templates)</SelectItem>
                        <SelectItem value="dealer">Dealer-specific</SelectItem>
                      </SelectContent>
                    </SelectShadcn>
                  </div>
                )}
              </div>
              <div className="flex justify-end gap-2 mt-6">
                <button
                  type="button"
                  onClick={() => setEditorOpen(false)}
                  disabled={editorSaving}
                  className="px-4 py-2 text-sm border border-gray-200 rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleSaveTemplate}
                  disabled={editorSaving || !editorTitle.trim()}
                  className="px-4 py-2 text-sm bg-gray-800 text-white rounded hover:bg-gray-700 disabled:opacity-50"
                >
                  {editorSaving ? 'Saving…' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
