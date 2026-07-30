import { Building2, CalendarClock, MessageSquare, type LucideIcon } from 'lucide-react';

// Business-audience entries shown in the "Business" nav dropdown (desktop + mobile).
// Parallel to `cardTypes` for the Personal menu — copy and routes live here, not in JSX.
//
// CardJoy serves two business use cases and the menu is shaped around them: group cards
// a team starts from Slack, and a contact book that reminds an owner before a client's
// occasion. Reminders belong to the second one only — the Slack app has no roster and
// stores no dates, so no description here may imply it remembers anything on its own.
export interface BusinessLink {
  id: string;
  label: string;
  description: string;
  route: string;
  icon: LucideIcon;
  // Tailwind gradient stops for the icon tile, matching the ProductMenu tile treatment.
  gradient: string;
}

export const businessLinks: BusinessLink[] = [
  {
    id: 'slack',
    label: 'Group cards in Slack',
    description: 'Start a card with /cardjoy and let the whole team sign it.',
    route: '/slack',
    icon: MessageSquare,
    gradient: 'from-[var(--color-brand-pink)] to-[var(--color-brand-blue)]',
  },
  {
    id: 'client-occasions',
    label: 'Client occasions',
    description: 'Keep your clients’ dates and get an email a week before each one.',
    route: '/client-occasions',
    icon: CalendarClock,
    gradient: 'from-[var(--color-brand-green)] to-[var(--color-brand-yellow)]',
  },
  {
    id: 'for-business',
    label: 'CardJoy for Business',
    description: 'Both use cases, and which one fits your business.',
    route: '/for-business',
    icon: Building2,
    gradient: 'from-[var(--color-brand-blue)] to-[var(--color-brand-green)]',
  },
];
