import { useState } from 'react';
import { ImageIcon } from 'lucide-react';
import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';

type SizePreset = 'xs' | 'sm' | 'md' | 'lg';

const SIZE_CLASSES: Record<SizePreset, { container: string; icon: string }> = {
  xs: { container: 'w-8 h-8', icon: 'w-3.5 h-3.5' },
  sm: { container: 'w-10 h-10', icon: 'w-4 h-4' },
  md: { container: 'w-16 h-16', icon: 'w-6 h-6' },
  lg: { container: 'w-24 h-24', icon: 'w-8 h-8' },
};

interface CatalogItemImageProps {
  src: string | null | undefined;
  alt?: string;
  size?: SizePreset;
  className?: string;
  onClick?: () => void;
  objectFit?: 'cover' | 'contain';
}

/**
 * Centralized image display for CatalogItems.
 * - Resolves Supabase Storage URLs (public + path-only)
 * - Shows placeholder icon when no image
 * - Gracefully handles broken images with fallback
 * - Consistent styling across the app
 */
export default function CatalogItemImage({
  src,
  alt = 'Item',
  size = 'sm',
  className = '',
  onClick,
  objectFit = 'cover',
}: CatalogItemImageProps) {
  const resolvedUrl = useResolvedStorageUrl(src);
  const [broken, setBroken] = useState(false);

  const { container, icon } = SIZE_CLASSES[size];
  const showImage = resolvedUrl && !broken;

  return (
    <div
      className={`
        ${container} rounded border border-gray-200 overflow-hidden bg-gray-50
        flex items-center justify-center flex-shrink-0
        ${onClick ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''}
        ${className}
      `}
      onClick={onClick}
    >
      {showImage ? (
        <img
          src={resolvedUrl}
          alt={alt}
          className={`w-full h-full ${objectFit === 'contain' ? 'object-contain' : 'object-cover'}`}
          loading="lazy"
          decoding="async"
          onError={() => setBroken(true)}
        />
      ) : (
        <ImageIcon className={`${icon} text-gray-300`} />
      )}
    </div>
  );
}
