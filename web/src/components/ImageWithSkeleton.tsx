import React, { useState } from 'react';
import { Skeleton } from '@/components/ui/skeleton';
import { Button } from '@/components/ui/button';
import { RotateCcw } from 'lucide-react';

interface ImageWithSkeletonProps {
  src: string;
  alt: string;
  className?: string;
  style?: React.CSSProperties;
  onClick?: () => void;
  children?: React.ReactNode; // For overlay content like attribution
}

const ImageWithSkeleton: React.FC<ImageWithSkeletonProps> = ({
  src,
  alt,
  className = '',
  style,
  onClick,
  children,
}) => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [retryKey, setRetryKey] = useState(0);

  const handleLoad = () => {
    setLoading(false);
    setError(false);
  };

  const handleError = () => {
    setLoading(false);
    setError(true);
  };

  const handleRetry = (e: React.MouseEvent) => {
    e.stopPropagation(); // Prevent triggering onClick of parent
    setLoading(true);
    setError(false);
    setRetryKey(prev => prev + 1); // Force image reload
  };

  const containerClasses = `relative ${className} ${onClick ? 'cursor-pointer' : ''}`;

  return (
    <div className={containerClasses} style={style} onClick={onClick}>
      {loading && (
        <div className="absolute inset-0 z-10">
          <Skeleton className="w-full h-full rounded-lg bg-gray-200 dark:bg-gray-700" />
        </div>
      )}

      {error && (
        <div className="absolute inset-0 z-20 flex flex-col items-center justify-center bg-gray-100 dark:bg-gray-800 rounded-lg">
          <div className="text-center p-4">
            <div className="text-gray-400 mb-3 text-sm">Failed to load image</div>
            <Button variant="outline" size="sm" onClick={handleRetry} className="gap-2">
              <RotateCcw className="h-4 w-4" />
              Retry
            </Button>
          </div>
        </div>
      )}

      <img
        key={retryKey} // Force reload on retry
        src={src}
        alt={alt}
        className={`w-full h-full object-cover transition-opacity duration-200 ${
          loading || error ? 'opacity-0' : 'opacity-100'
        }`}
        onLoad={handleLoad}
        onError={handleError}
      />

      {children && !loading && !error && children}
    </div>
  );
};

export default ImageWithSkeleton;
