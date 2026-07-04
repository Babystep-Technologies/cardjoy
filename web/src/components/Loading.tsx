import { Loader2 } from 'lucide-react';

export default function LoadingScreen({ message = 'Loading...' }) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[calc(100vh-4rem)] text-gray-600">
      <Loader2 className="w-10 h-10 animate-spin mb-4 text-gray-500" />
      <p className="text-lg font-medium">{message}</p>
    </div>
  );
}
