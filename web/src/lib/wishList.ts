import { differenceInCalendarDays, parseISO } from 'date-fns';

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

/** What a registry is for. Keep in sync with WishList::OCCASIONS in the API. */
export const REGISTRY_OCCASIONS = [
  { value: 'birthday', label: 'Birthday' },
  { value: 'wedding', label: 'Wedding' },
  { value: 'baby', label: 'Baby' },
  { value: 'housewarming', label: 'Housewarming' },
  { value: 'graduation', label: 'Graduation' },
  { value: 'holiday', label: 'Holiday' },
  { value: 'other', label: 'Something else' },
] as const;

export const occasionLabel = (occasion?: string | null): string | null =>
  REGISTRY_OCCASIONS.find(o => o.value === occasion)?.label ?? null;

/**
 * Starting points per occasion (#251): a title and intro to edit, whether it is a surprise, and a few
 * plain-text ideas an owner can add with one tap. Deliberately generic, never specific products.
 */
export interface RegistryTemplate {
  title: string;
  intro: string;
  surpriseMode: boolean;
  suggestions: string[];
}

export const REGISTRY_TEMPLATES: Record<string, RegistryTemplate> = {
  birthday: {
    title: 'My birthday wish list',
    intro: 'Thanks for celebrating with me! Here are a few things I would love.',
    surpriseMode: true,
    suggestions: [
      'A good book',
      'Gift card to a favorite restaurant',
      'Something for my hobby',
      'Cozy blanket',
    ],
  },
  wedding: {
    title: 'Our wedding registry',
    intro:
      'Your love and support mean the world to us. If you would like to give a gift, here are some ideas.',
    surpriseMode: false,
    suggestions: ['Cookware set', 'Bedding', 'Dinnerware', 'Honeymoon fund', 'Home decor'],
  },
  baby: {
    title: 'Baby registry',
    intro: 'We are so grateful for your help getting ready for our little one.',
    surpriseMode: false,
    suggestions: ['Stroller', 'Crib', 'Diapers', 'Baby carrier', 'Swaddle blankets'],
  },
  housewarming: {
    title: 'Housewarming wish list',
    intro: 'Come see the new place! If you would like to bring something, here are some ideas.',
    surpriseMode: false,
    suggestions: ['Kitchen tools', 'Houseplant', 'Throw pillows', 'Wall art', 'Towels'],
  },
  graduation: {
    title: 'Graduation wish list',
    intro: 'Thank you for helping me celebrate this milestone.',
    surpriseMode: true,
    suggestions: ['Laptop accessories', 'Luggage', 'Work wardrobe', 'Gift card for books'],
  },
  holiday: {
    title: 'Holiday wish list',
    intro: 'Happy holidays! Here are some ideas if you are shopping for me.',
    surpriseMode: true,
    suggestions: ['Warm socks', 'Candles', 'A good cookbook', 'Board game'],
  },
  other: {
    title: 'My wish list',
    intro: 'Anything from here would be lovely.',
    surpriseMode: true,
    suggestions: [],
  },
};

/**
 * Picks an occasion on a new registry: fills the title, intro and surprise setting from its
 * template, but never overwrites text the owner has changed. A field still holding another
 * template's text counts as untouched.
 */
export const applyRegistryTemplate = (draft: WishListDraft, occasion: string): WishListDraft => {
  const template = REGISTRY_TEMPLATES[occasion];
  const templates = Object.values(REGISTRY_TEMPLATES);
  const untouched = (value: string, field: 'title' | 'intro') =>
    !value.trim() || templates.some(t => t[field] === value);
  if (!template) return { ...draft, occasion };

  return {
    ...draft,
    occasion,
    title: untouched(draft.title, 'title') ? template.title : draft.title,
    intro: untouched(draft.intro, 'intro') ? template.intro : draft.intro,
    surpriseMode: template.surpriseMode,
  };
};

/**
 * How far off the event is, for the guest page: "today", "tomorrow", "in 12 days", or "ended" once it
 * has passed. Works in calendar days so the answer doesn't flip at some hour of the day.
 */
export const eventCountdown = (
  eventDate?: string | null,
  today: Date = new Date()
): string | null => {
  if (!eventDate) return null;
  const days = differenceInCalendarDays(parseISO(eventDate), today);
  if (days < 0) return 'ended';
  if (days === 0) return 'today';
  if (days === 1) return 'tomorrow';
  return `in ${days} days`;
};

export const TRUMP_ACCOUNT_INFO_URL = 'https://www.irs.gov/trumpaccounts';

export interface WishListItem {
  id?: string;
  title: string;
  url?: string | null;
  imageUrl?: string | null;
  price?: string | null;
  priceStale?: boolean;
  store?: string | null;
  note?: string | null;
  quantity: number;
  priority?: boolean;
  section?: string | null;
  remainingQuantity?: number;
  claimed?: boolean;
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
  externalId?: string;
  occasion?: string | null;
  eventDate?: string | null;
  archived?: boolean;
  coverImageUrl?: string | null;
  passcodeProtected?: boolean;
  standalone?: boolean;
  title: string;
  intro?: string | null;
  visible: boolean;
  surpriseMode: boolean;
  shareAddress?: boolean;
  remindOwner?: boolean;
  items: WishListItem[];
  contributions: WishListContribution[];
}

/** The editable shape of a wish list, shared by the create and edit flows. */
export interface WishListDraft {
  occasion: string;
  eventDate: string;
  title: string;
  intro: string;
  visible: boolean;
  surpriseMode: boolean;
  shareAddress: boolean;
  remindOwner: boolean;
  items: WishListItem[];
  contributions: WishListContribution[];
}

