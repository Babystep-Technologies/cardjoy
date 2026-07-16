import React, { useEffect, useMemo } from 'react';

import { CardEffect } from '@/components/effects';
import type { EffectSlug } from '@/components/effects';

interface CardPreviewProps {
  title: string;
  recipient: string;
  text: string;
  displayName: string;
  coverImage: string | Blob | null;
  backgroundColor: string;
  textColor: string;
  effect: EffectSlug | null;
}

/**
 * A miniature of the card as the recipient will receive it, mirroring the hero
 * of `pages/Card/Viewable.tsx` — cover image fading into the background color,
 * title, then the sender's note.
 */
const CardPreview: React.FC<CardPreviewProps> = ({
  title,
  recipient,
  text,
  displayName,
  coverImage,
  backgroundColor,
  textColor,
  effect,
}) => {
  const coverSrc = useMemo(
    () => (coverImage instanceof Blob ? URL.createObjectURL(coverImage) : coverImage),
    [coverImage]
  );

  // Object URLs are only freed by revoking them.
  useEffect(() => {
    if (coverImage instanceof Blob && coverSrc) {
      return () => URL.revokeObjectURL(coverSrc);
    }
  }, [coverImage, coverSrc]);

  return (
    <div
      className="relative overflow-hidden rounded-3xl border-4 border-white shadow-xl"
      style={{ backgroundColor }}
    >
      {/* Remounting on effect change replays the animation from the start. */}
      <CardEffect key={effect ?? 'none'} effect={effect} scope="preview" />

      {coverSrc && (
        <div className="relative h-40">
          <img src={coverSrc} alt="" className="h-full w-full object-cover" />
          <div
            className="absolute inset-0"
            style={{
              background: `linear-gradient(to bottom, ${backgroundColor}40 0%, ${backgroundColor}cc 70%, ${backgroundColor} 100%)`,
            }}
          />
        </div>
      )}

      <div className={`relative z-[1] px-6 pb-8 text-center ${coverSrc ? 'pt-2' : 'pt-8'}`}>
        <h3
          className="font-heading text-2xl leading-tight font-bold break-words"
          style={{ color: textColor }}
        >
          {title || 'Your card title'}
        </h3>

        <p className="mt-3 text-sm font-semibold" style={{ color: textColor, opacity: 0.7 }}>
          To {recipient || '…'}
        </p>

        <p
          className="mt-5 text-sm leading-relaxed break-words whitespace-pre-wrap"
          style={{ color: textColor, opacity: 0.9 }}
        >
          {text || 'Your message will appear here.'}
        </p>

        {displayName && (
          <p className="mt-5 text-sm font-semibold" style={{ color: textColor, opacity: 0.7 }}>
            — {displayName}
          </p>
        )}
      </div>
    </div>
  );
};

export default CardPreview;
