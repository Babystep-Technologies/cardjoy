import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, useReducedMotion } from 'motion/react';
import { ArrowLeft, Mail, Pencil, Send } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { CardEffect, isEffectSlug } from '@/components/effects';
import { StyleType } from '@/types/app';

interface OneOnOneMessage {
  text: string;
  displayName?: string;
  user?: { name?: string } | null;
}

interface OneOnOneCard {
  title: string;
  recipients?: string[] | null;
  coverImageUrl?: string | null;
  styles?: StyleType[] | null;
  messages?: OneOnOneMessage[] | null;
}

interface OneOnOneCardViewProps {
  card: OneOnOneCard;
  externalId: string;
  isCreator: boolean;
  onShareClick: () => void;
}

// A 1-on-1 card is a single message from one person to one person. Rather than the
// group card's scrollable message wall, the recipient is handed a sealed card that
// they tap to open — the message, and the sender's chosen effect, are the reveal.
const OneOnOneCardView: React.FC<OneOnOneCardViewProps> = ({
  card,
  externalId,
  isCreator,
  onShareClick,
}) => {
  const reducedMotion = useReducedMotion();
  const [opened, setOpened] = useState(false);

  const styleValue = (kind: string) => card.styles?.find(s => s.kind === kind)?.value;
  const cardColor = styleValue('background_color') || '#ffffff';
  const textColor = styleValue('text_color') || '#1a1a1a';
  const effectValue = styleValue('effect');
  const effect = isEffectSlug(effectValue) ? effectValue : null;

  const message = card.messages?.[0];
  const senderName = message?.displayName || message?.user?.name || 'Someone';
  const recipient = card.recipients?.[0];
  const coverImageUrl = card.coverImageUrl;

  // Under reduced motion the reveal is instant, but the tap-to-open moment stays —
  // the recipient still chooses to open the card, they just don't get the animation.
  const transition = reducedMotion
    ? { duration: 0 }
    : { type: 'spring' as const, stiffness: 200, damping: 22 };

  return (
    <div
      className="relative min-h-screen w-full overflow-hidden"
      style={{
        background: 'radial-gradient(120% 120% at 50% 0%, #2a2140 0%, #1a1526 45%, #0d0b14 100%)',
      }}
    >
      {/* The sender's effect fires when the card is opened. */}
      {opened && (
        <CardEffect effect={effect} scope="page" backgroundColor="#0d0b14" sectionCount={1} />
      )}

      {/* Creator bar — same convention as the group view. */}
      {isCreator && (
        <div className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-4 h-14 bg-[#0d0b14] border-b border-white/10">
          <Link
            to="/"
            className="flex items-center gap-2 text-white/70 hover:text-white transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            <span className="font-medium text-sm">Dashboard</span>
          </Link>
          <div className="flex items-center gap-2">
            <Link to={`/card/${externalId}/edit`}>
              <Button
                variant="outline"
                size="sm"
                className="gap-2 bg-transparent text-white border-white/30 hover:bg-white/10 hover:text-white"
              >
                <Pencil className="w-4 h-4" />
                Edit
              </Button>
            </Link>
            <Button
              size="sm"
              onClick={onShareClick}
              className="gap-2 bg-white text-black hover:bg-white/90"
            >
              <Send className="w-4 h-4" />
              Share
            </Button>
          </div>
        </div>
      )}

      <div className="relative z-[1] flex min-h-screen flex-col items-center justify-center px-6 py-20">
        {/* From — the sender leads, because a 1-on-1 card comes from one person. */}
        <motion.div
          layout
          className="mb-6 flex items-center gap-2 rounded-full bg-white/10 px-4 py-1.5 text-sm text-white/90 backdrop-blur"
        >
          <Mail className="h-4 w-4" />
          <span>
            From <span className="font-semibold">{senderName}</span>
          </span>
        </motion.div>

        {/* The card object on its stage. */}
        <motion.button
          type="button"
          onClick={() => !opened && setOpened(true)}
          aria-label={opened ? undefined : 'Open your card'}
          className={`relative w-full max-w-md rounded-3xl text-left shadow-2xl focus:outline-none focus-visible:ring-4 focus-visible:ring-white/40 ${
            opened ? 'cursor-default' : 'cursor-pointer'
          }`}
          style={{ backgroundColor: cardColor, color: textColor }}
          initial={false}
          animate={
            opened || reducedMotion
              ? { scale: 1, rotate: 0, y: 0 }
              : { scale: 0.96, rotate: -1.5, y: 0 }
          }
          whileHover={opened ? undefined : { scale: 1, rotate: 0, y: -6 }}
          transition={transition}
        >
          {coverImageUrl && (
            <div className="h-40 w-full overflow-hidden rounded-t-3xl sm:h-52">
              <img src={coverImageUrl} alt="" className="h-full w-full object-cover" />
            </div>
          )}

          <div className="px-6 py-8 sm:px-8 sm:py-10">
            {recipient && (
              <p className="mb-3 text-sm font-medium uppercase tracking-wide opacity-60">
                To {recipient}
              </p>
            )}

            <h1 className="text-3xl font-extrabold leading-tight sm:text-4xl">{card.title}</h1>

            {opened ? (
              <motion.div
                initial={reducedMotion ? false : { opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={reducedMotion ? { duration: 0 } : { delay: 0.15, duration: 0.4 }}
              >
                {message?.text && (
                  <p className="mt-6 whitespace-pre-line text-lg leading-relaxed sm:text-xl">
                    {message.text}
                  </p>
                )}
                <p className="mt-8 text-base italic opacity-80">— {senderName}</p>
              </motion.div>
            ) : (
              <p className="mt-6 text-base font-medium opacity-70">
                A card is waiting for you. Tap to open it.
              </p>
            )}
          </div>

          {/* Seal — only while closed. */}
          {!opened && (
            <div
              className="pointer-events-none absolute -bottom-4 left-1/2 flex h-14 w-14 -translate-x-1/2 items-center justify-center rounded-full shadow-lg"
              style={{ backgroundColor: textColor, color: cardColor }}
            >
              <Mail className="h-6 w-6" />
            </div>
          )}
        </motion.button>

        {!opened && (
          <motion.p
            className="mt-10 text-sm text-white/50"
            initial={reducedMotion ? false : { opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
          >
            Tap the card to open
          </motion.p>
        )}
      </div>
    </div>
  );
};

export default OneOnOneCardView;
