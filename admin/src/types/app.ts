export type JWTPayload = {
  exp: number;
  iat: number;
  sub: string;
  email: string;
  name: string;
  admin_id: string;
};

export type Tag = {
  id: string | null;
  name: string;
};

export type Style = {
  id: string;
  tags: Tag[];
  value: string;
  name: string;
  kind: string;
};

export type User = {
  id: string;
  email: string;
  name: string;
};

export type PromoCode = {
  id: string;
  code: string;
  creditAmount: number;
  usageLimit: number | null;
  timesRedeemed: number | null;
  expiresAt: string | null;
  createdAt: string;
  user: {
    id: string;
    email: string;
  } | null;
};

export type Organization = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  membersCount: number;
  creditBalance: number;
  createdAt: string;
};

export type OrganizationMembership = {
  role: string;
  createdAt: string;
  user: {
    id: string;
    name: string;
    email: string;
    creditBalance: number;
  };
};

// One row of an organization's shared credit pool. `amount` is signed:
// positive put credits in (a purchase or an admin grant), negative took them
// out (an allocation to a member, or a chargeback reversal).
export type OrganizationCredit = {
  id: string;
  amount: number;
  reason: string | null;
  createdAt: string;
  actor: { id: string; name: string } | null;
  member: { id: string; name: string } | null;
};

export type OrganizationDetail = Organization & {
  memberships: OrganizationMembership[];
  credits: OrganizationCredit[];
};

export type UserMessage = {
  id: string;
  title: string;
  text: string;
  imageUrl?: string | null;
  flagged?: boolean;
  user: {
    id: string;
    name?: string;
  };
};

export type GuestMessage = {
  id: string;
  title: string;
  text: string;
  imageUrl?: string | null;
  flagged?: boolean;
  name?: string;
};

export type Message = UserMessage | GuestMessage;

export type Card = {
  externalId: string;
  title: string;
  locked: boolean;
  deleted: boolean;
  flagged: boolean;
  styles: Style[];
  recipients: string[];
  createdAt: Date;
};

export type Invitation = {
  id: string;
  externalId: string;
  title: string;
  description?: string;
  location?: string;
  eventDate: string;
  eventTime: string;
  eventTimezone?: string;
  coverImageUrl?: string;
  createdAt: string;
  user: {
    id: string;
    name: string;
    email: string;
  };
  rsvpCounts: {
    going: number;
    maybe: number;
    notGoing: number;
    total: number;
    totalAttendees: number;
  };
};

export type Rsvp = {
  id: string;
  guestName: string;
  guestEmail: string;
  status: string;
  additionalGuestsCount: number;
  plusOneName?: string;
  message?: string;
  createdAt: string;
  user?: {
    id: string;
    name: string;
    email: string;
  };
};
