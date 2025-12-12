import { useEffect } from 'react';
import { useUIStore } from '../../stores/ui-store';
import { CheckCircle, AlertCircle, X } from 'lucide-react';

export default function Toast() {
  const { notifications, removeNotification } = useUIStore();

  // Get the most recent notification (for toast display)
  const latestNotification = notifications.length > 0 ? notifications[0] : null;

  useEffect(() => {
    if (latestNotification && latestNotification.type === 'success') {
      // Auto-remove after 5 seconds (already handled in store, but ensure cleanup)
      const timer = setTimeout(() => {
        removeNotification(latestNotification.id);
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [latestNotification, removeNotification]);

  if (!latestNotification) return null;

  const isSuccess = latestNotification.type === 'success';
  const isError = latestNotification.type === 'error';

  return (
    <div
      className={`fixed top-4 right-4 z-50 min-w-[300px] max-w-md p-4 rounded-lg border-2 shadow-lg flex items-start gap-3 animate-in slide-in-from-top-5 ${
        isSuccess
          ? 'bg-green-50 border-green-300 text-green-800'
          : isError
          ? 'bg-red-50 border-red-300 text-red-800'
          : 'bg-blue-50 border-blue-300 text-blue-800'
      }`}
      role="alert"
    >
      {isSuccess ? (
        <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
      ) : isError ? (
        <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
      ) : null}
      <div className="flex-1">
        <p className="font-semibold text-sm mb-1">{latestNotification.title}</p>
        {latestNotification.message && (
          <p className="text-xs opacity-90">{latestNotification.message}</p>
        )}
      </div>
      <button
        onClick={() => removeNotification(latestNotification.id)}
        className={`flex-shrink-0 ${
          isSuccess
            ? 'text-green-600 hover:text-green-800'
            : isError
            ? 'text-red-600 hover:text-red-800'
            : 'text-blue-600 hover:text-blue-800'
        }`}
        aria-label="Close notification"
      >
        <X className="w-4 h-4" />
      </button>
    </div>
  );
}

