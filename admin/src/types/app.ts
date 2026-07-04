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
