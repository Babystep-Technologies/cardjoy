/**
 * The layout gallery.
 *
 * Each card is a real `PanelPreview` at thumbnail scale rather than a drawing of
 * one, so what the user picks from is the same renderer that produces the
 * preview and, through it, the print. A hand-drawn thumbnail would be a third
 * copy of the geometry.
 *
 * Only templates matching the card's size are offered: a template's geometry is
 * drawn for one panel size, and the API refuses the mismatch anyway.
 */
import React from 'react';
import { Check } from 'lucide-react';
import { PanelPreview } from './PanelPreview';
import type {
  DesignConfig,
  EditorOptions,
  HolidayCardPhoto,
  HolidayCardTemplate,
  PanelName,
  Sticker,
} from '../types';

interface TemplatePickerProps {
  templates: HolidayCardTemplate[];
  selectedId: string;
  panel: PanelName;
  /** Drawn into the thumbnails, so switching shows the user their own card. */
  config: DesignConfig;
  options: EditorOptions;
  photos: HolidayCardPhoto[];
  stickers: Sticker[];
  onSelect: (template: HolidayCardTemplate) => void;
  /** Thumbnail width in pixels; the scale falls out of the template's own width. */
  width?: number;
}

export const TemplatePicker: React.FC<TemplatePickerProps> = ({
  templates,
  selectedId,
  panel,
  config,
  options,
  photos,
  stickers,
  onSelect,
  width = 168,
}) => (
  <div className="grid grid-cols-2 gap-3">
    {templates.map(template => {
      const scale = width / (template.widthInches + template.bleedInches * 2);
      const isSelected = template.id === selectedId;

      return (
        <button
          key={template.id}
          type="button"
          onClick={() => onSelect(template)}
          title={template.description ?? template.name}
          className={`group relative rounded-lg border-2 p-2 text-left transition-colors ${
            isSelected
              ? 'border-[var(--color-brand-yellow)] bg-amber-50/60'
              : 'border-transparent hover:border-gray-300 bg-gray-50'
          }`}
        >
          <div className="flex justify-center overflow-hidden rounded">
            <PanelPreview
              template={template}
              panel={panel}
              config={config}
              options={options}
              photos={photos}
              stickers={stickers}
              scale={scale}
            />
          </div>
          <div className="mt-2 flex items-center justify-between gap-1">
            <span className="truncate text-xs font-medium text-gray-800">{template.name}</span>
            {isSelected && (
              <Check className="w-3.5 h-3.5 shrink-0 text-[var(--color-brand-yellow)]" />
            )}
          </div>
        </button>
      );
    })}
  </div>
);
