/**
 * One text region, edited in place.
 *
 * When selected the region swaps a `<div>` for a `<textarea>` carrying the
 * *identical* computed style — same family, same point-derived size, same line
 * height, same alignment, same wrapping. That is what keeps the editing state
 * honest: if the textarea laid text out even slightly differently, a message
 * would reflow the moment the user clicked away, which is precisely the
 * "close enough" preview this feature exists to avoid.
 *
 * The region clips its overflow exactly as the print renderer does, so a
 * greeting too long for its box is visibly cut off here rather than discovered
 * on the proof.
 */
import React, { useEffect, useRef } from 'react';
import type { CSSProperties } from 'react';
import { setTextPlacement, textPlacement } from '../design';
import type {
  DesignConfig,
  EditorOptions,
  PanelName,
  TextRegion as TextRegionSpec,
} from '../types';

interface TextRegionProps {
  region: TextRegionSpec;
  panel: PanelName;
  config: DesignConfig;
  options: EditorOptions;
  /** The computed print style, from `geometry.textStyle`. */
  style: CSSProperties;
  selected: boolean;
  showGuides: boolean;
  onSelect: () => void;
  onChange?: (next: DesignConfig) => void;
}

export const TextRegion: React.FC<TextRegionProps> = ({
  region,
  panel,
  config,
  options,
  style,
  selected,
  showGuides,
  onSelect,
  onChange,
}) => {
  const placement = textPlacement(config, panel, region.id);
  const content = placement?.content ?? '';
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (selected) textareaRef.current?.focus();
  }, [selected]);

  if (selected && onChange) {
    return (
      <textarea
        ref={textareaRef}
        value={content}
        // The model rejects anything longer, so stopping here means the user
        // sees the limit as they hit it rather than as a rejected save.
        maxLength={options.textMaxLength}
        onChange={event =>
          onChange(
            setTextPlacement(config, panel, region.id, {
              ...placement,
              content: event.target.value,
            })
          )
        }
        onPointerDown={event => event.stopPropagation()}
        style={{
          ...style,
          // Reset the browser's own textarea chrome so only the print style shows.
          background: 'transparent',
          border: 'none',
          outline: 'none',
          padding: 0,
          margin: 0,
          resize: 'none',
          overflow: 'hidden',
          boxShadow: '0 0 0 2px var(--color-brand-yellow)',
        }}
      />
    );
  }

  return (
    <div
      style={{ ...style, cursor: 'text' }}
      onPointerDown={event => {
        event.stopPropagation();
        onSelect();
      }}
    >
      {content || (showGuides ? <PlaceholderHint region={region} /> : '')}
    </div>
  );
};

/**
 * What an empty region says before anyone writes in it. Rendered at the region's
 * own type size and colour-muted, so it reads as an invitation rather than as
 * content the user might mistake for something that prints.
 */
const PlaceholderHint: React.FC<{ region: TextRegionSpec }> = ({ region }) => (
  <span className="opacity-40 select-none">{labelFor(region.id)}</span>
);

/**
 * A human label for a region id. Falls back to the id itself with its
 * underscores opened out, so a template that adds a region nobody thought about
 * still gets something readable rather than a blank box.
 */
function labelFor(id: string): string {
  const labels: Record<string, string> = {
    greeting: 'Your greeting',
    message: 'Your message',
    signoff: 'Sign off',
    names: 'Your names',
  };

  return labels[id] ?? id.replace(/_/g, ' ');
}
