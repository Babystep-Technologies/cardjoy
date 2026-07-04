import { GraduationCap, Users, Sparkles } from 'lucide-react';
import { EventLandingConfig } from './types';

export const graduationConfig: EventLandingConfig = {
  hero: {
    headline: 'Congratulate Your Graduate',
    subheadline:
      'Create a group graduation card filled with pride, encouragement, and congratulations from everyone who supported them.',
    imageUrl:
      'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&auto=format&fit=crop',
    imageAlt: 'Graduation celebration with cap and diploma',
    ctaText: 'Create Graduation Card',
    gradientClasses: 'from-yellow-100 via-orange-50 to-yellow-100',
  },
  features: [
    {
      icon: GraduationCap,
      title: 'Celebrate Their Achievement',
      description:
        'Gather messages of pride, encouragement, and advice from family, friends, and mentors.',
    },
    {
      icon: Users,
      title: 'From Near and Far',
      description:
        'Easy for everyone to sign—just share a link. Perfect for classmates scattered across the country.',
    },
    {
      icon: Sparkles,
      title: 'A Milestone Preserved',
      description:
        'Create a beautiful keepsake they can look back on as they start their next chapter.',
    },
  ],
  cta: {
    headline: 'Ready to Honor Their Hard Work?',
    description: 'Create your graduation group card in minutes. 100% free.',
    ctaText: 'Start Your Graduation Card',
    gradientClasses: 'from-yellow-600 via-orange-600 to-yellow-600',
  },
  occasion: 'Graduation',
  theme: {
    primaryColor: '#fbbf24',
  },
};
