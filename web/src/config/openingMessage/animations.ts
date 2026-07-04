import type { AnimationPreset } from '@/types/openingMessage';
import type { Variants } from 'motion/react';

export interface AnimationConfig {
  id: AnimationPreset;
  name: string;
  description: string;
  variants: Variants;
  useConfetti?: boolean;
}

export const ANIMATIONS: Record<AnimationPreset, AnimationConfig> = {
  fade_in: {
    id: 'fade_in',
    name: 'Fade In',
    description: 'Smooth opacity transition',
    variants: {
      hidden: { opacity: 0 },
      visible: {
        opacity: 1,
        transition: { duration: 1.2, ease: 'easeOut' },
      },
    },
  },
  typewriter: {
    id: 'typewriter',
    name: 'Typewriter',
    description: 'Letter-by-letter reveal',
    variants: {
      hidden: { opacity: 0 },
      visible: {
        opacity: 1,
        transition: {
          staggerChildren: 0.05,
        },
      },
    },
  },
  slide_up: {
    id: 'slide_up',
    name: 'Slide Up',
    description: 'Content slides from bottom',
    variants: {
      hidden: { opacity: 0, y: 60 },
      visible: {
        opacity: 1,
        y: 0,
        transition: { duration: 0.8, ease: [0.25, 0.46, 0.45, 0.94] },
      },
    },
  },
  confetti_pop: {
    id: 'confetti_pop',
    name: 'Confetti Pop',
    description: 'Scale animation with confetti burst',
    variants: {
      hidden: { opacity: 0, scale: 0.5 },
      visible: {
        opacity: 1,
        scale: 1,
        transition: {
          type: 'spring',
          stiffness: 200,
          damping: 15,
        },
      },
    },
    useConfetti: true,
  },
  bounce_in: {
    id: 'bounce_in',
    name: 'Bounce In',
    description: 'Spring animation with bounce',
    variants: {
      hidden: { opacity: 0, scale: 0.3, y: -50 },
      visible: {
        opacity: 1,
        scale: 1,
        y: 0,
        transition: {
          type: 'spring',
          stiffness: 260,
          damping: 20,
        },
      },
    },
  },
  sparkle: {
    id: 'sparkle',
    name: 'Sparkle',
    description: 'Blur reveal with glow effect',
    variants: {
      hidden: {
        opacity: 0,
        filter: 'blur(20px)',
      },
      visible: {
        opacity: 1,
        filter: 'blur(0px)',
        transition: { duration: 1.5, ease: 'easeOut' },
      },
    },
  },
};

export const ANIMATION_LIST = Object.values(ANIMATIONS);

// Typewriter character variant for letter-by-letter animation
export const typewriterCharVariant: Variants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1 },
};
