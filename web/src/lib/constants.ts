export const APP_TOKEN_KEY = `cardjoy_${import.meta.env.VITE_ENV}_token`;
export const POSTHOG_HOST = 'https://us.i.posthog.com';
export const GITHUB_REPO_URL = 'https://github.com/Babystep-Technologies/cardjoy';
export const CREDIT_PLANS = [
  {
    title: 'Single Credit',
    price: '$3',
    credits: '1 credit',
    use: 'One card or invitation — perfect for a last-minute moment',
    highlight: false,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_1_CREDIT!,
  },
  {
    title: '5-Credit Bundle',
    price: '$12',
    credits: '5 credits',
    use: 'Five cards or invitations for multiple celebrations',
    highlight: false,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_5_CREDITS!,
  },
  {
    title: '10-Credit Bundle',
    price: '$20',
    credits: '10 credits',
    use: 'Ten cards or invitations for families, squads, and frequent celebrations',
    highlight: true,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_10_CREDITS!,
  },
];
