import { Heart, Users, Sparkles } from 'lucide-react';
import { EventLandingConfig } from './types';

export const valentinesDayConfig: EventLandingConfig = {
  hero: {
    headline: 'Share Love with Everyone',
    subheadline:
      "Create a group Valentine's card and collect heartfelt messages from everyone who cares.",
    imageUrl:
      'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=1200&auto=format&fit=crop',
    imageAlt: "Valentine's Day hearts and romance",
    ctaText: "Create Valentine's Card",
    gradientClasses: 'from-pink-100 via-purple-100 to-red-100',
  },
  features: [
    {
      icon: Heart,
      title: 'Collect Love Notes',
      description:
        'Invite friends, family, or coworkers to add their own heartfelt messages and photos.',
    },
    {
      icon: Users,
      title: 'Share with Anyone',
      description:
        "Send via link—no signup required. Everyone can contribute, even if they've never used CardJoy.",
    },
    {
      icon: Sparkles,
      title: 'Beautiful Designs',
      description:
        "Choose from stunning Valentine's designs that make your group card feel extra special.",
    },
  ],
  cta: {
    headline: 'Ready to Spread the Love?',
    description: "Create your Valentine's group card in minutes. 100% free.",
    ctaText: "Start Your Valentine's Card",
    gradientClasses: 'from-pink-600 via-purple-600 to-red-600',
  },
  occasion: "Valentine's Day",
  theme: {
    primaryColor: '#ff69d5',
  },
};
