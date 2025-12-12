import React from 'react';
import { X, Copy, Check } from 'lucide-react';
import { useState } from 'react';

interface PasswordModalProps {
  isOpen: boolean;
  onClose: () => void;
  email: string;
  password: string;
  organizationName: string;
}

export default function PasswordModal({
  isOpen,
  onClose,
  email,
  password,
  organizationName,
}: PasswordModalProps) {
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const handleCopyPassword = async () => {
    try {
      await navigator.clipboard.writeText(password);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy password:', err);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600 transition-colors"
          aria-label="Close"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Header */}
        <div className="mb-4">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">
            Access Created Successfully
          </h2>
          <p className="text-sm text-gray-600">
            A user account has been created for <strong>{organizationName}</strong>.
          </p>
        </div>

        {/* Content */}
        <div className="space-y-4 mb-6">
          <div>
            <label className="text-xs font-medium text-gray-700 block mb-1">
              Email
            </label>
            <div className="p-3 bg-gray-50 border border-gray-200 rounded text-sm font-mono text-gray-900">
              {email}
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-gray-700 block mb-1">
              Temporary Password
            </label>
            <div className="flex items-center gap-2">
              <div className="flex-1 p-3 bg-yellow-50 border border-yellow-200 rounded text-sm font-mono text-gray-900">
                {password}
              </div>
              <button
                onClick={handleCopyPassword}
                className="p-2 border border-gray-300 rounded hover:bg-gray-50 transition-colors"
                title="Copy password"
              >
                {copied ? (
                  <Check className="w-5 h-5 text-green-600" />
                ) : (
                  <Copy className="w-5 h-5 text-gray-600" />
                )}
              </button>
            </div>
          </div>

          <div className="p-3 bg-blue-50 border border-blue-200 rounded">
            <p className="text-xs text-blue-800">
              <strong>Important:</strong> Please save this password securely. 
              The user should change it after their first login.
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm font-medium"
          >
            I've Saved This Information
          </button>
        </div>
      </div>
    </div>
  );
}

