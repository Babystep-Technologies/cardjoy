// Opening Message Configuration Types

export type TemplateId =
  | 'classic_centered'
  | 'bold_left'
  | 'minimal_bottom'
  | 'elegant_split'
  | 'playful_stacked'
  | 'modern_gradient';

export type AnimationPreset =
  | 'fade_in'
  | 'typewriter'
  | 'slide_up'
  | 'confetti_pop'
  | 'bounce_in'
  | 'sparkle';

export type FontPreset = 'poppins' | 'playfair' | 'montserrat' | 'dancing_script';

export type BackgroundType = 'color' | 'gradient' | 'image';

export interface ImageTransform {
  x: number; // X offset percentage (-50 to 50)
  y: number; // Y offset percentage (-50 to 50)
  scale: number; // Scale factor (0.5 to 3.0)
  rotation: number; // Degrees (0 to 360)
}

export interface TextTransform {
  x: number; // X position percentage (0 = left, 50 = center, 100 = right)
  y: number; // Y position percentage (0 = top, 50 = center, 100 = bottom)
  rotation: number; // Degrees (-180 to 180)
  scale: number; // Scale factor (0.5 to 2.0)
}

export interface OpeningMessageText {
  title: string;
  subtitle?: string | null;
  transform?: TextTransform;
}

export interface OpeningMessageTheme {
  font: FontPreset;
  text_color: string;
}

export interface OpeningMessageBackground {
  type: BackgroundType;
  value: string;
  overlay_opacity?: number;
  image_transform?: ImageTransform;
}

export interface OpeningMessageAnimation {
  preset: AnimationPreset;
  duration_ms: number;
}

export interface OpeningMessageConfig {
  template_id: TemplateId;
  text: OpeningMessageText;
  theme?: OpeningMessageTheme;
  background?: OpeningMessageBackground;
  animation?: OpeningMessageAnimation;
}

// Default configuration for new opening messages
export const DEFAULT_OPENING_MESSAGE_CONFIG: OpeningMessageConfig = {
  template_id: 'classic_centered',
  text: { title: "You're Invited!", subtitle: null },
  theme: { font: 'poppins', text_color: '#FFFFFF' },
  background: {
    type: 'gradient',
    value: 'from-purple-400 via-pink-400 to-blue-400',
    overlay_opacity: 0.0,
  },
  animation: { preset: 'fade_in', duration_ms: 1800 },
};
