import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';

interface ResolvedStorageImgProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  src: string | null | undefined;
}

/**
 * Renders an img using a resolved (signed) URL when src is a Supabase storage URL,
 * so old and new catalog/dealer images load with RLS.
 */
export default function ResolvedStorageImg({ src, ...props }: ResolvedStorageImgProps) {
  const resolved = useResolvedStorageUrl(src);
  if (!resolved) return null;
  return <img {...props} src={resolved} />;
}
