/**
 * The dashboard's holiday cards tab (#153).
 *
 * Sibling to `CardsList` and `InvitationsList`, but the tile answers a
 * different question. A group card is a link you share and then watch fill up;
 * a holiday card is forty physical objects in the postal system, and the thing
 * its owner wants off this screen is *did they arrive*. So the tile leads with
 * a send summary — "40 mailed · 2 failed" — and where that summary reports a
 * failure it is the loudest thing on the card, because a refunded piece is the
 * only one that asks anything of the reader.
 *
 * That also decides where a tile links. An unsent card opens the editor,
 * because there is nothing to track yet. A sent one opens the orders view,
 * because that is the question being asked. Both are always reachable — the
 * secondary link is never removed, only demoted.
 *
 * There is no delete here. `deleteHolidayCard` exists, but a card with orders
 * against it is history that has already been mailed and paid for, and
 * disposing of it correctly is not something to bolt onto a list tile.
 */
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AlertTriangle, Gift, Mailbox, Pencil, Plus, Send } from 'lucide-react';
import * as motion from 'motion/react-client';
import { format, parseISO } from 'date-fns';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import type { OrderSummary } from '@/pages/HolidayCard/types';

export interface DashboardHolidayCard {
  externalId: string;
  title: string | null;
  size: string;
  templateId: string;
  updatedAt: string;
  photos: { url: string | null }[];
  orderSummary: OrderSummary;
}

/** Just enough of a template to paint a tile that has no photo on it yet. */
export interface DashboardTemplate {
  id: string;
  name: string;
  front: { background: string };
}

/**
 * The one line that says what happened to this card.
 *
 * `total - failed` rather than a `mailed` count from the server, because
 * "mailed" is a statement about the pieces that were *not* rejected and the API
 * reports the rejections. Keeping the subtraction here means the two numbers on
 * screen always add up to the total the user was charged for.
 */
function sendSummary(summary: OrderSummary): { text: string; failed: number } {
  if (summary.total === 0) return { text: 'Not sent yet', failed: 0 };

  const mailed = summary.total - summary.failed;
  const parts = [`${mailed} mailed`];
  if (summary.inFlight > 0) parts.push(`${summary.inFlight} on the way`);
  if (summary.delivered > 0) parts.push(`${summary.delivered} delivered`);
  if (summary.failed > 0) parts.push(`${summary.failed} failed`);

  return { text: parts.join(' · '), failed: summary.failed };
}

function formatSentOn(iso: string | null): string | null {
  if (!iso) return null;
  try {
    return format(parseISO(iso), 'd MMM yyyy');
  } catch {
    return null;
  }
}

