import React from 'react';

import { cn } from '@/lib/utils';
import type { AddressFilter } from '../types';

type ContactsToolbarProps = {
  /** How many of the currently visible contacts are selected. */
  selectedCount: number;
  visibleCount: number;
  onToggleAll: (selectAll: boolean) => void;
  addressFilter: AddressFilter;
  onAddressFilterChange: (filter: AddressFilter) => void;
  /** Counts for the filter chips, over the contacts in scope (a list, or everyone). */
  totalCount: number;
  mailableCount: number;
};

const ContactsToolbar: React.FC<ContactsToolbarProps> = ({
  selectedCount,
  visibleCount,
  onToggleAll,
  addressFilter,
  onAddressFilterChange,
  totalCount,
  mailableCount,
}) => {
  const allSelected = visibleCount > 0 && selectedCount === visibleCount;
  const someSelected = selectedCount > 0 && !allSelected;

  const filters: { value: AddressFilter; label: string }[] = [
    { value: 'all', label: `All ${totalCount}` },
    { value: 'has', label: `Has address ${mailableCount}` },
    { value: 'missing', label: `Missing address ${totalCount - mailableCount}` },
  ];

  return (
    <div className="mb-3 flex flex-wrap items-center gap-x-4 gap-y-2">
      <label className="flex cursor-pointer items-center gap-2 text-sm text-gray-600">
        <input
          type="checkbox"
          className="h-4 w-4 cursor-pointer accent-pink-600"
          checked={allSelected}
          // Some-but-not-all is only expressible through the DOM node.
          ref={element => {
            if (element) element.indeterminate = someSelected;
          }}
          onChange={e => onToggleAll(e.target.checked)}
          disabled={visibleCount === 0}
          aria-label="Select all shown contacts"
        />
        Select all shown
      </label>

      <div className="flex flex-wrap gap-1" role="group" aria-label="Filter by mailing address">
        {filters.map(filter => (
          <button
            key={filter.value}
            type="button"
            aria-pressed={addressFilter === filter.value}
            onClick={() => onAddressFilterChange(filter.value)}
            className={cn(
              'rounded-full border px-3 py-1 text-xs font-medium transition-colors',
              addressFilter === filter.value
                ? 'border-pink-300 bg-pink-100 text-pink-900'
                : 'border-gray-200 bg-white text-gray-600 hover:bg-gray-50'
            )}
          >
            {filter.label}
          </button>
        ))}
      </div>
    </div>
  );
};

export default ContactsToolbar;
