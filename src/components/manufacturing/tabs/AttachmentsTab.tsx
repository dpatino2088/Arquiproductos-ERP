import { useState, useEffect, useRef } from 'react';
import { Upload, Trash2, Download, FileText } from 'lucide-react';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { useAuth } from '../../../hooks/useAuth';
import { useUIStore } from '../../../stores/ui-store';

const STORAGE_BUCKET = 'mo-attachments';

export interface MOAttachment {
  id: string;
  manufacturing_order_id: string;
  organization_id: string;
  file_name: string;
  file_path: string;
  file_size: number | null;
  content_type: string | null;
  uploaded_by: string | null;
  created_at: string;
}

interface AttachmentsTabProps {
  moId: string;
  organizationId: string;
}

export default function AttachmentsTab({ moId, organizationId }: AttachmentsTabProps) {
  const [attachments, setAttachments] = useState<MOAttachment[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const orgId = activeOrganizationId ?? organizationId;

  useEffect(() => {
    if (!moId) return;
    const fetchAttachments = async () => {
      setLoading(true);
      const { data, error } = await supabase
        .from('manufacturing_order_attachments')
        .select('id, manufacturing_order_id, organization_id, file_name, file_path, file_size, content_type, uploaded_by, created_at')
        .eq('manufacturing_order_id', moId)
        .order('created_at', { ascending: false });
      if (error) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error loading attachments', message: error.message });
        setAttachments([]);
      } else {
        setAttachments((data ?? []) as MOAttachment[]);
      }
      setLoading(false);
    };
    fetchAttachments();
  }, [moId]);

  const formatFileSize = (bytes: number | null): string => {
    if (bytes == null || bytes === 0) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files?.length || !orgId || !moId || !user) return;
    setUploading(true);
    const added: MOAttachment[] = [];
    try {
      for (const file of Array.from(files)) {
        const ext = file.name.split('.').pop() || '';
        const uniqueName = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;
        const filePath = `${orgId}/mo/${moId}/${uniqueName}`;
        const { error: uploadError } = await supabase.storage
          .from(STORAGE_BUCKET)
          .upload(filePath, file, { cacheControl: '3600', upsert: false });
        if (uploadError) throw uploadError;
        const { data: row, error: insertError } = await supabase
          .from('manufacturing_order_attachments')
          .insert({
            manufacturing_order_id: moId,
            organization_id: orgId,
            file_name: file.name,
            file_path: filePath,
            file_size: file.size,
            content_type: file.type || null,
            uploaded_by: user.id,
          })
          .select('id, manufacturing_order_id, organization_id, file_name, file_path, file_size, content_type, uploaded_by, created_at')
          .single();
        if (insertError) throw insertError;
        added.push(row as MOAttachment);
      }
      setAttachments((prev) => [...added, ...prev]);
      useUIStore.getState().addNotification({ type: 'success', title: 'Upload complete', message: `${added.length} file(s) uploaded.` });
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Upload failed', message: err.message || 'Failed to upload files.' });
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  };

  const handleDelete = async (att: MOAttachment) => {
    try {
      await supabase.storage.from(STORAGE_BUCKET).remove([att.file_path]);
      const { error } = await supabase.from('manufacturing_order_attachments').delete().eq('id', att.id);
      if (error) throw error;
      setAttachments((prev) => prev.filter((a) => a.id !== att.id));
      useUIStore.getState().addNotification({ type: 'success', title: 'Deleted', message: 'Attachment removed.' });
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Delete failed', message: err.message || 'Failed to delete.' });
    }
  };

  const getDownloadUrl = (filePath: string): string => {
    const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);
    return data.publicUrl;
  };

  if (loading) {
    return (
      <div>
        <div className="animate-pulse space-y-3">
          <div className="h-8 bg-gray-200 rounded w-1/3" />
          <div className="h-24 bg-gray-100 rounded" />
          <div className="h-24 bg-gray-100 rounded" />
        </div>
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
            disabled={uploading}
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-gray-800 rounded-lg hover:bg-gray-700 disabled:opacity-50"
          >
            <Upload className="w-4 h-4" />
            {uploading ? 'Uploading...' : 'Upload'}
          </button>
        </div>
      </div>

      {attachments.length === 0 ? (
        <div className="rounded-lg border border-dashed border-gray-300 bg-gray-50 p-8 text-center text-gray-500">
          No attachments yet. Upload files to attach them to this manufacturing order.
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
                      href={getDownloadUrl(att.file_path)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-2 text-primary hover:underline"
                    >
                      <FileText className="w-4 h-4 text-gray-400" />
                      {att.file_name}
                    </a>
                  </td>
                  <td className="px-4 py-3 text-right text-gray-600 tabular-nums">{formatFileSize(att.file_size)}</td>
                  <td className="px-4 py-3 text-gray-600">{att.created_at ? new Date(att.created_at).toLocaleString() : '—'}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1">
                      <a
                        href={getDownloadUrl(att.file_path)}
                        download={att.file_name}
                        className="p-1.5 text-gray-500 hover:text-gray-700 rounded"
                        title="Download"
                      >
                        <Download className="w-4 h-4" />
                      </a>
                      <button
                        type="button"
                        onClick={() => handleDelete(att)}
                        className="p-1.5 text-gray-500 hover:text-red-600 rounded"
                        title="Remove"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
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
