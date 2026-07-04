import type { TemplateId } from '@/types/openingMessage';

export interface TemplateConfig {
  id: TemplateId;
  name: string;
  description: string;
  titleClassName: string;
  subtitleClassName: string;
  containerClassName: string;
}

export const TEMPLATES: Record<TemplateId, TemplateConfig> = {
  classic_centered: {
    id: 'classic_centered',
    name: 'Classic Centered',
    description: 'Elegant centered text with balanced proportions',
    containerClassName: 'flex flex-col items-center justify-center text-center',
    titleClassName: 'text-4xl md:text-6xl font-bold mb-4',
    subtitleClassName: 'text-xl md:text-2xl opacity-90',
  },
  bold_left: {
    id: 'bold_left',
    name: 'Bold Left',
    description: 'Left-aligned large typography with impact',
    containerClassName: 'flex flex-col items-start justify-center text-left px-8 md:px-16',
    titleClassName: 'text-5xl md:text-7xl font-black mb-4 leading-tight',
    subtitleClassName: 'text-lg md:text-xl opacity-80',
  },
  minimal_bottom: {
    id: 'minimal_bottom',
    name: 'Minimal Bottom',
    description: 'Clean text positioned at the bottom',
    containerClassName: 'flex flex-col items-center justify-end text-center pb-24',
    titleClassName: 'text-3xl md:text-5xl font-medium mb-3',
    subtitleClassName: 'text-base md:text-lg opacity-75',
  },
  elegant_split: {
    id: 'elegant_split',
    name: 'Elegant Split',
    description: 'Title and subtitle with distinct separation',
    containerClassName: 'flex flex-col items-center justify-center text-center gap-8',
    titleClassName: 'text-5xl md:text-7xl font-light tracking-wider',
    subtitleClassName: 'text-lg md:text-xl tracking-widest uppercase opacity-70',
  },
  playful_stacked: {
    id: 'playful_stacked',
    name: 'Playful Stacked',
    description: 'Fun stacked layout with varied sizes',
    containerClassName: 'flex flex-col items-center justify-center text-center',
    titleClassName: 'text-6xl md:text-8xl font-extrabold mb-2 -rotate-2',
    subtitleClassName: 'text-2xl md:text-3xl rotate-1 opacity-90',
  },
  modern_gradient: {
    id: 'modern_gradient',
    name: 'Modern Gradient',
    description: 'Contemporary style with gradient text effect',
    containerClassName: 'flex flex-col items-center justify-center text-center',
    titleClassName:
      'text-5xl md:text-7xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-white via-white/90 to-white/70',
    subtitleClassName: 'text-xl md:text-2xl opacity-80',
  },
};

export const TEMPLATE_LIST = Object.values(TEMPLATES);
