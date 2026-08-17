// Shapes the Contacts page and its components share. These mirror the GraphQL documents
// in `Index.tsx`; there is no codegen in this repo, so they are maintained by hand.
import type { ContactAddress } from '@/lib/address';

export type Occasion = {
  id: string;
  kind: string;
  occursOn: string;
  recurring: boolean;
  nextOccurrence: string;
  // Days before the occasion that its reminder email goes out; null means off.
  reminderLeadDays: number | null;
};

/** A list as it appears in the sidebar — counts only, never its members. */
export type ContactListSummary = {
  id: string;
  name: string;
  contactsCount: number;
  mailableContactsCount: number;
};

export type Contact = ContactAddress & {
  id: string;
  name: string;
  email: string | null;
  relationship: string | null;
  phone: string | null;
  notes: string | null;
  // Whether the address is complete enough to deliver to; computed by the API.
  mailable: boolean;
  occasions: Occasion[];
  // Membership is read off the contact rather than off the list, so filtering the table by
  // list never has to ask for a list's `contacts`.
  contactLists: { id: string; name: string }[];
};

export type UpcomingOccasion = Occasion & {
  contact: { id: string; name: string };
};

/** Which contacts the table is showing, by address completeness. */
export type AddressFilter = 'all' | 'has' | 'missing';
