import * as React from 'react';
import { useAddressAutocomplete, PlacePrediction } from '@/hooks/useAddressAutocomplete';
import { cn } from '@/lib/utils';
import { Loader2 } from 'lucide-react';

export interface AddressAutocompleteProps
  extends Omit<React.ComponentProps<'input'>, 'onChange' | 'value' | 'onSelect'> {
  value: string;
  onChange: (value: string) => void;
  onSelect?: (prediction: PlacePrediction) => void;
}

function AddressAutocomplete({
  value,
  onChange,
  onSelect,
  className,
  ...props
}: AddressAutocompleteProps) {
  const [isOpen, setIsOpen] = React.useState(false);
  const [highlightedIndex, setHighlightedIndex] = React.useState(-1);
  const containerRef = React.useRef<HTMLDivElement>(null);
  const inputRef = React.useRef<HTMLInputElement>(null);
  const listRef = React.useRef<HTMLUListElement>(null);

  const { predictions, isLoading, getPredictions, clearPredictions, resetSession } =
    useAddressAutocomplete({
      debounceMs: 300,
      minChars: 3,
    });

  // Handle input change
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value;
    onChange(newValue);
    getPredictions(newValue);
    setIsOpen(true);
    setHighlightedIndex(-1);
  };

  // Handle prediction selection
  const handleSelect = (prediction: PlacePrediction) => {
    onChange(prediction.description);
    clearPredictions();
    setIsOpen(false);
    setHighlightedIndex(-1);
    resetSession(); // Reset session token after selection for billing optimization
    onSelect?.(prediction);
    inputRef.current?.focus();
  };

  // Handle keyboard navigation
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!isOpen || predictions.length === 0) {
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setHighlightedIndex(prev => (prev < predictions.length - 1 ? prev + 1 : 0));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setHighlightedIndex(prev => (prev > 0 ? prev - 1 : predictions.length - 1));
        break;
      case 'Enter':
        e.preventDefault();
        if (highlightedIndex >= 0 && highlightedIndex < predictions.length) {
          handleSelect(predictions[highlightedIndex]);
        }
        break;
      case 'Escape':
        e.preventDefault();
        setIsOpen(false);
        setHighlightedIndex(-1);
        break;
      case 'Tab':
        setIsOpen(false);
        setHighlightedIndex(-1);
        break;
    }
  };

  // Scroll highlighted item into view
  React.useEffect(() => {
    if (highlightedIndex >= 0 && listRef.current) {
      const highlightedItem = listRef.current.children[highlightedIndex] as HTMLElement;
      if (highlightedItem) {
        highlightedItem.scrollIntoView({ block: 'nearest' });
      }
    }
  }, [highlightedIndex]);

  // Close dropdown when clicking outside
  React.useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setHighlightedIndex(-1);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Show dropdown when focused and has predictions
  const handleFocus = () => {
    if (predictions.length > 0) {
      setIsOpen(true);
    }
  };

  const showDropdown = isOpen && (predictions.length > 0 || isLoading);

  return (
    <div ref={containerRef} className="relative w-full">
      <input
        ref={inputRef}
        type="text"
        value={value}
        onChange={handleInputChange}
        onKeyDown={handleKeyDown}
        onFocus={handleFocus}
        role="combobox"
        aria-expanded={showDropdown}
        aria-haspopup="listbox"
        aria-autocomplete="list"
        aria-controls={showDropdown ? 'address-autocomplete-list' : undefined}
        aria-activedescendant={
          highlightedIndex >= 0 ? `address-option-${highlightedIndex}` : undefined
        }
        autoComplete="off"
        data-slot="input"
        className={cn(
          'file:text-foreground placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground dark:bg-input/30 border-input flex h-9 w-full min-w-0 rounded-md border bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm',
          'focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]',
          'aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive',
          className
        )}
        {...props}
      />

      {showDropdown && (
        <ul
          ref={listRef}
          id="address-autocomplete-list"
          role="listbox"
          className="absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-md border bg-popover p-1 shadow-md"
        >
          {isLoading && predictions.length === 0 ? (
            <li className="flex items-center justify-center py-3 text-sm text-muted-foreground">
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Searching...
            </li>
          ) : (
            predictions.map((prediction, index) => (
              <li
                key={prediction.placeId}
                id={`address-option-${index}`}
                role="option"
                aria-selected={index === highlightedIndex}
                onClick={() => handleSelect(prediction)}
                onMouseEnter={() => setHighlightedIndex(index)}
                className={cn(
                  'cursor-pointer rounded-sm px-3 py-2 text-sm transition-colors',
                  index === highlightedIndex
                    ? 'bg-accent text-accent-foreground'
                    : 'hover:bg-accent'
                )}
              >
                <div className="font-medium">{prediction.mainText}</div>
                {prediction.secondaryText && (
                  <div className="text-xs text-muted-foreground">{prediction.secondaryText}</div>
                )}
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}

export { AddressAutocomplete };
