import { LucideIcon } from 'lucide-react';

export interface FeatureConfig {
  icon: LucideIcon;
  title: string;
  description: string;
}

export interface HeroConfig {
  headline: string;
  subheadline: string;
  imageUrl: string;
  imageAlt: string;
  ctaText: string;
  gradientClasses: string;
}

export interface CTAConfig {
  headline: string;
  description: string;
  ctaText: string;
  gradientClasses: string;
}

export interface EventLandingConfig {
  hero: HeroConfig;
  features: FeatureConfig[];
  cta: CTAConfig;
  occasion: string;
  theme: {
    primaryColor: string;
  };
}
