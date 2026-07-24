import React, { useEffect, useState } from 'react';
import { Copy, GitBranch, FilePlus, X } from 'lucide-react';
import Button from '../ui/Button';

/** Mirrors Quote duplicate modes, plus optional rebuild-from-quote for linked proposals. */
export type DuplicateProposalMode = 'version' | 'copy' | 'from_quote';

export interface DuplicateProposalModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (mode: DuplicateProposalMode) => Promise<void> | void;
  sourceProposalNo?: string | null;
  sourceQuoteNo?: string | null;
  /** When true, proposal has a parent Quote — show "New from Quote". */
  hasQuote?: boolean;
  isLoading?: boolean;
}

const DuplicateProposalModal: React.FC<DuplicateProposalModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  sourceProposalNo,
  sourceQuoteNo,
  hasQuote = false,
  isLoading = false,
}) => {
  const [mode, setMode] = useState<DuplicateProposalMode>('version');

  useEffect(() => {
    if (!isOpen) return;
    setMode('version');
  }, [isOpen]);

  if (!isOpen) return null;

  const handleBackdrop = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget && !isLoading) onClose();
  };

  const baseNo = sourceProposalNo
    ? String(sourceProposalNo).replace(/_V\d+$/i, '')
    : 'PR-XXXXX';

  return (
    <div
      className="fixed inset-0 z-[120] flex items-center justify-center bg-black bg-opacity-50 p-4"
      onClick={handleBackdrop}
    >
      <div
        className="bg-white rounded-lg shadow-xl max-w-lg w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between p-5 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="bg-blue-100 p-2 rounded-full">
              <Copy className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Duplicate proposal</h3>
              {sourceProposalNo && (
                <p className="text-xs text-gray-500 mt-0.5">Source: {sourceProposalNo}</p>
              )}
            </div>
          </div>
          {!isLoading && (
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 transition-colors"
              aria-label="Close"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>

        <div className="p-5 space-y-4">
          <p className="text-sm text-gray-600">
            Choose how to duplicate this proposal (same rules as Quotes):
          </p>

          <div className="space-y-3">
            <label
              className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                mode === 'version'
                  ? 'border-blue-500 bg-blue-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <input
                type="radio"
                name="duplicate-proposal-mode"
                value="version"
                disabled={isLoading}
                checked={mode === 'version'}
                onChange={() => setMode('version')}
                className="mt-1"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <GitBranch className="w-4 h-4 text-blue-600" />
                  <span className="font-medium text-gray-900">New version</span>
                  <span className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded">
                    _V&lt;n&gt;
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Copies everything (lines, adjustments, add-ons, discounts) as {baseNo}_V2…
                  The current one is archived as history. Best for iterating on the same project.
                </p>
              </div>
            </label>

            <label
              className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                mode === 'copy'
                  ? 'border-blue-500 bg-blue-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <input
                type="radio"
                name="duplicate-proposal-mode"
                value="copy"
                disabled={isLoading}
                checked={mode === 'copy'}
                onChange={() => setMode('copy')}
                className="mt-1"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <Copy className="w-4 h-4 text-gray-600" />
                  <span className="font-medium text-gray-900">New proposal</span>
                  <span className="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded">
                    PR-XXXXX
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Full clone with a new number (like “New Quote”). Includes all lines and
                  adjustments. The original is not archived — useful for another project or
                  customer. Also works for standalone proposals.
                </p>
              </div>
            </label>

            {hasQuote && (
              <label
                className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                  mode === 'from_quote'
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <input
                  type="radio"
                  name="duplicate-proposal-mode"
                  value="from_quote"
                  disabled={isLoading}
                  checked={mode === 'from_quote'}
                  onChange={() => setMode('from_quote')}
                  className="mt-1"
                />
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <FilePlus className="w-4 h-4 text-gray-600" />
                    <span className="font-medium text-gray-900">New from Quote</span>
                    <span className="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded">
                      PR-XXXXX
                    </span>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    New number, rebuilt from the Quote
                    {sourceQuoteNo ? ` (${sourceQuoteNo})` : ''} — without copying adjustments
                    or custom lines from this version. The current one is not archived.
                  </p>
                </div>
              </label>
            )}
          </div>
        </div>

        <div className="flex items-center justify-end gap-3 p-5 border-t border-gray-200 bg-gray-50">
          <Button variant="outline" onClick={onClose} disabled={isLoading} className="min-w-[100px]">
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={() => onConfirm(mode)}
            disabled={isLoading}
            loading={isLoading}
            className="min-w-[140px]"
          >
            {mode === 'version' ? 'Create version' : 'Create new'}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default DuplicateProposalModal;
