/**
 * Debounced autosave for the design document.
 *
 * The user is arranging photos, not filling in a form. There is no natural
 * moment to press Save, and losing an afternoon's arranging to a refresh is
 * unacceptable — so every change schedules a save and the UI reports where that
 * save got to.
 *
 * Three things this has to get right:
 *
 *  - **Wholesale, not merged.** `updateHolidayCard` replaces `design_config`, so
 *    the caller holds the document and this sends all of it. That is what makes
 *    deletion expressible at all.
 *  - **No redundant saves.** The document is compared against what the server
 *    last acknowledged, so clicking into a text region and back out sends
 *    nothing.
 *  - **No lost trailing edit.** If the document changes while a save is in
 *    flight, another save is scheduled the moment that one lands. Dropping it
 *    would leave the user looking at "Saved" over unsaved work, which is worse
 *    than showing an error.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import { useMutation } from '@apollo/client';
import { UPDATE_HOLIDAY_CARD } from '../queries';
import { designsEqual } from '../design';
import type { DesignConfig, HolidayCard } from '../types';

const DEBOUNCE_MS = 1200;

export type SaveState = 'idle' | 'pending' | 'saving' | 'saved' | 'error';

interface Draft {
  config: DesignConfig;
  templateId: string;
  title: string | null;
}

interface UseAutosaveOptions {
  externalId: string;
  draft: Draft;
  /** What the server last acknowledged. Saves are skipped while it matches. */
  saved: Draft | null;
  /**
   * False until the card has loaded and the working copy has been seeded.
   *
   * Without this the hook would run against the page's initial empty state,
   * where there is no `saved` to compare against and so everything looks dirty.
   * On a slow load that debounce fires before the seed lands and posts a blank
   * document with an empty `templateId` — which is to say it overwrites the
   * user's card with nothing.
   */
  enabled: boolean;
  onSaved: (card: HolidayCard) => void;
}

interface UpdateResponse {
  updateHolidayCard: {
    holidayCard: HolidayCard | null;
    errors: string[];
  };
}

export function useAutosave({ externalId, draft, saved, enabled, onSaved }: UseAutosaveOptions) {
  const [state, setState] = useState<SaveState>('idle');
  const [errors, setErrors] = useState<string[]>([]);
  const [update] = useMutation<UpdateResponse>(UPDATE_HOLIDAY_CARD);

  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const inFlight = useRef(false);
  // Read inside the timer callback, so a save always sends the newest document
  // rather than whatever was current when the timer was set.
  const latest = useRef(draft);
  latest.current = draft;
  const savedRef = useRef(saved);
  savedRef.current = saved;
  const onSavedRef = useRef(onSaved);
  onSavedRef.current = onSaved;

  const dirty = enabled && (!saved || !sameDraft(draft, saved));
  const enabledRef = useRef(enabled);
  enabledRef.current = enabled;

  const flush = useCallback(async () => {
    if (inFlight.current || !enabledRef.current) return;

    const pending = latest.current;
    const acknowledged = savedRef.current;
    if (acknowledged && sameDraft(pending, acknowledged)) {
      setState('saved');
      return;
    }

    inFlight.current = true;
    setState('saving');
    try {
      const result = await update({
        variables: {
          externalId,
          title: pending.title,
          templateId: pending.templateId,
          designConfig: pending.config,
        },
      });

      const payload = result.data?.updateHolidayCard;
      if (payload?.errors?.length) {
        // Surfaced rather than swallowed: a rejected document means the editor
        // built something the model will not store, and the user is the only
        // one who can decide what to do about it.
        setErrors(payload.errors);
        setState('error');
        return;
      }

      setErrors([]);
      if (payload?.holidayCard) onSavedRef.current(payload.holidayCard);
      // Whether this counts as "saved" depends on what has happened since the
      // request went out; the effect below re-fires if the draft moved on.
      setState(sameDraft(latest.current, pending) ? 'saved' : 'pending');
    } catch {
      setErrors(['Could not reach the server. Your changes are still here — retrying.']);
      setState('error');
    } finally {
      inFlight.current = false;
    }
  }, [externalId, update]);

  useEffect(() => {
    if (!dirty) return;

    setState(current => (current === 'saving' ? current : 'pending'));
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      void flush();
    }, DEBOUNCE_MS);

    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
    // `draft` is compared by value through `dirty`; depending on the object
    // identity would restart the debounce on every render.
  }, [dirty, draft, flush]);

  // A refresh or tab close mid-debounce would otherwise drop the last edit. This
  // is best-effort — browsers do not guarantee an async request survives unload
  // — so it is a backstop for the debounce window, not the save path.
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (!dirty) return;
      event.preventDefault();
      event.returnValue = '';
    };

    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);

  return { state, errors, dirty, saveNow: flush };
}

function sameDraft(a: Draft, b: Draft): boolean {
  return a.templateId === b.templateId && a.title === b.title && designsEqual(a.config, b.config);
}
