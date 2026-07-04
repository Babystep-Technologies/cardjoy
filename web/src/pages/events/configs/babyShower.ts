import { Baby, Users, Heart } from 'lucide-react';
import { EventLandingConfig } from './types';

export const babyShowerConfig: EventLandingConfig = {
  hero: {
    headline: 'Welcome the New Baby',
    subheadline:
      'Create a group baby shower card filled with love, advice, and well wishes from everyone who cares.',
    imageUrl:
      'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=1200&auto=format&fit=crop',
    imageAlt: 'Baby shower celebration with soft pastels',
    ctaText: 'Create Baby Shower Card',
    gradientClasses: 'from-blue-100 via-cyan-50 to-pink-50',
  },
  features: [
    {
      icon: Baby,
      title: 'Messages for Baby',
      description: 'Collect sweet messages, photos, and parenting wisdom from friends and family.',
    },
    {
      icon: Users,
      title: 'Easy to Share',
      description: 'Send via link—everyone can contribute from anywhere, no signup needed.',
    },
    {
      icon: Heart,
      title: 'A Precious Memory',
      description: 'Create a keepsake they can share with their little one as they grow up.',
    },
  ],
  cta: {
    headline: 'Ready to Celebrate the New Arrival?',
    description: 'Create your baby shower group card in minutes. 100% free.',
    ctaText: 'Start Your Baby Shower Card',
    gradientClasses: 'from-blue-600 via-cyan-600 to-pink-600',
  },
  occasion: 'Baby Shower',
  theme: {
    primaryColor: '#67e8f9',
  },
};
