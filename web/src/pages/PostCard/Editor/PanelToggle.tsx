/**
 * Front / back switch.
 *
 * The back is the constrained side — PostGrid owns a block of it — so the toggle
 * says so rather than leaving the user to discover it by switching. A card has
 * exactly two sides, so this is a segmented control and not a dropdown.
 */
import React from 'react';
import type { PanelName } from '../types';

interface PanelToggleProps {
  value: PanelName;
  onChange: (panel: PanelName) => void;
}

export const PanelToggle: React.FC<PanelToggleProps> = ({ value, onChange }) => (
  <div className="inline-flex rounded-lg bg-gray-200/80 p-1" role="tablist" aria-label="Card side">
    {(['front', 'back'] as PanelName[]).map(panel => (
      <button
        key={panel}
        type="button"
        role="tab"
        aria-selected={value === panel}
        onClick={() => onChange(panel)}
        className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors capitalize ${
          value === panel ? 'bg-white shadow text-gray-900' : 'text-gray-600 hover:text-gray-900'
        }`}
      >
        {panel}
      </button>
    ))}
  </div>
);
