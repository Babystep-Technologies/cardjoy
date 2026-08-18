// Mailing-address helpers shared by the contact dialog and the contact list.
//
// The API stores the address as six loose columns and enforces all-or-nothing: the moment
// any field is set, line 1, city, postal code and country are all required
// (`Contact::REQUIRED_ADDRESS_FIELDS`). We mirror that rule here so a half-filled address is
// caught inline rather than coming back as a server error.
import { COUNTRY_OPTIONS, type CountryCode } from '@/lib/phone';

export type { CountryCode };

/**
 * ISO 3166-1 alpha-2 options for the country select. Reused from the phone helpers: that
 * list is already the full ISO country set with display names and flags, and the extra
 * calling code is simply ignored here.
 */
export const COUNTRY_CODE_OPTIONS = COUNTRY_OPTIONS;

// Where the rate card is cheapest and most of our users are.
export const DEFAULT_COUNTRY_CODE: CountryCode = 'US';

/** The address as the dialog edits it — strings only, never null. */
export type AddressDraft = {
  line1: string;
  line2: string;
  city: string;
  region: string;
  postalCode: string;
  countryCode: CountryCode;
};

export type AddressErrors = Partial<Record<keyof AddressDraft, string>>;

/** The address as the API returns it on `Contact`. */
export type ContactAddress = {
  addressLine1: string | null;
  addressLine2: string | null;
  city: string | null;
  region: string | null;
  postalCode: string | null;
  countryCode: string | null;
};

export function emptyAddressDraft(): AddressDraft {
  return {
    line1: '',
    line2: '',
    city: '',
    region: '',
    postalCode: '',
    countryCode: DEFAULT_COUNTRY_CODE,
  };
}

export function addressDraftFrom(contact: ContactAddress): AddressDraft {
  return {
    line1: contact.addressLine1 ?? '',
    line2: contact.addressLine2 ?? '',
    city: contact.city ?? '',
    region: contact.region ?? '',
    postalCode: contact.postalCode ?? '',
    countryCode: (contact.countryCode as CountryCode | null) ?? DEFAULT_COUNTRY_CODE,
  };
}

/**
 * Whether the user has actually started an address.
 *
 * The country is deliberately excluded. It defaults to US so the select has something to
 * show, and a default nobody touched must not turn a contact with no address at all into a
 * partial one — which is exactly what the API's all-or-nothing validation would reject.
 */
export function hasAddressInput(draft: AddressDraft): boolean {
  return [draft.line1, draft.line2, draft.city, draft.region, draft.postalCode].some(
    value => value.trim() !== ''
  );
}

const REQUIRED_FIELDS: { field: keyof AddressDraft; label: string }[] = [
  { field: 'line1', label: 'Street address' },
  { field: 'city', label: 'City' },
  { field: 'postalCode', label: 'Postal code' },
  { field: 'countryCode', label: 'Country' },
];

/** The same rule `Contact` validates, checked before we send anything. */
export function validateAddress(draft: AddressDraft): AddressErrors {
  if (!hasAddressInput(draft)) return {};

  const errors: AddressErrors = {};
  for (const { field, label } of REQUIRED_FIELDS) {
    if (!draft[field].trim()) {
      errors[field] = `${label} is required to complete the mailing address`;
    }
  }
  return errors;
}

/**
 * The six address arguments `createContact` / `updateContact` take. An address the user
 * never started sends empty strings rather than being omitted, so editing a contact and
 * emptying the fields clears the stored address instead of leaving it untouched.
 */
export function addressInput(draft: AddressDraft): ContactAddress {
  if (!hasAddressInput(draft)) {
    return {
      addressLine1: '',
      addressLine2: '',
      city: '',
      region: '',
      postalCode: '',
      countryCode: '',
    };
  }

  return {
    addressLine1: draft.line1.trim(),
    addressLine2: draft.line2.trim(),
    city: draft.city.trim(),
    region: draft.region.trim(),
    postalCode: draft.postalCode.trim(),
    countryCode: draft.countryCode,
  };
}

export function countryName(code: string | null | undefined): string | null {
  if (!code) return null;
  return COUNTRY_CODE_OPTIONS.find(option => option.code === code)?.name ?? code;
}

/** How a stored address reads on a contact row: "12 Elm St, Austin, TX 78701, United States". */
export function formatAddressSummary(contact: ContactAddress): string | null {
  const parts = [
    contact.addressLine1,
    contact.addressLine2,
    contact.city,
    [contact.region, contact.postalCode].filter(Boolean).join(' ') || null,
    countryName(contact.countryCode),
  ].filter(Boolean);

  return parts.length > 0 ? parts.join(', ') : null;
}
