import { Mail, Heart, PartyPopper, Gift, type LucideIcon } from 'lucide-react';

// Product identities shown in marketing surfaces. This is broader than the API's
// Card::KINDS (group | one_on_one): invitation is a separate model and holiday is not
// built yet, but all four share one brand identity here.
export type CardTypeId = 'group' | 'one_on_one' | 'invitation' | 'holiday';

export interface CardTypeTheme {
  id: CardTypeId;
  label: string;
  shortLabel: string;
  // Action-phrased call to action, e.g. "Create a Group Card".
  cta: string;
  // Empty when the type has no working create flow yet (holiday).
  route: string;
  icon: LucideIcon;
  description: string;
  // The single authoritative per-type brand color, used for feature icons and CTA accents.
  colorVar: string;
  // Gradient stops for the tile header, anchored on the type's color.
  gradient: string;
  comingSoon?: boolean;
}

// Single source of truth for the per-type color scheme. Consumed by the marketing home
// page, the Products dropdown, and the create/edit flows so the mapping lives in one place.
// Mapping: group = pink, one_on_one = blue, invitation = green, holiday = yellow.
export const cardTypes: CardTypeTheme[] = [
  {
    id: 'group',
    label: 'Group Cards',
    shortLabel: 'Group',
    cta: 'Create a Group Card',
    route: '/group-card/new',
    icon: Mail,
    description:
      'Collect heartfelt messages, photos & wishes from everyone who cares — all in one beautiful keepsake.',
    colorVar: 'var(--color-brand-pink)',
    gradient: 'from-[var(--color-brand-pink)] to-[var(--color-brand-blue)]',
  },
  {
    id: 'one_on_one',
    label: '1-on-1 Cards',
    shortLabel: '1-on-1',
    cta: 'Send a 1-on-1 Card',
    route: '/one-on-one-card/new',
    icon: Heart,
    description:
      'Send one person a single heartfelt message that opens with an effect — no group signing needed.',
    colorVar: 'var(--color-brand-blue)',
    gradient: 'from-[var(--color-brand-blue)] to-[var(--color-brand-green)]',
  },
  {
    id: 'invitation',
    label: 'Invitations',
    shortLabel: 'Invites',
    cta: 'Create an Invitation',
    route: '/invitation/new',
    icon: PartyPopper,
    description:
      'Design animated invites your guests will love, with RSVP tracking and event details built right in.',
    colorVar: 'var(--color-brand-green)',
    gradient: 'from-[var(--color-brand-green)] to-[var(--color-brand-blue)]',
  },
  {
    id: 'holiday',
    label: 'Holiday Cards',
    shortLabel: 'Holiday',
    cta: 'Create a Holiday Card',
    route: '',
    icon: Gift,
    description:
      'Spread seasonal cheer with festive cards made for the holidays — coming soon to CardJoy.',
    colorVar: 'var(--color-brand-yellow)',
    gradient: 'from-[var(--color-brand-yellow)] to-[var(--color-brand-pink)]',
    comingSoon: true,
  },
];

export const cardTypeById: Record<CardTypeId, CardTypeTheme> = Object.fromEntries(
  cardTypes.map(type => [type.id, type])
) as Record<CardTypeId, CardTypeTheme>;
