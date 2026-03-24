import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase/client';
import { useAuth } from './useAuth';

export interface AppNotification {
  id: string;
  event_code: string;
  module: string;
  entity_type: string;
  entity_id: string;
  title: string;
  message: string;
  payload: Record<string, unknown> | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

export function useNotifications(limit: number = 30) {
  const { user, isAuthenticated } = useAuth();
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchNotifications = useCallback(async () => {
    if (!isAuthenticated || !user?.id) {
      setNotifications([]);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const { data, error: queryErr } = await supabase
        .from('UserNotifications')
        .select('id, event_code, module, entity_type, entity_id, title, message, payload, is_read, read_at, created_at')
        .order('created_at', { ascending: false })
        .limit(limit);

      if (queryErr) throw queryErr;
      setNotifications((data ?? []) as AppNotification[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load notifications');
      setNotifications([]);
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated, user?.id, limit]);

  const markAsRead = useCallback(
    async (notificationId: string) => {
      const current = notifications.find((n) => n.id === notificationId);
      if (!current || current.is_read) return;

      const nowIso = new Date().toISOString();
      setNotifications((prev) =>
        prev.map((n) => (n.id === notificationId ? { ...n, is_read: true, read_at: nowIso } : n))
      );

      const { error: updateErr } = await supabase
        .from('UserNotifications')
        .update({ is_read: true, read_at: nowIso })
        .eq('id', notificationId);

      if (updateErr) {
        // Restore from DB state if update fails.
        fetchNotifications();
      }
    },
    [notifications, fetchNotifications]
  );

  const markAllAsRead = useCallback(async () => {
    if (!user?.id) return;

    const nowIso = new Date().toISOString();
    setNotifications((prev) => prev.map((n) => (n.is_read ? n : { ...n, is_read: true, read_at: nowIso })));

    const { error: updateErr } = await supabase
      .from('UserNotifications')
      .update({ is_read: true, read_at: nowIso })
      .eq('recipient_auth_user_id', user.id)
      .eq('is_read', false);

    if (updateErr) {
      fetchNotifications();
    }
  }, [user?.id, fetchNotifications]);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  useEffect(() => {
    if (!isAuthenticated || !user?.id) return;

    const channel = supabase
      .channel(`notifications-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'UserNotifications',
          filter: `recipient_auth_user_id=eq.${user.id}`,
        },
        (payload: any) => {
          const row = payload.new as AppNotification;
          setNotifications((prev) => {
            if (prev.some((n) => n.id === row.id)) return prev;
            return [row, ...prev].slice(0, limit);
          });
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'UserNotifications',
          filter: `recipient_auth_user_id=eq.${user.id}`,
        },
        (payload: any) => {
          const row = payload.new as AppNotification;
          setNotifications((prev) => prev.map((n) => (n.id === row.id ? { ...n, ...row } : n)));
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [isAuthenticated, user?.id, limit]);

  const unreadCount = useMemo(() => notifications.filter((n) => !n.is_read).length, [notifications]);

  return {
    notifications,
    unreadCount,
    loading,
    error,
    fetchNotifications,
    markAsRead,
    markAllAsRead,
  };
}
