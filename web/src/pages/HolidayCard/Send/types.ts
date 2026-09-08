/**
 * The send flow's view of the API (#151).
 *
 * Money is `*Cents` everywhere and stays an integer all the way to
 * `formatCents`. There is no `totalDollars` in this file and there must not be
 * one — see `web/src/lib/money.ts`.
 */
import type { ContactAddress } from '@/lib/address';

/** A contact as the recipient picker needs it: identity, address, list membership. */
export interface SendContact extends ContactAddress {
  id: string;
  name: string;
  email: string | null;
  /** Whether the address has the four fields a carrier needs. Server-computed. */
  mailable: boolean;
  /** "verified" | "undeliverable" | "unverified", cached from PostGrid. */
  addressVerificationStatus: string;
  contactLists: { id: string; name: string }[];
}

export interface SendContactList {
  id: string;
  name: string;
  contactsCount: number;
  mailableContactsCount: number;
}

/** The card, as far as this flow cares: identity plus the whole proof state. */
export interface SendCard {
  id: string;
  externalId: string;
  title: string | null;
  size: string;
  templateId: string;
  proofUrl: string | null;
  proofGeneratedAt: string | null;
  /** False for a proof whose design has moved *or* whose PDF link has aged out. */
  proofCurrent: boolean;
  /** Only ever true while `proofCurrent` is — approval does not outlive its proof. */
  proofApproved: boolean;
}

/**
 * One recipient in a quote: either a price or the reason there isn't one, never
 * both. `totalCents` is null exactly when `reason` is set.
 */
export interface QuoteEntry {
  contact: SendContact;
  mailable: boolean;
  addressVerificationStatus: string;
  zone: string | null;
  totalCents: number | null;
  reason: string | null;
}

export interface MailingQuote {
  entries: QuoteEntry[];
  /** Over the mailable entries only. */
  totalCents: number;
  mailableCount: number;
  unmailableCount: number;
  postageBalanceCents: number;
}

export interface MailOrder {
  id: string;
  status: string;
  chargedCents: number;
  recipientName: string | null;
  recipientAddress: {
    name: string | null;
    addressLine1: string | null;
    addressLine2: string | null;
    city: string | null;
    region: string | null;
    postalCode: string | null;
    countryCode: string | null;
  };
  contactId: string | null;
  trackingNumber: string | null;
  failureReason: string | null;
  submittedAt: string | null;
  mailedAt: string | null;
  createdAt: string;
}

/** The three stages, in order. `review` covers pricing, payment, and confirmation. */
export type SendStage = 'recipients' | 'proof' | 'review';

export const SEND_STAGES: SendStage[] = ['recipients', 'proof', 'review'];

export const STAGE_LABELS: Record<SendStage, string> = {
  recipients: 'Recipients',
  proof: 'Proof',
  review: 'Review & pay',
};

/**
 * What the user has picked, kept as lists rather than as a flat id set so a
 * contact list stays *live*: adding someone to a selected list later adds them
 * to this send too.
 *
 * `excludedContactIds` is what makes that survivable — unticking one member of
 * a selected list has to mean "not this person", not "drop the whole list".
 */
export interface Selection {
  listIds: string[];
  /** Contacts ticked individually, whether or not they are on a selected list. */
  contactIds: string[];
  /** Contacts unticked despite a selected list vouching for them. */
  excludedContactIds: string[];
}

export const EMPTY_SELECTION: Selection = { listIds: [], contactIds: [], excludedContactIds: [] };
