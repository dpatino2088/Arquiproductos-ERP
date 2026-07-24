import React, { useEffect, useState } from 'react';
import { Copy, GitBranch, X } from 'lucide-react';
import Button from '../ui/Button';

export type DuplicateQuoteMode = 'copy' | 'version';

export interface DuplicateQuoteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (mode: DuplicateQuoteMode, recalculate: boolean) => Promise<void> | void;
  sourceQuoteNo?: string | null;
  /** When true, the 'version' radio is disabled (e.g. quote already converted to SO). */
  disableVersion?: boolean;
  /** Optional reason to show under disabled 'version' radio. */
  versionDisabledReason?: string | null;
  isLoading?: boolean;
}

const DuplicateQuoteModal: React.FC<DuplicateQuoteModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  sourceQuoteNo,
  disableVersion = false,
  versionDisabledReason,
  isLoading = false,
}) => {
  const [mode, setMode] = useState<DuplicateQuoteMode>(disableVersion ? 'copy' : 'version');
  const [recalculate, setRecalculate] = useState(true);

  useEffect(() => {
    if (!isOpen) return;
    setMode(disableVersion ? 'copy' : 'version');
    setRecalculate(true);
  }, [isOpen, disableVersion]);

  if (!isOpen) return null;

  const handleBackdrop = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget && !isLoading) onClose();
  };

  const handleConfirm = async () => {
    await onConfirm(mode, recalculate);
  };

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
              <h3 className="text-lg font-semibold text-gray-900">Duplicate quote</h3>
              {sourceQuoteNo && (
                <p className="text-xs text-gray-500 mt-0.5">Source: {sourceQuoteNo}</p>
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
          <p className="text-sm text-gray-600">Choose how to duplicate this Quote:</p>

          <div className="space-y-3">
            <label
              className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                mode === 'version'
                  ? 'border-blue-500 bg-blue-50'
                  : disableVersion
                    ? 'border-gray-200 bg-gray-50 cursor-not-allowed opacity-60'
                    : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <input
                type="radio"
                name="duplicate-mode"
                value="version"
                disabled={disableVersion || isLoading}
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
                  Creates a new version linked to the original quote (e.g. QT-00123_V2). The
                  previous version is marked as <strong>superseded</strong> and versions are
                  grouped in the list. Best for iterating on a project.
                </p>
                {disableVersion && versionDisabledReason && (
                  <p className="text-xs text-amber-700 mt-1">{versionDisabledReason}</p>
                )}
              </div>
            </label>

            <label
              className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${
                mode === 'copy' ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <input
                type="radio"
                name="duplicate-mode"
                value="copy"
                checked={mode === 'copy'}
                disabled={isLoading}
                onChange={() => setMode('copy')}
                className="mt-1"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <Copy className="w-4 h-4 text-gray-600" />
                  <span className="font-medium text-gray-900">New Quote</span>
                  <span className="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded">
                    QT-XXXXX
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Creates a completely new quote (with its own consecutive number) with no link
                  to the original. Useful for another customer or a new project.
                </p>
              </div>
            </label>
          </div>

          <div className="border-t border-gray-100 pt-4">
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={recalculate}
                disabled={isLoading}
                onChange={(e) => setRecalculate(e.target.checked)}
                className="mt-1"
              />
              <div className="flex-1">
                <span className="text-sm font-medium text-gray-900">
                  Recalculate prices with the current catalog
                </span>
                <p className="text-xs text-gray-500 mt-0.5">
                  Duplicated lines will be marked as <em>stale</em> so the next save picks up
                  current costs and MSRP. If unchecked, snapshots stay identical to the original.
                </p>
              </div>
            </label>
          </div>
        </div>

        <div className="flex items-center justify-end gap-3 p-5 border-t border-gray-200 bg-gray-50">
          <Button variant="outline" onClick={onClose} disabled={isLoading} className="min-w-[100px]">
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={handleConfirm}
            disabled={isLoading}
            loading={isLoading}
            className="min-w-[140px]"
          >
            {mode === 'version' ? 'Create version' : 'Duplicate'}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default DuplicateQuoteModal;
