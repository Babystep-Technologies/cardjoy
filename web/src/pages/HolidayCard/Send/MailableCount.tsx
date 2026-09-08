/**
 * "38 of 42 selected contacts can be mailed" (#151).
 *
 * The one sentence in this flow that has to be impossible to miss, and the
 * reason it is a shared component rather than three copies: the four people who
 * *cannot* be mailed are the ones the user actually cares about, and a count
 * that only appears on the stage where you pick people is a count you have
 * stopped reading by the time you pay. It rides every stage.
 *
 * It changes colour rather than only wording, because a number that is fine and
 * a number that is quietly dropping four people should not look the same in
 * peripheral vision.
 */
import React from 'react';
import { AlertTriangle, CheckCircle2, Users } from 'lucide-react';
import { cn } from '@/lib/utils';
import { pluralize } from '@/lib/money';

type MailableCountProps = {
  selected: number;
  mailable: number;
  className?: string;
};

export const MailableCount: React.FC<MailableCountProps> = ({ selected, mailable, className }) => {
  const missing = selected - mailable;
  const allGood = selected > 0 && missing === 0;

  const Icon = selected === 0 ? Users : allGood ? CheckCircle2 : AlertTriangle;

  return (
    <div
      // Announced, but politely: this number moves on every tick of the picker,
      // and an assertive region would interrupt the checkbox label the user is
      // still listening to. It is a running total, not an alert.
      role="status"
      aria-live="polite"
      className={cn(
        'flex items-start gap-2.5 rounded-lg border px-4 py-3 text-sm',
        selected === 0 && 'border-gray-200 bg-white text-gray-600',
        allGood && 'border-green-200 bg-green-50 text-green-900',
        selected > 0 && missing > 0 && 'border-amber-300 bg-amber-50 text-amber-900',
        className
      )}
    >
      <Icon className="mt-0.5 h-4 w-4 shrink-0" />
      <p>
        {selected === 0 ? (
          'No recipients selected yet.'
        ) : (
          <>
            <strong className="font-semibold">
              {mailable} of {pluralize(selected, 'selected contact')}
            </strong>{' '}
            can be mailed
            {missing > 0
              ? ` — ${missing === 1 ? 'one is' : `${missing} are`} missing a deliverable address, and won't be sent a card.`
              : '.'}
          </>
        )}
      </p>
    </div>
  );
};

export default MailableCount;
