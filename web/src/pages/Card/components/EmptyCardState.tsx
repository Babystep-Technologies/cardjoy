import React from 'react';

interface EmptyCardStateProps {
  /** The recipient(s) this card is for, already joined (e.g. "Sarah" or "Sarah & Tom"). */
  recipientName?: string;
  /** The creator sees a gentle "share it" nudge; everyone else sees a "write the first note" prompt. */
  isCreator: boolean;
  /** The card's text color, so the illustration and copy sit on any background. */
  textColor: string;
  /** Call to action (e.g. a link to the contribute flow). Rendered below the copy. */
  cta?: React.ReactNode;
}

/**
 * Friendly placeholder shown on a group card that has no messages yet, so it never
 * renders as a blank card. The recipient's name is woven into the copy when available.
 */
const EmptyCardState: React.FC<EmptyCardStateProps> = ({
  recipientName,
  isCreator,
  textColor,
  cta,
}) => {
  const heading = isCreator
    ? 'No messages yet'
    : recipientName
      ? `Be the first to write a message for ${recipientName}!`
      : 'Be the first to write a message!';

  const subtext = isCreator
    ? recipientName
      ? `Share your card so friends can write the first note for ${recipientName}.`
      : 'Share your card so friends can write the first note.'
    : 'This card is waiting for its very first note — yours will get it started.';

  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-6 px-4 text-center">
      {/* Envelope-and-sparkle illustration, tinted to the card's text color. */}
      <svg
        width="140"
        height="140"
        viewBox="0 0 140 140"
        fill="none"
        aria-hidden="true"
        className="w-32 h-32 sm:w-36 sm:h-36"
      >
        <rect
          x="18"
          y="40"
          width="104"
          height="74"
          rx="10"
          stroke={textColor}
          strokeWidth="3"
          style={{ opacity: 0.4 }}
        />
        <path
          d="M18 50l52 36 52-36"
          stroke={textColor}
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          style={{ opacity: 0.4 }}
        />
        {/* A blank note lifting out of the envelope, inviting the first message. */}
        <rect
          x="42"
          y="16"
          width="56"
          height="46"
          rx="6"
          fill="var(--color-brand-pink)"
          fillOpacity="0.12"
          stroke={textColor}
          strokeWidth="3"
          style={{ opacity: 0.55 }}
        />
        <line
          x1="52"
          y1="30"
          x2="88"
          y2="30"
          stroke={textColor}
          strokeWidth="3"
          strokeLinecap="round"
          style={{ opacity: 0.3 }}
        />
        <line
          x1="52"
          y1="40"
          x2="80"
          y2="40"
          stroke={textColor}
          strokeWidth="3"
          strokeLinecap="round"
          style={{ opacity: 0.3 }}
        />
        {/* Sparkles echoing the card title's flourish. */}
        <path
          d="M112 24l2.2 5.8L120 32l-5.8 2.2L112 40l-2.2-5.8L104 32l5.8-2.2z"
          fill="var(--color-brand-pink)"
        />
        <path
          d="M26 92l1.6 4.2L32 98l-4.4 1.6L26 104l-1.6-4.4L20 98l4.4-1.8z"
          fill="var(--color-brand-blue)"
        />
      </svg>

      <div className="space-y-3">
        <h2
          className="text-2xl sm:text-3xl font-bold text-balance leading-tight"
          style={{ color: textColor }}
        >
          {heading}
        </h2>
        <p
          className="text-base sm:text-lg leading-relaxed text-balance"
          style={{ color: textColor, opacity: 0.7 }}
        >
          {subtext}
        </p>
      </div>

      {cta}
    </div>
  );
};

export default EmptyCardState;
