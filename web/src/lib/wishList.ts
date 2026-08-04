export type ContributionKind = 'venmo' | 'cashapp' | 'paypal' | 'zelle' | 'trump_account';

export interface ContributionKindMeta {
  value: ContributionKind;
  label: string;
  handleLabel: string;
  handlePlaceholder: string;
  /** Whether we can deep-link the guest into the payment app. */
  linkable: boolean;
  hint?: string;
}

/**
 * Cash gifts are pass-through only: CardJoy links out to the host's own payment account and never
 * holds or moves funds. Keep this list in sync with WishListContribution::KINDS in the API.
 */
export const CONTRIBUTION_KINDS: ContributionKindMeta[] = [
  {
    value: 'venmo',
    label: 'Venmo',
    handleLabel: 'Venmo username',
    handlePlaceholder: '@your-handle',
    linkable: true,
  },
  {
    value: 'cashapp',
    label: 'Cash App',
    handleLabel: 'Cashtag',
    handlePlaceholder: '$yourcashtag',
    linkable: true,
  },
  {
    value: 'paypal',
    label: 'PayPal',
    handleLabel: 'PayPal.Me link or username',
    handlePlaceholder: 'paypal.me/you',
    linkable: true,
  },
  {
    value: 'zelle',
    label: 'Zelle',
    handleLabel: 'Email or phone',
    handlePlaceholder: 'you@example.com',
    linkable: false,
    hint: 'Zelle has no shareable link, so guests will copy this and send from their bank app.',
  },
  {
    value: 'trump_account',
    label: 'Trump Account',
    handleLabel: 'How to contribute',
    handlePlaceholder: 'Message me and I’ll send the account details',
    linkable: false,
    hint: 'Contributions go through the account custodian, so guests get your instructions instead of a link.',
  },
];

export const contributionKindMeta = (kind: string): ContributionKindMeta =>
  CONTRIBUTION_KINDS.find(k => k.value === kind) ?? CONTRIBUTION_KINDS[0];

export const TRUMP_ACCOUNT_INFO_URL = 'https://www.irs.gov/trumpaccounts';

export interface WishListItem {
  id?: string;
  title: string;
  url?: string | null;
  imageUrl?: string | null;
  price?: string | null;
  store?: string | null;
  note?: string | null;
  quantity: number;
}

export interface WishListContribution {
  id?: string;
  kind: ContributionKind;
  handle: string;
  label?: string | null;
  suggestedAmount?: string | null;
  note?: string | null;
  actionUrl?: string | null;
}

export interface WishList {
  id?: string;
  title: string;
  intro?: string | null;
  visible: boolean;
  surpriseMode: boolean;
  items: WishListItem[];
  contributions: WishListContribution[];
}

export const WISH_LIST_FIELDS = `
  id
  title
  intro
  visible
  surpriseMode
  items {
    id
    title
    url
    imageUrl
    price
    store
    note
    quantity
    position
  }
  contributions {
    id
    kind
    handle
    label
    suggestedAmount
    note
    actionUrl
    position
  }
`;
