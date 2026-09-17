/**
 * One text region, edited in place.
 *
 * The region is a `<textarea>` carrying the *identical* computed style the print
 * renderer would give it — same family, same point-derived size, same line
 * height, same alignment, same wrapping — with all of the browser's own textarea
 * chrome reset away. Editing therefore happens on the thing that prints rather
 * than on a proxy for it, and nothing reflows when the user clicks away.
 *
 * It is a textarea *always*, not only while selected. Swapping a div for a
 * textarea on click looks tidier but does not work: the element the pointer went
 * down on is gone by the time the browser assigns focus, so focus lands on
 * `<body>` and the first thing the user types is silently dropped. Rendering one
 * element throughout lets the browser do its own focus handling, which it is
 * better at than we are.
 *
 * The region clips its overflow exactly as the print renderer does, so a
 * greeting too long for its box is visibly cut off here rather than discovered
 * on the proof.
 */
import React from 'react';
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

  return (
    <textarea
      value={content}
      readOnly={!onChange}
      // The model rejects anything longer, so stopping here means the user sees
      // the limit as they hit it rather than as a save the server refuses.
      maxLength={options.textMaxLength}
      placeholder={showGuides ? labelFor(region.id) : undefined}
      aria-label={labelFor(region.id)}
      onChange={event =>
        onChange?.(
          setTextPlacement(config, panel, region.id, {
            ...placement,
            content: event.target.value,
          })
        )
      }
      // Focus is the source of truth for "which region is being edited", so the
      // rail follows the caret rather than needing its own click handling.
      onFocus={onSelect}
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
        cursor: 'text',
        ...(selected ? { boxShadow: '0 0 0 2px var(--color-brand-yellow)' } : {}),
      }}
    />
  );
};

/**
 * A human label for a region id, used as the empty-state placeholder. Falls back
 * to the id itself with its underscores opened out, so a template that adds a
 * region nobody thought about still gets something readable rather than a blank
 * box.
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
