export type JWTPayload = {
  exp: number;
  iat: number;
  sub: string;
  email: string;
  name: string;
  user_id: string;
};

export type UserType = {
  id: string;
  name: string;
  email: string;
};

// Mirrors Card::KINDS in the API.
export type CardKind = 'group' | 'one_on_one';

export type CardType = {
  externalId: string;
  slug?: string | null;
  title: string;
  kind: CardKind;
  locked: boolean;
  coverImageUrl?: string | null;
  styles: StyleType[];
  recipients: string[];
  maxMessages?: number;
  requireLoginToContribute?: boolean;
  // Set only for a 1-on-1 card with a pending scheduled send (UTC ISO instant).
  deliverAt?: string | null;
  deliverToEmail?: string | null;
  // Set only for an organization-owned card; null means the card is personal.
  organization?: { id: string; name: string } | null;
  // The member who created the card. Only interesting for an org-owned card, where
  // "whose card is this" stops being obvious.
  user?: { id: string; name: string } | null;
};

export type UserMessageType = {
  id: string;
  // Nullable in the API: a 1-on-1 card's message carries no title.
  title?: string | null;
  text: string;
  imageUrl?: string | null;
  flagged?: boolean;
  displayName?: string;
  user: {
    id: string;
    name?: string;
  };
};

export type GuestMessageType = {
  id: string;
  title?: string | null;
  text?: string | null;
  imageUrl?: string | null;
  flagged?: boolean;
  name?: string | null;
};

export type MessageType = UserMessageType | GuestMessageType;

export type StyleType = {
  id: string;
  kind: string;
  value: string;
  tags: TagType[];
  name: string;
};

export type TagType = {
  id: string | null;
  name: string;
};

// Invitation Types
export type InvitationType = {
  id: string;
  slug?: string | null;
  title: string;
  description: string;
  location: string;
  eventDate: string;
  eventTime: string;
  coverImageUrl?: string | null;
  specialInstructions?: SpecialInstructionsType;
  rsvpDeadline?: string;
  createdBy: string;
  createdAt: string;
  styles?: StyleType[];
};

export type SpecialInstructionsType = {
  allowPlusOne: boolean;
  attire?: string;
  customInstructions?: string;
};

export type RSVPStatus = 'going' | 'maybe' | 'not-going';

export type RSVPResponseType = {
  id: string;
  invitationId: string;
  userId?: string;
  guestName?: string;
  guestEmail?: string;
  status: RSVPStatus;
  plusOne: boolean;
  plusOneName?: string;
  message?: string;
  createdAt: string;
};
