import { MessageSquare, Play, Users, type LucideIcon } from 'lucide-react';

// Business-audience entries shown in the "Business" nav dropdown (desktop + mobile).
// Parallel to `cardTypes` for the Personal menu — copy and routes live here, not in JSX.
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
    label: 'Slack integration',
    description: 'Create cards with /cardjoy, right where your team works.',
    route: '/slack',
    icon: MessageSquare,
    gradient: 'from-[var(--color-brand-pink)] to-[var(--color-brand-blue)]',
  },
  {
    id: 'demo',
    label: 'Watch demo',
    description: 'See CardJoy for Slack in 90 seconds.',
    route: '/slack#demo',
    icon: Play,
    gradient: 'from-[var(--color-brand-blue)] to-[var(--color-brand-green)]',
  },
  {
    id: 'for-teams',
    label: 'CardJoy for Teams',
    description: 'Automate every birthday, work anniversary & farewell.',
    route: '/for-teams',
    icon: Users,
    gradient: 'from-[var(--color-brand-green)] to-[var(--color-brand-yellow)]',
  },
];