export const emptyWishListDraft = (): WishListDraft => ({
  occasion: '',
  eventDate: '',
  title: 'Wish List',
  intro: '',
  visible: true,
  surpriseMode: true,
  shareAddress: false,
  remindOwner: true,
  items: [],
  contributions: [],
});

export const emptyWishListItem = (): WishListItem => ({
  title: '',
  url: '',
  price: '',
  note: '',
  quantity: 1,
});

/** Items grouped under their section heading, in the order each section first appears. */
export const groupItemsBySection = (
  items: WishListItem[]
): { section: string | null; items: WishListItem[] }[] => {
  const groups: { section: string | null; items: WishListItem[] }[] = [];
  for (const item of items) {
    const section = item.section?.trim() || null;
    const group = groups.find(g => g.section === section);
    if (group) group.items.push(item);
    else groups.push({ section, items: [item] });
  }
  return groups;
};

export const emptyWishListContribution = (): WishListContribution => ({
  kind: 'venmo',
  handle: '',
  label: '',
  suggestedAmount: '',
});

export const wishListToDraft = (wishList: WishList): WishListDraft => ({
  occasion: wishList.occasion || '',
  eventDate: wishList.eventDate || '',
  title: wishList.title || 'Wish List',
  intro: wishList.intro || '',
  visible: wishList.visible,
  surpriseMode: wishList.surpriseMode,
  shareAddress: wishList.shareAddress ?? false,
  remindOwner: wishList.remindOwner ?? true,
  items: wishList.items.map(item => ({
    id: item.id,
    title: item.title,
    url: item.url || '',
    imageUrl: item.imageUrl || '',
    price: item.price || '',
    store: item.store || '',
    note: item.note || '',
    quantity: item.quantity ?? 1,
    priority: item.priority ?? false,
    section: item.section || '',
  })),
  contributions: wishList.contributions.map(contribution => ({
    kind: contribution.kind,
    handle: contribution.handle,
    label: contribution.label || '',
    suggestedAmount: contribution.suggestedAmount || '',
  })),
});

export const isWishListDraftEmpty = (draft: WishListDraft): boolean =>
  draft.items.length === 0 && draft.contributions.length === 0;

/** Returns a message to show the host, or null when the draft is good to save. */
export const validateWishListDraft = (draft: WishListDraft): string | null => {
  if (draft.items.some(item => !item.title.trim())) {
    return 'Every gift idea needs a name';
  }
  if (draft.contributions.some(contribution => !contribution.handle.trim())) {
    return 'Every cash option needs a handle or instructions';
  }
  return null;
};

export const wishListDraftToInput = (draft: WishListDraft) => ({
  occasion: draft.occasion || null,
  eventDate: draft.eventDate || null,
  title: draft.title.trim() || 'Wish List',
  intro: draft.intro.trim() || null,
  visible: draft.visible,
  surpriseMode: draft.surpriseMode,
  shareAddress: draft.shareAddress,
  remindOwner: draft.remindOwner,
  items: draft.items.map(item => ({
    id: item.id || null,
    title: item.title.trim(),
    url: item.url?.trim() || null,
    imageUrl: item.imageUrl?.trim() || null,
    price: item.price?.trim() || null,
    store: item.store?.trim() || null,
    note: item.note?.trim() || null,
    quantity: item.quantity || 1,
    priority: item.priority ?? false,
    section: item.section?.trim() || null,
  })),
  contributions: draft.contributions.map(contribution => ({
    kind: contribution.kind,
    handle: contribution.handle.trim(),
    label: contribution.label?.trim() || null,
    suggestedAmount: contribution.suggestedAmount?.trim() || null,
  })),
});

export const UPSERT_WISH_LIST_MUTATION = `
  mutation UpsertWishList($input: UpsertWishListInput!) {
    upsertWishList(input: $input) {
      wishList {
        id
        externalId
      }
      errors
    }
  }
`;

export const PREVIEW_WISH_LIST_LINK_MUTATION = `
  mutation PreviewWishListLink($input: PreviewWishListLinkInput!) {
    previewWishListLink(input: $input) {
      preview {
        title
        imageUrl
        price
        store
      }
      errors
    }
  }
`;

export const WISH_LIST_FIELDS = `
  id
  externalId
  occasion
  eventDate
  archived
  coverImageUrl
  passcodeProtected
  standalone
  title
  intro
  visible
  surpriseMode
  shareAddress
  remindOwner
  items {
    id
    title
    url
    imageUrl
    price
    priceStale
    store
    note
    quantity
    priority
    section
    position
    remainingQuantity
    claimed
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

export const RESERVE_WISH_LIST_ITEM_MUTATION = `
  mutation ReserveWishListItem($input: ReserveWishListItemInput!) {
    reserveWishListItem(input: $input) {
      token
      wishListItem {
        id
        quantity
        remainingQuantity
        claimed
      }
      errors
    }
  }
`;

export const SET_WISH_LIST_RESERVATION_PURCHASED_MUTATION = `
  mutation SetWishListReservationPurchased($input: SetWishListReservationPurchasedInput!) {
    setWishListReservationPurchased(input: $input) {
      wishListItem {
        id
        claimed
      }
      errors
    }
  }
`;

export const RELEASE_WISH_LIST_RESERVATION_MUTATION = `
  mutation ReleaseWishListReservation($input: ReleaseWishListReservationInput!) {
    releaseWishListReservation(input: $input) {
      wishListItem {
        id
        quantity
        remainingQuantity
        claimed
      }
      errors
    }
  }
`;
