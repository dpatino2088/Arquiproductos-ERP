import React from 'react';
import { AlertTriangle, X } from 'lucide-react';
import Button from './Button';

export interface ConfirmDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  variant?: 'danger' | 'warning' | 'info';
  isLoading?: boolean;
}

const ConfirmDialog: React.FC<ConfirmDialogProps> = ({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirmar',
  cancelText = 'Cancelar',
  variant = 'danger',
  isLoading = false,
}) => {
  if (!isOpen) return null;

  const handleConfirm = () => {
    onConfirm();
  };

  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget && !isLoading) {
      onClose();
    }
  };

  const variantStyles = {
    danger: {
      iconBg: 'bg-red-100',
      iconColor: 'text-red-600',
      confirmButton: 'danger' as const,
    },
    warning: {
      iconBg: 'bg-yellow-100',
      iconColor: 'text-yellow-600',
      confirmButton: 'primary' as const,
    },
    info: {
      iconBg: 'bg-blue-100',
      iconColor: 'text-blue-600',
      confirmButton: 'primary' as const,
    },
  };

  const styles = variantStyles[variant];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4"
      onClick={handleBackdropClick}
    >
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full transform transition-all">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className={`${styles.iconBg} p-2 rounded-full`}>
              <AlertTriangle className={`w-5 h-5 ${styles.iconColor}`} />
            </div>
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
          </div>
          {!isLoading && (
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 transition-colors"
              aria-label="Cerrar"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>

        {/* Body */}
        <div className="p-6">
          <p className="text-sm text-gray-600 leading-relaxed">{message}</p>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200 bg-gray-50">
          <Button
            variant="outline"
            onClick={onClose}
            disabled={isLoading}
            className="min-w-[100px]"
          >
            {cancelText}
          </Button>
          <Button
            variant={styles.confirmButton}
            onClick={handleConfirm}
            disabled={isLoading}
            loading={isLoading}
            className="min-w-[100px]"
          >
            {confirmText}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmDialog;

