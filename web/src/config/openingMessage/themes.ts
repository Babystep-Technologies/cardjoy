import type { FontPreset } from '@/types/openingMessage';

export interface FontConfig {
  id: FontPreset;
  name: string;
  fontFamily: string;
  className: string;
}

export const FONTS: Record<FontPreset, FontConfig> = {
  poppins: {
    id: 'poppins',
    name: 'Poppins',
    fontFamily: "'Poppins', sans-serif",
    className: 'font-sans',
  },
  playfair: {
    id: 'playfair',
    name: 'Playfair Display',
    fontFamily: "'Playfair Display', serif",
    className: 'font-serif',
  },
  montserrat: {
    id: 'montserrat',
    name: 'Montserrat',
    fontFamily: "'Montserrat', sans-serif",
    className: 'font-sans tracking-wide',
  },
  dancing_script: {
    id: 'dancing_script',
    name: 'Dancing Script',
    fontFamily: "'Dancing Script', cursive",
    className: 'font-cursive',
  },
};

export const FONT_LIST = Object.values(FONTS);

// Preset color palettes for text
export const TEXT_COLORS = [
  { name: 'White', value: '#FFFFFF' },
  { name: 'Cream', value: '#FFF8E7' },
  { name: 'Gold', value: '#FFD700' },
  { name: 'Rose', value: '#FFB6C1' },
  { name: 'Lavender', value: '#E6E6FA' },
  { name: 'Mint', value: '#98FB98' },
  { name: 'Sky', value: '#87CEEB' },
  { name: 'Charcoal', value: '#2C3E50' },
];
