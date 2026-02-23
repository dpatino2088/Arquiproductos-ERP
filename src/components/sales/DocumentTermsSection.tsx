/**
 * Reusable Terms & Conditions section for Quote, Proposal, Sales Order.
 * Editable terms_title + terms_content, Reset to default, Save as template.
 */

import { useState } from 'react';
import {
  resolveDefaultTermsTemplateId,
  fetchTermsTemplateById,
  upsertTermsTemplate,
  setDealerDefaultTermsTemplate,
} from '../../lib/terms';
import { useUIStore } from '../../stores/ui-store';
import type { DocTypeForTerms } from '../../types/terms';
import Input from '../ui/Input';
import Label from '../ui/Label';

export interface DocumentTermsSectionProps {
  docType: DocTypeForTerms;
  orgId: string | null;
  dealerId: string | null;
  termsTitle: string;
  termsContent: string;
  onTermsChange: (title: string, content: string) => void;
  readOnly?: boolean;
  /** Called after Reset loads template with (title, content) - parent can persist */
  onAfterReset?: (title: string, content: string) => void | Promise<void>;
  /** Hide Save as template / Set as default buttons (e.g. in Proposal) */
  hideSaveAsTemplate?: boolean;
  /** Hide Title and Content labels */
  hideLabels?: boolean;
  /** Hide Title input field (only show content textarea) */
  hideTitleInput?: boolean;
}

export default function DocumentTermsSection({
  docType,
  orgId,
  dealerId,
  termsTitle,
  termsContent,
  onTermsChange,
  readOnly = false,
  onAfterReset,
  hideSaveAsTemplate = false,
  hideLabels = false,
  hideTitleInput = false,
}: DocumentTermsSectionProps) {
  const [resetLoading, setResetLoading] = useState(false);
  const [saveAsTemplateLoading, setSaveAsTemplateLoading] = useState(false);
  const [lastSavedTemplateId, setLastSavedTemplateId] = useState<string | null>(null);
  const [setDefaultLoading, setSetDefaultLoading] = useState(false);

  const handleResetToDefault = async () => {
    if (!orgId || !dealerId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Cannot reset',
        message: 'Organization and dealer are required.',
      });
      return;
    }
    setResetLoading(true);
    try {
      const templateId = await resolveDefaultTermsTemplateId(orgId, dealerId, docType);
      if (!templateId) {
        useUIStore.getState().addNotification({
          type: 'info',
          title: 'No default',
          message: 'No default template is set for this dealer.',
        });
        return;
      }
      const template = await fetchTermsTemplateById(templateId);
      if (!template) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Template not found',
          message: 'Could not load the default template.',
        });
        return;
      }
      const title = template.title ?? 'Terms and Conditions';
      const content = template.content ?? '';
      onTermsChange(title, content);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Reset to default',
        message: 'Terms loaded from default template.',
      });
      await onAfterReset?.(title, content);
    } catch (e) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to reset.',
      });
    } finally {
      setResetLoading(false);
    }
  };

  const handleSaveAsTemplate = async () => {
    if (!orgId || !dealerId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Cannot save',
        message: 'Organization and dealer are required.',
      });
      return;
    }
    setSaveAsTemplateLoading(true);
    try {
      const { id, error } = await upsertTermsTemplate({
        organization_id: orgId,
        dealer_id: dealerId,
        doc_type: docType,
        title: termsTitle.trim() || 'Untitled Terms',
        content: termsContent,
        is_active: true,
      });
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: error });
        return;
      }
      setLastSavedTemplateId(id);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Saved as template',
        message: 'Template created. You can set it as default in Dealer settings.',
      });
    } finally {
      setSaveAsTemplateLoading(false);
    }
  };

  const handleSetAsDefault = async () => {
    if (!dealerId || !lastSavedTemplateId) return;
    setSetDefaultLoading(true);
    try {
      const { error } = await setDealerDefaultTermsTemplate(dealerId, docType, lastSavedTemplateId);
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: error });
      } else {
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Default set',
          message: 'This template is now the default for this dealer.',
        });
      }
    } finally {
      setSetDefaultLoading(false);
    }
  };

  return (
    <div className="flex-1 min-w-0 bg-white border border-gray-200 rounded-lg p-6">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">Terms & Conditions</h3>
      <div className="space-y-3">
        {!hideTitleInput && (
          <div>
            {!hideLabels && <Label className="text-xs">Title</Label>}
            <Input
              value={termsTitle}
              onChange={(e) => onTermsChange(e.target.value, termsContent)}
              disabled={readOnly}
              placeholder="Terms and Conditions"
              className={hideLabels ? '' : 'mt-1'}
            />
          </div>
        )}
        <div>
          {!hideLabels && <Label className="text-xs">Content</Label>}
          <textarea
            value={termsContent}
            onChange={(e) => onTermsChange(termsTitle, e.target.value)}
            disabled={readOnly}
            rows={6}
            className={`w-full border border-gray-200 rounded px-3 py-2 text-sm ${hideLabels ? '' : 'mt-1'}`}
            placeholder="Enter terms and conditions..."
          />
        </div>
        {!readOnly && (
          <div className="flex flex-wrap gap-2 pt-1">
            <button
              type="button"
              onClick={handleResetToDefault}
              disabled={resetLoading}
              className="text-sm px-3 py-1.5 border border-gray-200 rounded hover:bg-gray-50 disabled:opacity-50"
            >
              {resetLoading ? 'Loading…' : 'Reset to default template'}
            </button>
            {!hideSaveAsTemplate && (
              <>
                <button
                  type="button"
                  onClick={handleSaveAsTemplate}
                  disabled={saveAsTemplateLoading}
                  className="text-sm px-3 py-1.5 border border-gray-200 rounded hover:bg-gray-50 disabled:opacity-50"
                >
                  {saveAsTemplateLoading ? 'Saving…' : 'Save as template'}
                </button>
                {lastSavedTemplateId && (
                  <button
                    type="button"
                    onClick={handleSetAsDefault}
                    disabled={setDefaultLoading}
                    className="text-sm px-3 py-1.5 bg-gray-800 text-white rounded hover:bg-gray-700 disabled:opacity-50"
                  >
                    {setDefaultLoading ? 'Saving…' : 'Set as default'}
                  </button>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
