import { useState, useCallback } from 'react';

export interface ConfirmDialogOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  variant?: 'danger' | 'warning' | 'info';
}

export interface ConfirmDialogState extends ConfirmDialogOptions {
  isOpen: boolean;
  onConfirm: (() => void) | null;
  isLoading?: boolean;
}

export function useConfirmDialog() {
  const [dialogState, setDialogState] = useState<ConfirmDialogState>({
    isOpen: false,
    title: '',
    message: '',
    onConfirm: null,
    isLoading: false,
  });

  const showConfirm = useCallback(
    (options: ConfirmDialogOptions): Promise<boolean> => {
      return new Promise((resolve) => {
        setDialogState({
          isOpen: true,
          title: options.title,
          message: options.message,
          confirmText: options.confirmText || 'Confirmar',
          cancelText: options.cancelText || 'Cancelar',
          variant: options.variant || 'danger',
          onConfirm: () => {
            resolve(true);
            setDialogState((prev) => ({ ...prev, isOpen: false, onConfirm: null }));
          },
          isLoading: false,
        });
      });
    },
    []
  );

  const closeDialog = useCallback(() => {
    setDialogState((prev) => ({
      ...prev,
      isOpen: false,
      onConfirm: null,
      isLoading: false,
    }));
  }, []);

  const setLoading = useCallback((loading: boolean) => {
    setDialogState((prev) => ({ ...prev, isLoading: loading }));
  }, []);

  const handleConfirm = useCallback(() => {
    if (dialogState.onConfirm) {
      dialogState.onConfirm();
    }
  }, [dialogState.onConfirm]);

  return {
    dialogState,
    showConfirm,
    closeDialog,
    setLoading,
    handleConfirm,
  };
}





