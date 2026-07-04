import { Cake, Users, Sparkles } from 'lucide-react';
import { EventLandingConfig } from './types';

export const birthdayConfig: EventLandingConfig = {
  hero: {
    headline: 'Make Their Birthday Unforgettable',
    subheadline:
      'Create a group birthday card and collect heartfelt messages, photos, and wishes from everyone who cares.',
    imageUrl:
      'https://images.unsplash.com/photo-1558636508-e0db3814bd1d?w=1200&auto=format&fit=crop',
    imageAlt: 'Birthday celebration with cake and candles',
    ctaText: 'Create Birthday Card',
    gradientClasses: 'from-pink-100 via-purple-100 to-pink-100',
  },
  features: [
    {
      icon: Cake,
      title: 'Collect Birthday Wishes',
      description:
        'Invite friends, family, and colleagues to add their own birthday messages, photos, and memories.',
    },
    {
      icon: Users,
      title: 'Share with Everyone',
      description:
        'Send via link—no signup required. Everyone can contribute, even from across the world.',
    },
    {
      icon: Sparkles,
      title: "A Gift They'll Treasure",
      description: 'Create a beautiful digital keepsake they can revisit anytime, anywhere.',
    },
  ],
  cta: {
    headline: 'Ready to Make Their Day Special?',
    description: 'Create your birthday group card in minutes. 100% free.',
    ctaText: 'Start Your Birthday Card',
    gradientClasses: 'from-pink-600 via-purple-600 to-pink-600',
  },
  occasion: 'Birthday',
  theme: {
    primaryColor: '#e879f9',
  },
};
