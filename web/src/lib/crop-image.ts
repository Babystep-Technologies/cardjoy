import { Area } from 'react-easy-crop';

export default async function getCroppedImg(
  imageSrc: string,
  pixelCrop: Area | null
): Promise<Blob> {
  if (!pixelCrop) throw new Error('Crop area is not defined');
  const image = await createImage(imageSrc);
  const canvas = document.createElement('canvas');
  canvas.width = pixelCrop.width;
  canvas.height = pixelCrop.height;
  const ctx = canvas.getContext('2d');

  if (!ctx) throw new Error('Canvas context not available');

  // Fill canvas with white to avoid black/blank bars in JPEG output
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height
  );

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      blob => {
        if (blob) resolve(blob);
        else reject(new Error('Failed to create blob from canvas'));
      },
      'image/jpeg',
      1
    );
  });
}

function createImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = 'anonymous'; // Needed for external URLs or some local setups
    image.src = url;
    image.onload = () => resolve(image);
    image.onerror = reject;
  });
}
