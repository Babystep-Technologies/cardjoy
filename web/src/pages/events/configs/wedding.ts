import { Heart, Users, Sparkles } from 'lucide-react';
import { EventLandingConfig } from './types';

export const weddingConfig: EventLandingConfig = {
  hero: {
    headline: 'Celebrate Their Forever',
    subheadline:
      'Create a group wedding card and gather congratulations from all their loved ones on their special day.',
    imageUrl:
      'https://images.unsplash.com/photo-1519741497674-611481863552?w=1200&auto=format&fit=crop',
    imageAlt: 'Beautiful wedding celebration',
    ctaText: 'Create Wedding Card',
    gradientClasses: 'from-rose-100 via-pink-50 to-white',
  },
  features: [
    {
      icon: Heart,
      title: 'Gather Congratulations',
      description:
        'Collect heartfelt messages, photos, and well-wishes from family and friends near and far.',
    },
    {
      icon: Users,
      title: 'From All Your Guests',
      description: 'Easy for everyone to sign—just share a link. No signup or app required.',
    },
    {
      icon: Sparkles,
      title: 'A Keepsake Forever',
      description: 'A beautiful digital memory they can treasure for years to come.',
    },
  ],
  cta: {
    headline: 'Ready to Create Something Special?',
    description: 'Create your wedding group card in minutes. 100% free.',
    ctaText: 'Start Your Wedding Card',
    gradientClasses: 'from-rose-600 via-pink-600 to-rose-600',
  },
  occasion: 'Wedding',
  theme: {
    primaryColor: '#fb7185',
  },
};
