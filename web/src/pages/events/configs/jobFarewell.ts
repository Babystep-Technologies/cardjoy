import { Heart, Users, Gift } from 'lucide-react';
import { EventLandingConfig } from './types';

export const jobFarewellConfig: EventLandingConfig = {
  hero: {
    headline: "Show Them They're Not Forgotten",
    subheadline:
      "A layoff can shake someone's confidence. Rally the team and create a free group goodbye card packed with heartfelt messages to remind them just how valued they truly are.",
    imageUrl:
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=1200&auto=format&fit=crop',
    imageAlt: 'Colleagues coming together to support a coworker',
    ctaText: 'Create a Free Goodbye Card',
    gradientClasses: 'from-amber-50 via-orange-50 to-yellow-50',
  },
  features: [
    {
      icon: Users,
      title: 'Rally the Whole Team',
      description:
        'Share a link and let everyone add their message — no account needed. Perfect for remote teams and last-minute goodbyes.',
    },
    {
      icon: Heart,
      title: 'Remind Them of Their Worth',
      description:
        'Give them a keepsake full of genuine appreciation they can revisit while job hunting. The right words make all the difference.',
    },
    {
      icon: Gift,
      title: '100% Free',
      description:
        'No credits, no catch. Because right now, the best thing you can give them is your words.',
    },
  ],
  cta: {
    headline: 'Ready to Send Them Off With Love?',
    description: 'Create your free goodbye card in minutes. No account required to sign.',
    ctaText: 'Create a Free Goodbye Card',
    gradientClasses: 'from-amber-500 via-orange-500 to-yellow-500',
  },
  occasion: 'Farewell',
  theme: {
    primaryColor: '#f59e0b',
  },
};
