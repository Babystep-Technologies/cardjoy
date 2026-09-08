/**
 * The stage indicator (#151).
 *
 * Visible stages, not a wizard that hides where you are: this flow ends in an
 * irreversible charge, and someone about to spend money should be able to see
 * how far along they are and step back without guessing. A completed stage is a
 * button; a stage ahead of the furthest one reached is not, because arriving at
 * "Review & pay" without having approved a proof is not a state this flow has.
 */
import React from 'react';
import { Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import { SEND_STAGES, STAGE_LABELS, type SendStage } from './types';

type StepperProps = {
  current: SendStage;
  /** The furthest stage unlocked so far. Anything beyond it is not navigable. */
  furthest: SendStage;
  onNavigate: (stage: SendStage) => void;
};

export const Stepper: React.FC<StepperProps> = ({ current, furthest, onNavigate }) => {
  const currentIndex = SEND_STAGES.indexOf(current);
  const furthestIndex = SEND_STAGES.indexOf(furthest);

  return (
    <nav aria-label="Send progress">
      <ol className="flex flex-wrap items-center gap-x-2 gap-y-2">
        {SEND_STAGES.map((stage, index) => {
          const done = index < currentIndex;
          const active = index === currentIndex;
          const reachable = index <= furthestIndex;

          return (
            <li key={stage} className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => reachable && onNavigate(stage)}
                disabled={!reachable}
                aria-current={active ? 'step' : undefined}
                className={cn(
                  'flex items-center gap-2 rounded-full py-1.5 pr-3 pl-1.5 text-sm transition-colors',
                  active && 'bg-gray-900 font-medium text-white',
                  !active && reachable && 'text-gray-700 hover:bg-gray-100',
                  !reachable && 'cursor-not-allowed text-gray-400'
                )}
              >
                <span
                  className={cn(
                    'flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold',
                    active && 'bg-white text-gray-900',
                    done && 'bg-green-600 text-white',
                    !active && !done && 'bg-gray-200 text-gray-600'
                  )}
                >
                  {done ? <Check className="h-3.5 w-3.5" /> : index + 1}
                </span>
                {STAGE_LABELS[stage]}
              </button>
              {index < SEND_STAGES.length - 1 && (
                <span aria-hidden="true" className="h-px w-6 bg-gray-300 sm:w-10" />
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
};

export default Stepper;
