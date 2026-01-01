import { useState, useRef, useEffect } from 'react';
import { Upload, X, FileText, Download, Trash2 } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';

interface FileItem {
  id: string;
  name: string;
  url: string;
  size: number;
  type: string;
}

interface FileUploadProps {
  currentFiles?: FileItem[];
  onFilesChanged: (files: FileItem[]) => void;
  disabled?: boolean;
  acceptedTypes?: string[];
  maxFileSize?: number; // in bytes
  maxFiles?: number;
}

export default function FileUpload({ 
  currentFiles = [], 
  onFilesChanged, 
  disabled = false,
  acceptedTypes = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'image/*'],
  maxFileSize = 10 * 1024 * 1024, // 10MB default
  maxFiles = 10
}: FileUploadProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { activeOrganizationId } = useOrganizationContext();
  const [files, setFiles] = useState<FileItem[]>(currentFiles);

  // Update files when currentFiles prop changes
  useEffect(() => {
    setFiles(currentFiles);
  }, [currentFiles]);

  const formatFileSize = (bytes: number): string => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  const getFileIcon = (type: string) => {
    if (type.startsWith('image/')) return '🖼️';
    if (type === 'application/pdf') return '📄';
    if (type.includes('word') || type.includes('document')) return '📝';
    return '📎';
  };

  const handleFileSelect = async (fileList: FileList) => {
    const filesArray = Array.from(fileList);

    // Check max files limit
    if (files.length + filesArray.length > maxFiles) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Too many files',
        message: `Maximum ${maxFiles} files allowed.`,
      });
      return;
    }

    // Validate each file
    for (const file of filesArray) {
      // Check file type
      if (!acceptedTypes.some(type => {
        if (type.endsWith('/*')) {
          return file.type.startsWith(type.slice(0, -1));
        }
        return file.type === type;
      })) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Invalid file type',
          message: `${file.name} is not an allowed file type.`,
        });
        return;
      }

      // Check file size
      if (file.size > maxFileSize) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'File too large',
          message: `${file.name} exceeds the maximum file size of ${formatFileSize(maxFileSize)}.`,
        });
        return;
      }
    }

    setIsUploading(true);

    try {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      const uploadedFiles: FileItem[] = [];

      for (const file of filesArray) {
        // Generate unique filename
        const fileExt = file.name.split('.').pop();
        const fileName = `${activeOrganizationId}/attachments/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;

        // Upload to Supabase Storage
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('catalog-images')
          .upload(fileName, file, {
            cacheControl: '3600',
            upsert: false,
          });

        if (uploadError) {
          throw uploadError;
        }

        // Get public URL
        const { data: urlData } = supabase.storage
          .from('catalog-images')
          .getPublicUrl(fileName);

        if (urlData?.publicUrl) {
          uploadedFiles.push({
            id: fileName,
            name: file.name,
            url: urlData.publicUrl,
            size: file.size,
            type: file.type,
          });
        }
      }

      const newFiles = [...files, ...uploadedFiles];
      setFiles(newFiles);
      onFilesChanged(newFiles);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Files uploaded',
        message: `${uploadedFiles.length} file(s) uploaded successfully`,
      });
    } catch (error: any) {
      console.error('Error uploading files:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Upload failed',
        message: error.message || 'Failed to upload files. Please try again.',
      });
    } finally {
      setIsUploading(false);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const fileList = e.target.files;
    if (fileList && fileList.length > 0) {
      handleFileSelect(fileList);
    }
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
    const fileList = e.dataTransfer.files;
    if (fileList.length > 0) {
      handleFileSelect(fileList);
    }
  };

  const handleDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleRemove = async (fileId: string) => {
    try {
      // Delete from storage
      const { error } = await supabase.storage
        .from('catalog-images')
        .remove([fileId]);

      if (error) {
        console.error('Error deleting file:', error);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Delete failed',
          message: 'Failed to delete file. Please try again.',
        });
        return;
      }

      const newFiles = files.filter(f => f.id !== fileId);
      setFiles(newFiles);
      onFilesChanged(newFiles);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'File deleted',
        message: 'File has been deleted successfully',
      });
    } catch (error) {
      console.error('Error deleting file:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Delete failed',
        message: 'Failed to delete file. Please try again.',
      });
    }
  };

  return (
    <div className="space-y-4">
      <label className="text-xs font-medium text-gray-700">Technical Documents & Materials</label>
      
      {/* File List */}
      {files.length > 0 && (
        <div className="space-y-2">
          {files.map((file) => (
            <div
              key={file.id}
              className="flex items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <span className="text-2xl">{getFileIcon(file.type)}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium text-gray-900 truncate">{file.name}</p>
                  <p className="text-xs text-gray-500">{formatFileSize(file.size)}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <a
                  href={file.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="p-1.5 text-gray-600 hover:text-gray-900 hover:bg-gray-200 rounded transition-colors"
                  title="Download"
                >
                  <Download className="w-4 h-4" />
                </a>
                {!disabled && (
                  <button
                    type="button"
                    onClick={() => handleRemove(file.id)}
                    className="p-1.5 text-red-600 hover:text-red-700 hover:bg-red-50 rounded transition-colors"
                    title="Remove"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Upload Area */}
      {files.length < maxFiles && (
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          className={`
            border-2 border-dashed rounded-lg p-6 text-center transition-colors
            ${isDragging ? 'border-primary bg-primary/5' : 'border-gray-300'}
            ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer hover:border-gray-400'}
          `}
          onClick={() => !disabled && !isUploading && fileInputRef.current?.click()}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept={acceptedTypes.join(',')}
            onChange={handleFileInputChange}
            multiple
            className="hidden"
            disabled={disabled || isUploading}
          />
          <div className="flex flex-col items-center gap-2">
            {isUploading ? (
              <>
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
                <p className="text-xs text-gray-600">Uploading...</p>
              </>
            ) : (
              <>
                <Upload className="w-8 h-8 text-gray-400" />
                <div>
                  <p className="text-xs text-gray-600">
                    Click to upload or drag and drop
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    PDF, DOC, DOCX, Images up to {formatFileSize(maxFileSize)}
                  </p>
                  <p className="text-xs text-gray-400 mt-1">
                    {files.length}/{maxFiles} files uploaded
                  </p>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {files.length >= maxFiles && (
        <p className="text-xs text-gray-500 text-center">
          Maximum {maxFiles} files reached. Remove files to upload more.
        </p>
      )}
    </div>
  );
}

