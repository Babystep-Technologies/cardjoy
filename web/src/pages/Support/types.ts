// Shared shapes for the support ticket pages, matching Types::SupportTicketType /
// Types::SupportTicketMessageType on the API.

export interface SupportTicketSummary {
  id: string;
  externalId: string;
  subject: string;
  category: string;
  status: string;
  lastCustomerReplyAt: string | null;
  lastAdminReplyAt: string | null;
  createdAt: string;
}

export interface SupportTicketMessage {
  id: string;
  authorKind: 'customer' | 'admin' | 'system';
  authorName: string | null;
  body: string;
  createdAt: string;
}

export interface SupportTicketDetail extends SupportTicketSummary {
  messages: SupportTicketMessage[];
}

// The four options already offered in the old Profile.tsx dialog — kept as the same
// value/label pairs so nothing about the category vocabulary changes for the customer,
// mirrored from SupportTicket::CATEGORIES on the API.
export const SUPPORT_CATEGORIES: { value: string; label: string }[] = [
  { value: 'Account question', label: 'Question about account' },
  { value: 'Product features', label: 'Question about product features' },
  { value: 'Credits & promos', label: 'Credits & promos' },
  { value: 'Others', label: 'Others' },
];

// Mirrors SupportTicket::STATUSES, worded from the customer's side: "open" means we
// owe them a reply, "pending" means they owe us one.
export const STATUS_LABELS: Record<string, string> = {
  open: 'Waiting on us',
  pending: 'Waiting on you',
  resolved: 'Resolved',
  closed: 'Closed',
};

export function statusBadgeVariant(status: string): 'default' | 'secondary' | 'outline' {
  if (status === 'pending') return 'default';
  if (status === 'open') return 'secondary';
  return 'outline';
}

/** Newest of the ticket's known activity timestamps, for the list's "last activity" column. */
export function lastActivityAt(ticket: SupportTicketSummary): string {
  return [ticket.lastAdminReplyAt, ticket.lastCustomerReplyAt, ticket.createdAt]
    .filter((value): value is string => Boolean(value))
    .sort()
    .at(-1)!;
}
