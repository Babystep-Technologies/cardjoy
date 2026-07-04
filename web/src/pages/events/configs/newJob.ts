import { Briefcase, Users, Sparkles } from 'lucide-react';
import { EventLandingConfig } from './types';

export const newJobConfig: EventLandingConfig = {
  hero: {
    headline: 'Celebrate Their New Beginning',
    subheadline:
      'Create a group card to congratulate them on their new job with encouragement and support from everyone who believes in them.',
    imageUrl:
      'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=1200&auto=format&fit=crop',
    imageAlt: 'Professional celebrating new job success',
    ctaText: 'Create New Job Card',
    gradientClasses: 'from-green-100 via-emerald-50 to-teal-50',
  },
  features: [
    {
      icon: Briefcase,
      title: 'Cheer on Their Success',
      description:
        'Collect messages of congratulations, encouragement, and advice from colleagues, mentors, and friends.',
    },
    {
      icon: Users,
      title: 'Easy to Organize',
      description:
        'Share via link—no signup required. Perfect for remote teams and distributed networks.',
    },
    {
      icon: Sparkles,
      title: 'A Confidence Boost',
      description:
        'Give them a keepsake full of support they can revisit as they navigate their new role.',
    },
  ],
  cta: {
    headline: 'Ready to Celebrate Their Career Move?',
    description: 'Create your new job group card in minutes. 100% free.',
    ctaText: 'Start Your New Job Card',
    gradientClasses: 'from-green-600 via-emerald-600 to-teal-600',
  },
  occasion: 'New Job',
  theme: {
    primaryColor: '#34d399',
  },
};
