import { useState, useCallback, useRef } from 'react';

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
  
  const resolveRef = useRef<((value: boolean) => void) | null>(null);

  const showConfirm = useCallback(
    (options: ConfirmDialogOptions): Promise<boolean> => {
      return new Promise((resolve) => {
        resolveRef.current = resolve;
        setDialogState({
          isOpen: true,
          title: options.title,
          message: options.message,
          confirmText: options.confirmText || 'Confirmar',
          cancelText: options.cancelText || 'Cancelar',
          variant: options.variant || 'danger',
          onConfirm: () => {
            if (resolveRef.current) {
              resolveRef.current(true);
              resolveRef.current = null;
            }
            setDialogState((prev) => ({ ...prev, isOpen: false, onConfirm: null }));
          },
          isLoading: false,
        });
      });
    },
    []
  );

  const closeDialog = useCallback(() => {
    if (resolveRef.current) {
      resolveRef.current(false);
      resolveRef.current = null;
    }
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















