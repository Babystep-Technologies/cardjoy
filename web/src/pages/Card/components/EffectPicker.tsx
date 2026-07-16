import React from 'react';
import { Heart, PartyPopper, Sparkles } from 'lucide-react';

import { isEffectSlug } from '@/components/effects';
import { StyleType } from '@/types/app';

interface EffectPickerProps {
  styles: StyleType[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}

const EFFECT_ICONS: Record<string, React.ElementType> = {
  confetti: PartyPopper,
  sparkles: Sparkles,
  hearts: Heart,
};

/**
 * Chips for the `effect` styles. Selecting the current chip clears it, which is
 * how a sender opts out of an animation entirely.
 */
const EffectPicker: React.FC<EffectPickerProps> = ({ styles, selectedId, onSelect }) => (
  <div className="flex flex-wrap gap-3">
    {styles
      .filter(style => isEffectSlug(style.value))
      .map(style => {
        const Icon = EFFECT_ICONS[style.value] ?? Sparkles;
        const isSelected = selectedId === style.id;

        return (
          <button
            key={style.id}
            type="button"
            onClick={() => onSelect(isSelected ? null : style.id)}
            aria-pressed={isSelected}
            className={`flex items-center gap-2 rounded-2xl border-2 px-4 py-2.5 text-sm font-semibold transition-all hover:scale-105 ${
              isSelected
                ? 'border-purple-500 bg-purple-100 text-purple-700 shadow-sm scale-105'
                : 'border-gray-200 bg-white text-gray-700 hover:border-purple-300 hover:bg-purple-50'
            }`}
          >
            <Icon className="h-4 w-4" />
            {style.name}
          </button>
        );
      })}
  </div>
);

export default EffectPicker;
