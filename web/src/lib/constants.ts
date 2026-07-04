export const APP_TOKEN_KEY = `cardjoy_${import.meta.env.VITE_ENV}_token`;
export const POSTHOG_HOST = 'https://us.i.posthog.com';
export const CREDIT_PLANS = [
  {
    title: 'Single Card',
    price: '$3',
    credits: '1 credit',
    use: 'Perfect for a special moment or last minute vibes',
    highlight: false,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_1_CREDIT!,
  },
  {
    title: '5-Card Bundle',
    price: '$12',
    credits: '5 credits',
    use: 'Great for multiple celebrations and events',
    highlight: false,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_5_CREDITS!,
  },
  {
    title: '10-Card Bundle',
    price: '$20',
    credits: '10 credits',
    use: 'Best for families, squads, and frequent celebrations',
    highlight: true,
    priceId: import.meta.env.VITE_STRIPE_PRICE_ID_10_CREDITS!,
  },
];
