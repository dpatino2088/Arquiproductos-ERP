import { useState, useRef, useEffect } from 'react';
import { Upload, X, Image as ImageIcon } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useUIStore } from '../../stores/ui-store';

interface ImageUploadProps {
  currentImageUrl?: string | null;
  onImageUploaded: (url: string | null) => void;
  disabled?: boolean;
  /** Storage bucket (default: catalog-images) */
  bucket?: string;
  /** Custom storage path. If not provided, uses {organizationId}/{timestamp}-{random}.{ext} */
  uploadPath?: (file: File) => string;
  /** Label above the drop zone (default: Item Image) */
  label?: string;
}

export default function ImageUpload({
  currentImageUrl,
  onImageUploaded,
  disabled,
  bucket = 'catalog-images',
  uploadPath,
  label = 'Item Image',
}: ImageUploadProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [preview, setPreview] = useState<string | null>(currentImageUrl || null);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const handleFileSelect = async (file: File) => {
    // Validate file type
    if (!file.type.startsWith('image/')) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Invalid file type',
        message: 'Please upload an image file (JPG, PNG, GIF, etc.)',
      });
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'File too large',
        message: 'Image must be less than 5MB',
      });
      return;
    }

    setIsUploading(true);

    try {
      const fileName = uploadPath
        ? uploadPath(file)
        : (() => {
            if (!activeOrganizationId) throw new Error('No organization selected');
            const fileExt = file.name.split('.').pop();
            return `${activeOrganizationId}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;
          })();

      // Create preview
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreview(reader.result as string);
      };
      reader.readAsDataURL(file);

      // Upload to Supabase Storage
      const { error: uploadError } = await supabase.storage
        .from(bucket)
        .upload(fileName, file, {
          cacheControl: '3600',
          upsert: false,
        });

      if (uploadError) {
        throw uploadError;
      }

      // Get public URL
      const { data: urlData } = supabase.storage
        .from(bucket)
        .getPublicUrl(fileName);

      console.log('🔍 ImageUpload - URL Data:', {
        fileName,
        urlData,
        publicUrl: urlData?.publicUrl,
      });

      if (urlData?.publicUrl) {
        console.log('✅ ImageUpload - Calling onImageUploaded with URL:', urlData.publicUrl);
        onImageUploaded(urlData.publicUrl);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Image uploaded',
          message: 'Image has been uploaded successfully',
        });
      } else {
        console.error('❌ ImageUpload - No publicUrl returned:', urlData);
        throw new Error('Failed to get public URL for uploaded image');
      }
    } catch (error: any) {
      console.error('Error uploading image:', error);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Upload failed',
        message: error.message || 'Failed to upload image. Please try again.',
      });
      setPreview(currentImageUrl || null);
    } finally {
      setIsUploading(false);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleFileSelect(file);
    }
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) {
      handleFileSelect(file);
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

  const handleRemove = async () => {
    if (!currentImageUrl) return;

    try {
      // Extract storage path from public URL: .../object/public/{bucket}/{path}
      const segment = `/object/public/${bucket}/`;
      const idx = currentImageUrl.indexOf(segment);
      const path = idx >= 0 ? currentImageUrl.slice(idx + segment.length) : null;
      if (!path) return;

      const { error } = await supabase.storage
        .from(bucket)
        .remove([path]);

      if (error) {
        console.error('Error deleting image:', error);
      }
    } catch (error) {
      console.error('Error deleting image:', error);
    }

    setPreview(null);
    onImageUploaded(null);
  };

  // Update preview when currentImageUrl changes externally
  useEffect(() => {
    if (currentImageUrl !== preview) {
      setPreview(currentImageUrl || null);
    }
  }, [currentImageUrl]);

  return (
    <div className="space-y-2">
      <label className="text-xs font-medium text-gray-700">{label}</label>
      
      {preview ? (
        <div className="relative inline-block">
          <div className="relative w-48 h-48 border border-gray-200 rounded-lg overflow-hidden bg-gray-50">
            <img
              src={preview}
              alt="Preview"
              className="w-full h-full object-contain"
              onError={() => {
                setPreview(null);
                onImageUploaded(null);
              }}
            />
            {!disabled && (
              <button
                type="button"
                onClick={handleRemove}
                className="absolute top-2 right-2 p-1 bg-red-500 text-white rounded-full hover:bg-red-600 transition-colors"
                title="Remove image"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      ) : (
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
            accept="image/*"
            onChange={handleFileInputChange}
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
                    PNG, JPG, GIF up to 5MB
                  </p>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