const HolidayCardTile: React.FC<{
  card: DashboardHolidayCard;
  template?: DashboardTemplate;
}> = ({ card, template }) => {
  const summary = sendSummary(card.orderSummary);
  const sent = card.orderSummary.total > 0;
  const sentOn = formatSentOn(card.orderSummary.lastOrderedAt);

  // The card's own first photo is the most recognisable thing about it. With no
  // photo yet there is still a template, and its print background is enough to
  // tell two drafts apart.
  const photoUrl = card.photos.find(photo => photo.url)?.url ?? null;
  const background = template?.front.background ?? '#F3F4F6';

  const primaryPath = sent
    ? `/holiday-card/${card.externalId}/orders`
    : `/holiday-card/${card.externalId}/edit`;

  return (
    <div className="flex flex-col overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm transition-shadow hover:shadow-md">
      <Link to={primaryPath} className="block">
        <div
          className="flex aspect-[3/2] items-center justify-center overflow-hidden"
          style={{
            backgroundColor: background,
            backgroundImage: photoUrl ? `url(${photoUrl})` : undefined,
            backgroundSize: 'cover',
            backgroundPosition: 'center',
          }}
        >
          {!photoUrl && (
            <div className="flex flex-col items-center gap-1.5 text-gray-500">
              <Gift className="h-8 w-8" style={{ color: 'var(--color-brand-yellow)' }} />
              <span className="text-xs font-medium">{template?.name ?? card.templateId}</span>
            </div>
          )}
        </div>
      </Link>

      <div className="flex flex-1 flex-col p-4">
        <Link to={primaryPath} className="block">
          <h3 className="truncate font-semibold text-gray-900">{card.title || 'Untitled card'}</h3>
        </Link>
        <p className="mt-0.5 text-xs text-gray-500">
          {card.size}
          {sentOn && ` · sent ${sentOn}`}
        </p>

        <div
          className={cn(
            'mt-3 flex items-start gap-1.5 rounded-md px-2.5 py-1.5 text-sm',
            summary.failed > 0
              ? 'bg-red-50 text-red-800'
              : sent
                ? 'bg-gray-50 text-gray-700'
                : 'bg-gray-50 text-gray-500'
          )}
        >
          {summary.failed > 0 ? (
            <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          ) : sent ? (
            <Mailbox className="mt-0.5 h-3.5 w-3.5 shrink-0" />
          ) : null}
          <span>{summary.text}</span>
        </div>

        <div className="mt-3 flex flex-wrap gap-2 pt-1">
          {sent ? (
            <>
              <Button asChild size="sm" className="flex-1">
                <Link to={`/holiday-card/${card.externalId}/orders`}>
                  <Mailbox className="mr-1.5 h-3.5 w-3.5" />
                  Track
                </Link>
              </Button>
              <Button asChild size="sm" variant="outline">
                <Link to={`/holiday-card/${card.externalId}/edit`}>
                  <Pencil className="h-3.5 w-3.5" />
                  <span className="sr-only">Edit this card</span>
                </Link>
              </Button>
            </>
          ) : (
            <>
              <Button asChild size="sm" className="flex-1">
                <Link to={`/holiday-card/${card.externalId}/edit`}>
                  <Pencil className="mr-1.5 h-3.5 w-3.5" />
                  Keep editing
                </Link>
              </Button>
              <Button asChild size="sm" variant="outline">
                <Link to={`/holiday-card/${card.externalId}/send`}>
                  <Send className="h-3.5 w-3.5" />
                  <span className="sr-only">Send this card by post</span>
                </Link>
              </Button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

interface HolidayCardsListProps {
  cards: DashboardHolidayCard[];
  templates: DashboardTemplate[];
  emptyTitle: string;
  emptyDescription: string;
}

export const HolidayCardsList: React.FC<HolidayCardsListProps> = ({
  cards,
  templates,
  emptyTitle,
  emptyDescription,
}) => {
  const navigate = useNavigate();
  const templatesById = React.useMemo(
    () => new Map(templates.map(template => [template.id, template])),
    [templates]
  );

  if (cards.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center space-y-6 py-12 text-center">
        <Gift className="h-20 w-20 opacity-80" style={{ color: 'var(--color-brand-yellow)' }} />
        <div className="space-y-2">
          <h2 className="text-2xl font-semibold text-gray-800">{emptyTitle}</h2>
          <p className="text-lg text-gray-500">{emptyDescription}</p>
        </div>
        <motion.button
          onClick={() => navigate('/holiday-card/new')}
          className="w-full rounded-xl bg-gradient-to-r from-[var(--color-brand-yellow)] to-[var(--color-brand-pink)] px-6 py-3 text-lg font-extrabold text-white shadow-xl sm:w-auto sm:text-xl"
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.9 }}
        >
          Create a Holiday Card
        </motion.button>
      </div>
    );
  }

  return (
    <div className="w-full">
      <motion.button
        onClick={() => navigate('/holiday-card/new')}
        className="mb-6 flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[var(--color-brand-yellow)] to-[var(--color-brand-pink)] px-6 py-4 text-xl font-extrabold text-white shadow-xl sm:w-auto"
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.9 }}
      >
        <Plus className="h-5 w-5" />
        Create a Holiday Card
      </motion.button>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        {cards.map(card => (
          <HolidayCardTile
            key={card.externalId}
            card={card}
            template={templatesById.get(card.templateId)}
          />
        ))}
      </div>
    </div>
  );
};
