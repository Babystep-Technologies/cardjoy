/**
 * The send flow's GraphQL documents, co-located with the page (this repo has no
 * codegen — see docs/DEVELOPMENT.md).
 *
 * Note what is *not* here: nothing sends a price. `SEND_HOLIDAY_CARD` carries a
 * card, a list of contacts, and a mailing class, because `SendHolidayCard` has
 * no argument that would accept an amount — the server re-quotes inside the
 * transaction that debits the wallet. A price variable added here would be
 * rejected, and that is deliberate.
 */
import { gql } from '@apollo/client';

/** Everything the recipient picker renders a row from. */
const SEND_CONTACT_FIELDS = gql`
  fragment SendContactFields on Contact {
    id
    name
    email
    addressLine1
    addressLine2
    city
    region
    postalCode
    countryCode
    mailable
    addressVerificationStatus
    contactLists {
      id
      name
    }
  }
`;

/** The card's identity and its whole proof state, in one selection. */
const SEND_CARD_FIELDS = gql`
  fragment SendCardFields on HolidayCard {
    id
    externalId
    title
    size
    templateId
    proofUrl
    proofGeneratedAt
    proofCurrent
    proofApproved
  }
`;

/**
 * The card, the address book, the lists — and whether any of this can run at
 * all. One round trip on flow entry.
 *
 * `holidayCardMailingAvailability` rides along rather than being asked for
 * separately because the answer decides whether the flow renders. A second
 * request would let the stepper paint first and be withdrawn a moment later
 * (#153).
 */
export const GET_SEND_DATA = gql`
  query HolidayCardSend($externalId: String!) {
    holidayCard(externalId: $externalId) {
      ...SendCardFields
    }
    holidayCardMailingAvailability {
      proofsAvailable
      mailingAvailable
    }
    myContacts {
      ...SendContactFields
    }
    myContactLists {
      id
      name
      contactsCount
      mailableContactsCount
    }
  }
  ${SEND_CARD_FIELDS}
  ${SEND_CONTACT_FIELDS}
`;

/**
 * Priced per recipient, with the wallet balance alongside so the shortfall is
 * one subtraction rather than a second round trip that could disagree.
 *
 * Advisory, always. The server re-prices at charge time; treat `totalCents` as
 * a number to show someone, not as a price anyone has committed to.
 */
export const QUOTE_MAILING = gql`
  query QuoteHolidayCardMailing($holidayCardId: ID!, $contactIds: [ID!]!) {
    quoteHolidayCardMailing(holidayCardId: $holidayCardId, contactIds: $contactIds) {
      totalCents
      mailableCount
      unmailableCount
      postageBalanceCents
      entries {
        mailable
        addressVerificationStatus
        zone
        totalCents
        reason
        contact {
          ...SendContactFields
        }
      }
    }
  }
  ${SEND_CONTACT_FIELDS}
`;

export const GENERATE_PROOF = gql`
  mutation GenerateHolidayCardProof($externalId: String!) {
    generateHolidayCardProof(input: { externalId: $externalId }) {
      holidayCard {
        ...SendCardFields
      }
      errors
    }
  }
  ${SEND_CARD_FIELDS}
`;

export const APPROVE_PROOF = gql`
  mutation ApproveHolidayCardProof($externalId: String!) {
    approveHolidayCardProof(input: { externalId: $externalId }) {
      holidayCard {
        ...SendCardFields
      }
      errors
    }
  }
  ${SEND_CARD_FIELDS}
`;

/**
 * The irreversible one. `totalChargedCents` comes back from the server's own
 * re-quote, so the client can tell the user if it moved from what they were
 * shown instead of letting a silent difference through.
 */
export const SEND_HOLIDAY_CARD = gql`
  mutation SendHolidayCard($holidayCardId: ID!, $contactIds: [ID!]!) {
    sendHolidayCard(input: { holidayCardId: $holidayCardId, contactIds: $contactIds }) {
      totalChargedCents
      orders {
        id
        status
        chargedCents
        recipientName
      }
      errors
    }
  }
`;

/** The inline "add an address" affordance on an unmailable recipient row. */
export const UPDATE_CONTACT_ADDRESS = gql`
  mutation UpdateContactAddress($input: UpdateContactInput!) {
    updateContact(input: $input) {
      contact {
        ...SendContactFields
      }
      errors
    }
  }
  ${SEND_CONTACT_FIELDS}
`;

/**
 * The order list the flow lands on lives with the orders page itself, in
 * `../queries.ts` — it outlives this flow, and the page that polls it is not
 * part of it.
 */
