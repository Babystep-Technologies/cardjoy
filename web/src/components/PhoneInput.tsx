import React from 'react';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { COUNTRY_OPTIONS, formatAsYouType, type CountryCode } from '@/lib/phone';

type PhoneInputProps = {
  id?: string;
  country: CountryCode;
  onCountryChange: (country: CountryCode) => void;
  /** The number as typed, in `country`'s national format. */
  value: string;
  onValueChange: (value: string) => void;
  onBlur?: () => void;
  invalid?: boolean;
  placeholder?: string;
};

/**
 * A country selector plus a number field that formats as you type. The value stays in the
 * national format while editing; callers convert to E.164 with `toE164` on submit.
 */
export const PhoneInput: React.FC<PhoneInputProps> = ({
  id,
  country,
  onCountryChange,
  value,
  onValueChange,
  onBlur,
  invalid,
  placeholder,
}) => {
  const handleChange = (next: string) => {
    const formatted = formatAsYouType(next, country);
    // Formatting re-inserts punctuation, so backspacing over a ")" or "-" alone would leave
    // the value unchanged and the field would feel stuck. Drop the last digit instead.
    if (next.length < value.length && formatted === value) {
      onValueChange(formatAsYouType(next.replace(/\d(?=\D*$)/, ''), country));
      return;
    }
    onValueChange(formatted);
  };

  const handleCountryChange = (next: string) => {
    const nextCountry = next as CountryCode;
    onCountryChange(nextCountry);
    // Re-format what's already typed for the newly selected country.
    onValueChange(formatAsYouType(value, nextCountry));
  };

  const selected = COUNTRY_OPTIONS.find(option => option.code === country);

  return (
    <div className="flex gap-2">
      <Select value={country} onValueChange={handleCountryChange}>
        <SelectTrigger className="w-[7.5rem] shrink-0" aria-label="Country code">
          <SelectValue>
            {selected ? `${selected.flag} +${selected.callingCode}` : country}
          </SelectValue>
        </SelectTrigger>
        <SelectContent className="max-h-72">
          {COUNTRY_OPTIONS.map(option => (
            // The list is ~240 long, so type-ahead is the only practical way to find a
            // country. Radix matches the item's rendered text, which starts with the flag
            // emoji, so point it at the name instead.
            <SelectItem key={option.code} value={option.code} textValue={option.name}>
              {option.flag} {option.name} +{option.callingCode}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Input
        id={id}
        type="tel"
        inputMode="tel"
        autoComplete="tel-national"
        value={value}
        onChange={e => handleChange(e.target.value)}
        onBlur={onBlur}
        aria-invalid={invalid || undefined}
        placeholder={placeholder}
      />
    </div>
  );
};
