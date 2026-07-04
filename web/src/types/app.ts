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

export type CardType = {
  externalId: string;
  slug?: string | null;
  title: string;
  locked: boolean;
  coverImageUrl?: string | null;
  styles: StyleType[];
  recipients: string[];
  maxMessages?: number;
  requireLoginToContribute?: boolean;
};

export type UserMessageType = {
  id: string;
  title: string;
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
  title: string;
  text: string;
  imageUrl?: string | null;
  flagged?: boolean;
  name?: string;
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
