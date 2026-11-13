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
  standalone?: boolean;
  title: string;
  intro?: string | null;
  visible: boolean;
  surpriseMode: boolean;
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
  items: wishList.items.map(item => ({
    id: item.id,
    title: item.title,
    url: item.url || '',
    imageUrl: item.imageUrl || '',
    price: item.price || '',
    store: item.store || '',
    note: item.note || '',
    quantity: item.quantity ?? 1,
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
  items: draft.items.map(item => ({
    id: item.id || null,
    title: item.title.trim(),
    url: item.url?.trim() || null,
    imageUrl: item.imageUrl?.trim() || null,
    price: item.price?.trim() || null,
    store: item.store?.trim() || null,
    note: item.note?.trim() || null,
    quantity: item.quantity || 1,
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
  standalone
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
