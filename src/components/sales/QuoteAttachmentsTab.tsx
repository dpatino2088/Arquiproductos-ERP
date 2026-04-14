import { useState, useEffect, useRef } from 'react';
import { formatDateTime } from '../../lib/utils';
import { Upload, Trash2, Download, FileText } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';

const BUCKET = 'quote-attachments';

interface QuoteAttachment {
  id: string;
  quote_id: string;
  organization_id: string;
  file_name: string;
  file_path: string;
  file_size: number | null;
  content_type: string | null;
  uploaded_by: string | null;
  created_at: string;
}

interface Props {
  quoteId: string;
  organizationId: string;
  canEdit?: boolean;
}

export default function QuoteAttachmentsTab({ quoteId, organizationId, canEdit = true }: Props) {
  const [attachments, setAttachments] = useState<QuoteAttachment[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const { user } = useAuth();
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!quoteId) return;
    (async () => {
      setLoading(true);
      const { data, error } = await supabase
        .from('quote_attachments')
        .select('id, quote_id, organization_id, file_name, file_path, file_size, content_type, uploaded_by, created_at')
        .eq('quote_id', quoteId)
        .order('created_at', { ascending: false });
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: error.message });
        setAttachments([]);
      } else {
        setAttachments((data ?? []) as QuoteAttachment[]);
      }
      setLoading(false);
    })();
  }, [quoteId]);

  const fmtSize = (bytes: number | null): string => {
    if (bytes == null || bytes === 0) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!canEdit) return;
    const files = e.target.files;
    if (!files?.length || !quoteId || !user) return;
    setUploading(true);
    const added: QuoteAttachment[] = [];
    try {
      for (const file of Array.from(files)) {
        const ext = file.name.split('.').pop() || '';
        const uniqueName = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;
        const filePath = `${organizationId}/quotes/${quoteId}/${uniqueName}`;
        const { error: upErr } = await supabase.storage
          .from(BUCKET)
          .upload(filePath, file, { cacheControl: '3600', upsert: false });
        if (upErr) throw upErr;
        const { data: row, error: insErr } = await supabase
          .from('quote_attachments')
          .insert({
            quote_id: quoteId,
            organization_id: organizationId,
            file_name: file.name,
            file_path: filePath,
            file_size: file.size,
            content_type: file.type || null,
            uploaded_by: user.id,
          })
          .select('id, quote_id, organization_id, file_name, file_path, file_size, content_type, uploaded_by, created_at')
          .single();
        if (insErr) throw insErr;
        added.push(row as QuoteAttachment);
      }
      setAttachments((prev) => [...added, ...prev]);
      useUIStore.getState().addNotification({ type: 'success', title: 'Upload complete', message: `${added.length} file(s) uploaded.` });
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Upload failed', message: err.message || 'Failed to upload.' });
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const handleDelete = async (att: QuoteAttachment) => {
    if (!canEdit) return;
    try {
      await supabase.storage.from(BUCKET).remove([att.file_path]);
      const { error } = await supabase.from('quote_attachments').delete().eq('id', att.id);
      if (error) throw error;
      setAttachments((prev) => prev.filter((a) => a.id !== att.id));
      useUIStore.getState().addNotification({ type: 'success', title: 'Deleted', message: 'Attachment removed.' });
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Delete failed', message: err.message || 'Failed to delete.' });
    }
  };

  const publicUrl = (path: string) =>
    supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;

  if (loading) {
    return (
      <div className="animate-pulse space-y-3">
        <div className="h-8 bg-gray-200 rounded w-1/3" />
        <div className="h-24 bg-gray-100 rounded" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">Attachments</h3>
        <div className="flex items-center gap-2">
          <input
            type="file"
            multiple
            className="hidden"
            ref={fileInputRef}
            onChange={handleUpload}
            disabled={!canEdit || uploading}
          />
          {canEdit && (
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white rounded-lg hover:opacity-90 disabled:opacity-50"
              style={{ backgroundColor: 'var(--primary-brand-hex, #1f2937)' }}
            >
              <Upload className="w-4 h-4" />
              {uploading ? 'Uploading...' : 'Upload'}
            </button>
          )}
        </div>
      </div>

      {attachments.length === 0 ? (
        <div className="rounded-lg border border-dashed border-gray-300 bg-gray-50 p-8 text-center text-gray-500">
          No attachments yet. Upload files such as measurement forms, photos, or documents.
        </div>
      ) : (
        <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">File</th>
                <th className="px-4 py-3 text-right font-medium text-gray-700">Size</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Uploaded</th>
                <th className="px-4 py-3 w-24"></th>
              </tr>
            </thead>
            <tbody>
              {attachments.map((att) => (
                <tr key={att.id} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <a
                      href={publicUrl(att.file_path)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-primary hover:underline"
                    >
                      <FileText className="w-4 h-4 text-gray-400" />
                      {att.file_name}
                    </a>
                  </td>
                  <td className="px-4 py-3 text-right text-gray-600 tabular-nums">{fmtSize(att.file_size)}</td>
                  <td className="px-4 py-3 text-gray-600">{att.created_at ? formatDateTime(att.created_at) : '—'}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1">
                      <a
                        href={publicUrl(att.file_path)}
                        download={att.file_name}
                        className="p-1.5 text-gray-500 hover:text-gray-700 rounded"
                        title="Download"
                      >
                        <Download className="w-4 h-4" />
                      </a>
                      {canEdit && (
                        <button
                          type="button"
                          onClick={() => handleDelete(att)}
                          className="p-1.5 text-gray-500 hover:text-red-600 rounded"
                          title="Remove"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
