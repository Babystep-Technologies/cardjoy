import { AlertTriangle } from 'lucide-react';

interface ErrorScreenProps {
  message?: string;
  details?: string;
}

export default function ErrorScreen({
  message = 'Something went wrong.',
  details,
}: ErrorScreenProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[calc(100vh-4rem)] text-center text-gray-600 px-4">
      <AlertTriangle className="w-10 h-10 text-red-500 mb-4" />
      <p className="text-xl font-semibold mb-2">{message}</p>
      {details && <p className="text-sm text-gray-500 max-w-md">{details}</p>}
    </div>
  );
}
