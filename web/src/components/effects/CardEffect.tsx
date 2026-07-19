import { useEffect, useMemo, useRef } from 'react';
import { useReducedMotion } from 'motion/react';

import ConfettiScene, { type ConfettiSceneHandle } from '@/components/ConfettiScene';
import { Confetti } from '@/components/magicui/confetti';
import { getBrandColors } from '@/lib/utils';
import HeartField from './HeartField';
import SparkleField from './SparkleField';
import type { EffectSlug } from './types';

interface CardEffectProps {
  /** Effect slug from the card's `effect` style. `null` falls back to confetti. */
  effect: EffectSlug | null;
  /**
   * `page` covers the viewport (a card being read); `preview` fills the nearest
   * positioned ancestor (the preview box on the creation page).
   */
  scope: 'page' | 'preview';
  /** Confetti only, `page` scope: tints the scene and drives per-section bursts. */
  backgroundColor?: string;
  sectionCount?: number;
}

/**
 * Renders the animation a sender chose for their card, in either the reader's
 * viewport or the creation page's preview box.
 *
 * Confetti has two implementations by necessity: the three.js `ConfettiScene`
 * is a fixed full-screen canvas and would escape a preview box, so the preview
 * uses canvas-confetti scoped to its own canvas instead.
 */
const CardEffect: React.FC<CardEffectProps> = ({
  effect,
  scope,
  backgroundColor = '#ffffff',
  sectionCount = 0,
}) => {
  const confettiSceneRef = useRef<ConfettiSceneHandle>(null);
  const reducedMotion = useReducedMotion();
  const wantsPageConfetti = scope === 'page' && (effect === null || effect === 'confetti');

  // magicui's <Confetti> re-fires whenever this options object's identity
  // changes. Without memoizing, a fresh object every render (the parent
  // re-renders on each keystroke of the creation form) would burst confetti on
  // every keypress. Stable identity fires once; CardPreview's `key` remount
  // replays it when the effect actually changes.
  const previewConfettiOptions = useMemo(
    () => ({
      colors: getBrandColors(),
      particleCount: 70,
      spread: 80,
      startVelocity: 28,
      scalar: 0.7,
      origin: { x: 0.5, y: 0.6 },
    }),
    []
  );

  // Burst once the renderer finishes loading — it is imported lazily, so the
  // ref is not populated on mount.
  useEffect(() => {
    if (!wantsPageConfetti || reducedMotion) return;
    let cancelled = false;
    const tryBurst = () => {
      if (cancelled) return;
      if (confettiSceneRef.current) {
        confettiSceneRef.current.triggerBurst(1.5);
      } else {
        setTimeout(tryBurst, 200);
      }
    };
    const timer = setTimeout(tryBurst, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [wantsPageConfetti, reducedMotion]);

  if (reducedMotion) return null;

  if (wantsPageConfetti) {
    return (
      <ConfettiScene
        ref={confettiSceneRef}
        backgroundColor={backgroundColor}
        sectionCount={sectionCount}
      />
    );
  }

  if (scope === 'preview' && (effect === null || effect === 'confetti')) {
    return (
      <Confetti
        className="pointer-events-none absolute inset-0 z-20 h-full w-full"
        options={previewConfettiOptions}
      />
    );
  }

  const positioning = scope === 'page' ? 'fixed z-10' : 'z-20';

  if (effect === 'sparkles') return <SparkleField className={positioning} />;
  if (effect === 'hearts') return <HeartField className={positioning} />;

  return null;
};

export default CardEffect;
