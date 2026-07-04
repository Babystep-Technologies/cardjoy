import type { TemplateId } from '@/types/openingMessage';
import type { TemplateProps } from './types';
import { ClassicCentered } from './ClassicCentered';
import { BoldLeft } from './BoldLeft';
import { MinimalBottom } from './MinimalBottom';
import { ElegantSplit } from './ElegantSplit';
import { PlayfulStacked } from './PlayfulStacked';
import { ModernGradient } from './ModernGradient';

export { ClassicCentered } from './ClassicCentered';
export { BoldLeft } from './BoldLeft';
export { MinimalBottom } from './MinimalBottom';
export { ElegantSplit } from './ElegantSplit';
export { PlayfulStacked } from './PlayfulStacked';
export { ModernGradient } from './ModernGradient';
export type { TemplateProps } from './types';

type TemplateComponent = React.ComponentType<TemplateProps>;

export const TEMPLATE_COMPONENTS: Record<TemplateId, TemplateComponent> = {
  classic_centered: ClassicCentered,
  bold_left: BoldLeft,
  minimal_bottom: MinimalBottom,
  elegant_split: ElegantSplit,
  playful_stacked: PlayfulStacked,
  modern_gradient: ModernGradient,
};
