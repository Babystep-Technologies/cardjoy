// Phone helpers shared by the contact dialog and the contact list.
//
// Phone numbers are stored in E.164 ("+14155550123") — the same canonical form the API
// validates — and only ever formatted for display. The bare `libphonenumber-js` entrypoint is
// the `min` metadata build, which is all we need for formatting and validation.
import {
  AsYouType,
  getCountries,
  getCountryCallingCode,
  parsePhoneNumberFromString,
  type CountryCode,
} from 'libphonenumber-js';

export type { CountryCode };

export const DEFAULT_PHONE_COUNTRY: CountryCode = 'US';

export type CountryOption = {
  code: CountryCode;
  name: string;
  callingCode: string;
  flag: string;
};

// Regional indicator symbols sit 127397 above the ASCII letters, so "US" maps to 🇺🇸.
function flagEmoji(code: CountryCode): string {
  return code.replace(/./g, char => String.fromCodePoint(127397 + char.charCodeAt(0)));
}

const regionNames = new Intl.DisplayNames(undefined, { type: 'region' });

// Built once — libphonenumber ships ~240 countries and the list never changes at runtime.
export const COUNTRY_OPTIONS: CountryOption[] = getCountries()
  .map(code => ({
    code,
    name: regionNames.of(code) ?? code,
    callingCode: getCountryCallingCode(code),
    flag: flagEmoji(code),
  }))
  .sort((a, b) => a.name.localeCompare(b.name));

/** Format partial input in `country`'s national format, e.g. "4155550" → "(415) 555-0". */
export function formatAsYouType(value: string, country: CountryCode): string {
  return new AsYouType(country).input(value);
}

/** The E.164 form of `value`, or null when it isn't a valid number for `country`. */
export function toE164(value: string, country: CountryCode): string | null {
  const parsed = parsePhoneNumberFromString(value, country);
  return parsed?.isValid() ? parsed.number : null;
}

/**
 * Split a stored E.164 number back into the country + national text the dialog edits, so
 * reopening a contact shows "(415) 555-0123" rather than "+14155550123".
 */
export function fromE164(phone: string | null | undefined): {
  country: CountryCode;
  national: string;
} {
  if (!phone) return { country: DEFAULT_PHONE_COUNTRY, national: '' };
  const parsed = parsePhoneNumberFromString(phone);
  if (!parsed) return { country: DEFAULT_PHONE_COUNTRY, national: phone };
  return { country: parsed.country ?? DEFAULT_PHONE_COUNTRY, national: parsed.formatNational() };
}

/**
 * How a stored number reads in the contact list: national format for the default country,
 * international (country code visible) for everyone else.
 */
export function formatPhoneForDisplay(phone: string | null | undefined): string | null {
  if (!phone) return null;
  const parsed = parsePhoneNumberFromString(phone);
  if (!parsed) return phone;
  return parsed.country === DEFAULT_PHONE_COUNTRY
    ? parsed.formatNational()
    : parsed.formatInternational();
}
