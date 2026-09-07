/**
 * Where the autosave got to, and what the server said if it refused.
 *
 * Validation errors are shown in full rather than as "something went wrong".
 * `design_config` is rejected as a whole document, so the model's message ("text
 * greeting in panel front is longer than 500 characters") is the only thing that
 * tells the user which of their edits is the problem.
 */
import React from 'react';
import { AlertCircle, Check, CloudOff, Loader2 } from 'lucide-react';
import type { SaveState } from './useAutosave';

interface SaveStatusProps {
  state: SaveState;
  errors: string[];
}

export const SaveStatus: React.FC<SaveStatusProps> = ({ state, errors }) => (
  <div className="flex flex-col items-end gap-1">
    <span className="flex items-center gap-1.5 text-xs text-gray-500" aria-live="polite">
      {state === 'saving' && (
        <>
          <Loader2 className="w-3.5 h-3.5 animate-spin" />
          Saving…
        </>
      )}
      {state === 'pending' && (
        <>
          <CloudOff className="w-3.5 h-3.5" />
          Unsaved changes
        </>
      )}
      {state === 'saved' && (
        <>
          <Check className="w-3.5 h-3.5 text-green-600" />
          Saved
        </>
      )}
      {state === 'error' && (
        <span className="flex items-center gap-1.5 text-red-600">
          <AlertCircle className="w-3.5 h-3.5" />
          Not saved
        </span>
      )}
    </span>

    {state === 'error' && errors.length > 0 && (
      <ul className="max-w-xs list-disc space-y-0.5 pl-4 text-right text-xs text-red-600">
        {errors.map(error => (
          <li key={error} className="text-left">
            {error}
          </li>
        ))}
      </ul>
    )}
  </div>
);
