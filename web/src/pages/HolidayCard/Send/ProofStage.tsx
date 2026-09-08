/**
 * Stage 2 — look at what will actually be printed, and say so (#151).
 *
 * The proof is the PDF our print partner produces from the same renderer that
 * will print the card, so it is the last honest chance to catch a cropped face
 * or a typo. Three rules shape this screen:
 *
 * 1. **Approval is an affirmative act.** A checkbox that says what it means and
 *    a button that commits it — never an implied consent from pressing Next.
 *    The user is about to authorise printing something they cannot recall.
 * 2. **A stale proof cannot be approved.** `proofCurrent` goes false when the
 *    design moved after the render *or* when the PDF link has aged out
 *    (`HolidayCard::PROOF_MAX_AGE`). The server rejects an approval either way;
 *    finding that out here, with a regenerate button, is far better than
 *    finding it out at the payment step.
 * 3. **The old proof stays on screen while it is stale**, labelled as such,
 *    rather than being blanked. It is still what the user last looked at, and
 *    hiding it makes the regenerate button feel like it lost their card.
 *
 * The PDF is embedded *and* linked. Some browsers and most mobile ones refuse
 * to render a cross-origin PDF in an iframe and show a blank box instead, which
 * would look exactly like a card with nothing on it — so the link out is a
 * peer of the embed, not a fallback tucked underneath it.
 */
import React, { useEffect, useState } from 'react';
import { AlertTriangle, CheckCircle2, ExternalLink, FileText, RefreshCw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

type ProofStageProps = {
  proofUrl: string | null;
  proofGeneratedAt: string | null;
  proofCurrent: boolean;
  proofApproved: boolean;
  generating: boolean;
  approving: boolean;
  errors: string[];
  onGenerate: () => void;
  onApprove: () => void;
  onBack: () => void;
  onContinue: () => void;
};

function generatedLabel(timestamp: string | null): string | null {
  if (!timestamp) return null;
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

export const ProofStage: React.FC<ProofStageProps> = ({
  proofUrl,
  proofGeneratedAt,
  proofCurrent,
  proofApproved,
  generating,
  approving,
  errors,
  onGenerate,
  onApprove,
  onBack,
  onContinue,
}) => {
  const [acknowledged, setAcknowledged] = useState(false);

  /**
   * The tick belongs to *this* proof, so a new render clears it.
   *
   * Without this, someone who ticks the box, notices a typo, goes back and
   * fixes it, then regenerates, returns to a pre-ticked confirmation for a
   * card they have never seen — an affirmative act inherited from a document
   * that no longer exists. `proofGeneratedAt` moves on every regeneration,
   * including one that produces a byte-identical PDF.
   */
  useEffect(() => {
    setAcknowledged(false);
  }, [proofGeneratedAt, proofUrl]);

  const stale = Boolean(proofUrl) && !proofCurrent;
  const canApprove = Boolean(proofUrl) && proofCurrent && acknowledged && !approving;

  return (
    <div className="space-y-6">
      {errors.length > 0 && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {errors.map(error => (
            <p key={error}>{error}</p>
          ))}
        </div>
      )}

      {!proofUrl && (
        <div className="rounded-lg border border-dashed border-gray-300 bg-white p-8 text-center">
          <FileText className="mx-auto h-9 w-9 text-gray-400" />
          <h2 className="mt-3 text-lg font-semibold text-gray-900">Make a proof of this card</h2>
          <p className="mx-auto mt-2 max-w-md text-sm text-gray-600">
            We&apos;ll render your card exactly as our print partner will print it, front and back,
            and show you the PDF. Nothing is printed or charged for a proof.
          </p>
          <Button className="mt-5" onClick={onGenerate} disabled={generating}>
            {generating ? 'Rendering your card…' : 'Generate proof'}
          </Button>
        </div>
      )}

      {proofUrl && (
        <>
          {stale && (
            <div className="flex items-start gap-3 rounded-lg border border-amber-300 bg-amber-50 px-4 py-3">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-700" />
              <div className="text-sm text-amber-900">
                <p className="font-semibold">This proof is out of date.</p>
                <p className="mt-1">
                  Your card has changed since it was made, or the proof has expired. What you see
                  below is not what would be printed, so it can&apos;t be approved — generate a new
                  one.
                </p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3 bg-white"
                  onClick={onGenerate}
                  disabled={generating}
                >
                  <RefreshCw className={cn('mr-1.5 h-3.5 w-3.5', generating && 'animate-spin')} />
                  {generating ? 'Rendering…' : 'Generate a new proof'}
                </Button>
              </div>
            </div>
          )}

          {proofApproved && !stale && (
            <div className="flex items-start gap-3 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
              <p>
                <span className="font-semibold">Proof approved.</span> Editing the card after this
                will withdraw the approval, and you&apos;ll be asked for a new proof.
              </p>
            </div>
          )}

          <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b bg-gray-50 px-4 py-2.5">
              <p className="text-sm text-gray-600">
                {stale ? 'Previous proof' : 'Your proof'}
                {generatedLabel(proofGeneratedAt) && (
                  <span className="ml-2 text-gray-400">
                    made {generatedLabel(proofGeneratedAt)}
                  </span>
                )}
              </p>
              <div className="flex items-center gap-2">
                {!stale && (
                  <Button variant="ghost" size="sm" onClick={onGenerate} disabled={generating}>
                    <RefreshCw className={cn('mr-1.5 h-3.5 w-3.5', generating && 'animate-spin')} />
                    Regenerate
                  </Button>
                )}
                <a
                  href={proofUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  <ExternalLink className="h-3.5 w-3.5" />
                  Open PDF in a new tab
                </a>
              </div>
            </div>

            <iframe
              // Keyed on the URL so a regenerated proof forces a fresh load
              // rather than leaving the previous PDF in a cached frame.
              key={proofUrl}
              src={proofUrl}
              title="Proof of your holiday card"
              className={cn('h-[36rem] w-full bg-gray-100', stale && 'opacity-50 grayscale')}
            />
          </div>

          {!stale && !proofApproved && (
            <div className="rounded-lg border border-gray-200 bg-white p-4">
              <label className="flex cursor-pointer items-start gap-3 text-sm text-gray-800">
                <input
                  type="checkbox"
                  checked={acknowledged}
                  onChange={event => setAcknowledged(event.target.checked)}
                  className="mt-0.5 h-4 w-4 shrink-0 rounded border-gray-300 accent-gray-900"
                />
                <span>
                  I have looked at both sides of this proof and it is what I want printed.
                </span>
              </label>
              <Button className="mt-4" onClick={onApprove} disabled={!canApprove}>
                {approving ? 'Approving…' : 'Approve this proof'}
              </Button>
            </div>
          )}
        </>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-4">
        <Button variant="outline" onClick={onBack}>
          Back to recipients
        </Button>
        <Button onClick={onContinue} disabled={!proofApproved || stale}>
          Continue to review &amp; pay
        </Button>
      </div>
    </div>
  );
};

export default ProofStage;
