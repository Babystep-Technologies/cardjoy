import type { ReactNode } from 'react';
import { AlertTriangle } from 'lucide-react';

interface ErrorScreenProps {
  message?: string;
  details?: string;
  /**
   * Optional affordance under the text — a retry, or a way back out. Some
   * failures are transient and the user can do something about them; most of
   * this component's callers have nothing to offer, so it stays optional.
   */
  action?: ReactNode;
}

export default function ErrorScreen({
  message = 'Something went wrong.',
  details,
  action,
}: ErrorScreenProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[calc(100vh-4rem)] text-center text-gray-600 px-4">
      <AlertTriangle className="w-10 h-10 text-red-500 mb-4" />
      <p className="text-xl font-semibold mb-2">{message}</p>
      {details && <p className="text-sm text-gray-500 max-w-md">{details}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
