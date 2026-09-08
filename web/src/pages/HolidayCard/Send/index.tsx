/**
 * `/holiday-card/:externalId/send` — pick recipients, approve a proof, pay (#151).
 *
 * This page owns everything that talks to the server and everything that can be
 * navigated between; the three stage components below it are presentational.
 * That split matters more here than in the editor, because the state that
 * decides *who gets mailed and what it costs* has to have exactly one holder.
 *
 * ## Why the stages are visible and reversible
 *
 * The end of this flow is a charge for a physical thing that cannot be
 * un-mailed. Someone at the payment step must be able to see how they got
 * there and step back to change it without losing their place. `furthest`
 * tracks how far the flow has legitimately unlocked; a stage past it is not
 * navigable, because "Review & pay" reached without an approved proof is not a
 * state that exists — the server would reject it, and learning that at the
 * payment step is the worst possible place to learn it.
 *
 * ## What survives leaving the app
 *
 * Running short of postage means a full-page trip to Stripe and back. The
 * selection is written to `sessionStorage` on every change (see `state.ts`), so
 * the user returns to their forty recipients rather than to an empty list. The
 * *proof approval* is not restored from storage — it lives on the server, where
 * it belongs, and is re-read on load.
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useApolloClient, useMutation, useQuery } from '@apollo/client';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Pencil } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import { Button } from '@/components/ui/button';
import { pluralize } from '@/lib/money';
import {
  APPROVE_PROOF,
  GENERATE_PROOF,
  GET_SEND_DATA,
  QUOTE_MAILING,
  SEND_HOLIDAY_CARD,
} from './queries';
import { classifySendErrors, type SendFailure } from './sendErrors';
import { pruneSelection, resolveSelection } from './selection';
import {
  clearSendState,
  emptySendState,
  readSendState,
  rememberPostageReturnTo,
  rememberSendState,
} from './state';
import Stepper from './Stepper';
import RecipientsStage from './RecipientsStage';
import ProofStage from './ProofStage';
import ReviewStage from './ReviewStage';
import {
  SEND_STAGES,
  type MailingQuote,
  type MailOrder,
  type Selection,
  type SendCard,
  type SendContact,
  type SendContactList,
  type SendStage,
} from './types';

/**
 * Note the absence of a balance here. The wallet is read from the *quote*,
 * which returns `postageBalanceCents` alongside the total — one answer, from
 * one request, so the balance and the price the shortfall is computed from can
 * never come from two different moments.
 */
interface SendDataResponse {
  holidayCard: SendCard | null;
  myContacts: SendContact[];
  myContactLists: SendContactList[];
}

interface ProofMutationResponse {
  generateHolidayCardProof?: { holidayCard: SendCard | null; errors: string[] };
  approveHolidayCardProof?: { holidayCard: SendCard | null; errors: string[] };
}

interface SendMutationResponse {
  sendHolidayCard: {
    totalChargedCents: number | null;
    orders: Pick<MailOrder, 'id' | 'status' | 'chargedCents' | 'recipientName'>[] | null;
    errors: string[];
  };
}

interface QuoteResponse {
  quoteHolidayCardMailing: MailingQuote;
}

const HolidayCardSend: React.FC = () => {
  const { externalId = '' } = useParams<{ externalId: string }>();
  const navigate = useNavigate();
  const client = useApolloClient();

  const { data, loading, error, refetch } = useQuery<SendDataResponse>(GET_SEND_DATA, {
    variables: { externalId },
    // The proof state and the wallet balance both move outside this tab (an
    // edit in the editor, a top-up through Stripe), so this page always asks.
    fetchPolicy: 'cache-and-network',
  });

  // Seeded once from whatever survived a trip to Stripe; `null` until then so
  // the first render does not write an empty selection over a stored one.
  const [restored, setRestored] = useState<{ selection: Selection; stage: SendStage } | null>(null);
  const [furthest, setFurthest] = useState<SendStage>('recipients');

  useEffect(() => {
    const stored = readSendState(externalId) ?? emptySendState;
    setRestored(stored);
    // The restored stage has to be reachable, or the stepper would render the
    // stage the user is standing on as one they are not allowed to visit.
    setFurthest(stored.stage);
  }, [externalId]);

  const [proofErrors, setProofErrors] = useState<string[]>([]);
  const [sendFailures, setSendFailures] = useState<SendFailure[]>([]);
  const [quote, setQuote] = useState<MailingQuote | null>(null);
  const [quoteLoading, setQuoteLoading] = useState(false);
  const [quoteError, setQuoteError] = useState<string | null>(null);

  const [generateProof, { loading: generating }] =
    useMutation<ProofMutationResponse>(GENERATE_PROOF);
  const [approveProof, { loading: approving }] = useMutation<ProofMutationResponse>(APPROVE_PROOF);
  const [sendCard, { loading: sending }] = useMutation<SendMutationResponse>(SEND_HOLIDAY_CARD);

  const card = data?.holidayCard ?? null;
  const contacts = useMemo(() => data?.myContacts ?? [], [data]);
  const lists = useMemo(() => data?.myContactLists ?? [], [data]);

  const selection = restored?.selection ?? emptySendState.selection;
  const stage = restored?.stage ?? 'recipients';

  const selectedContacts = useMemo(
    () => resolveSelection(contacts, selection),
    [contacts, selection]
  );
  const selectedIds = useMemo(
    () => selectedContacts.map(contact => contact.id),
    [selectedContacts]
  );

  // One writer for the stored state, so a stage change and a selection change
  // can never disagree about what was saved.
  const commit = useCallback(
    (next: { selection?: Selection; stage?: SendStage }) => {
      setRestored(current => {
        const base = current ?? emptySendState;
        const updated = {
          selection: next.selection ?? base.selection,
          stage: next.stage ?? base.stage,
        };
        rememberSendState(externalId, updated);
        return updated;
      });
    },
    [externalId]
  );

  // A stored id can name a contact deleted since — in another tab, or on the
  // Contacts page between two visits here. Dropped rather than carried into a
  // quote, which rejects the whole request for one unknown id and would leave
  // the flow stuck on an error the user cannot see the cause of.
  //
  // `pruneSelection` returns the same object when nothing changed, so this
  // settles after one pass; going through `commit` is what stops the stale ids
  // from surviving in storage to be read back on the next load.
  useEffect(() => {
    if (!restored || contacts.length === 0) return;
    const pruned = pruneSelection(restored.selection, contacts);
    if (pruned !== restored.selection) commit({ selection: pruned });
  }, [restored, contacts, commit]);

  const goToStage = useCallback(
    (next: SendStage) => {
      commit({ stage: next });
      if (SEND_STAGES.indexOf(next) > SEND_STAGES.indexOf(furthest)) setFurthest(next);
      window.scrollTo({ top: 0 });
    },
    [commit, furthest]
  );

  // An approved, current proof is what unlocks the payment stage — read off the
  // server's answer rather than remembered from a click, so an edit in another
  // tab locks it again on the next load.
  useEffect(() => {
    if (card?.proofApproved && SEND_STAGES.indexOf(furthest) < SEND_STAGES.indexOf('review')) {
      setFurthest('proof');
    }
  }, [card?.proofApproved, furthest]);

  /**
   * The other half of that rule: a *restored* review stage is demoted the
   * moment the server disagrees.
   *
   * `sessionStorage` says where the user was standing; only the card says
   * whether they are still allowed to be there. Someone who edits the design
   * in another tab while Stripe has this one, then comes back, must land on the
   * proof with the "out of date" banner rather than on a payment screen for a
   * card that would be rejected — the exact surprise the proof gate exists to
   * prevent, and the worst place to spring it.
   */
  useEffect(() => {
    if (!card || !restored) return;
    if (restored.stage === 'review' && !card.proofApproved) commit({ stage: 'proof' });
  }, [card, restored, commit]);

  /**
   * Prices the current selection. Always `network-only`: an advisory number
   * served from cache is the one thing this flow must not do.
   */
  const runQuote = useCallback(
    async (ids: string[]): Promise<MailingQuote | null> => {
      if (ids.length === 0) {
        setQuote(null);
        return null;
      }

      setQuoteLoading(true);
      setQuoteError(null);
      try {
        const { data: quoteData } = await client.query<QuoteResponse>({
          query: QUOTE_MAILING,
          variables: { holidayCardId: externalId, contactIds: ids },
          fetchPolicy: 'network-only',
        });
        const fresh = quoteData?.quoteHolidayCardMailing ?? null;
        setQuote(fresh);
        return fresh;
      } catch {
        setQuoteError(
          'We could not price this send just now. Please try again in a moment — nothing has been charged.'
        );
        return null;
      } finally {
        setQuoteLoading(false);
      }
    },
    [client, externalId]
  );

  /**
   * The review stage is the only one that needs a price, and it needs a fresh
   * one — an address may have been fixed since the last look.
   *
   * Keyed on the *contents* of the selection rather than on entering the stage.
   * Entry alone is not enough: a page restored straight into `review` (the way
   * back from a top-up) renders before `myContacts` has arrived, so the
   * selection resolves to nothing for a beat. Quoting once on entry priced that
   * empty list and never asked again — a review screen reporting "0 cards,
   * $0.00" for a selection the user could see was not empty.
   *
   * A join, not the array, because `selectedIds` is a fresh array on every
   * render. Ticking boxes does not cause requests: the picker only exists on
   * the recipients stage, where the guard below returns first.
   */
  const selectedKey = selectedIds.join(',');
  useEffect(() => {
    if (stage !== 'review') return;
    void runQuote(selectedKey ? selectedKey.split(',') : []);
  }, [stage, selectedKey, runQuote]);

  const handleGenerateProof = useCallback(async () => {
    setProofErrors([]);
    try {
      const { data: result } = await generateProof({ variables: { externalId } });
      const errors = result?.generateHolidayCardProof?.errors ?? [];
      if (errors.length > 0) {
        setProofErrors(errors);
        return;
      }
      await refetch();
      toast.success('Proof ready — take a good look at both sides.');
    } catch {
      setProofErrors([
        'We could not reach our print partner to render a proof. Please try again in a moment.',
      ]);
    }
  }, [generateProof, externalId, refetch]);

  const handleApproveProof = useCallback(async () => {
    setProofErrors([]);
    try {
      const { data: result } = await approveProof({ variables: { externalId } });
      const errors = result?.approveHolidayCardProof?.errors ?? [];
      if (errors.length > 0) {
        // Almost always a proof that went stale between rendering and pressing
        // the button. Re-reading the card is what puts the "out of date" banner
        // and the regenerate button on screen.
        setProofErrors(errors);
        await refetch();
        return;
      }
      await refetch();
      setFurthest('review');
      toast.success('Proof approved.');
    } catch {
      setProofErrors(['We could not record that approval. Please try again.']);
    }
  }, [approveProof, externalId, refetch]);

  const handleSend = useCallback(
    async (contactIds: string[], expectedTotalCents: number) => {
      setSendFailures([]);
      try {
        const { data: result } = await sendCard({
          // No price argument — see queries.ts. The server re-quotes.
          variables: { holidayCardId: externalId, contactIds },
        });
        const payload = result?.sendHolidayCard;
        const errors = payload?.errors ?? [];

        if (errors.length > 0) {
          setSendFailures(classifySendErrors(errors));
          // A rejected send may have moved the card (a stale proof) or the
          // wallet, so both are re-read before the user acts on the message.
          await refetch();
          return;
        }

        const charged = payload?.totalChargedCents ?? 0;
        const orderCount = payload?.orders?.length ?? contactIds.length;

        // The cards are in the queue; the selection has done its job and must
        // not be restored on top of a completed send.
        clearSendState(externalId);

        // The server priced this itself. If its number is not the one the user
        // was shown, say so on the page they land on rather than letting the
        // difference pass unremarked.
        navigate(`/holiday-card/${externalId}/orders`, {
          replace: true,
          state: {
            justSent: orderCount,
            chargedCents: charged,
            expectedCents: expectedTotalCents,
          },
        });
      } catch {
        setSendFailures([
          {
            kind: 'unknown',
            message:
              'We could not complete that send. Nothing was charged — please try again in a moment.',
          },
        ]);
      }
    },
    [sendCard, externalId, refetch, navigate]
  );

  /**
   * The top-up link. The path is written down before the redirect so
   * `/postage` knows where to send the user back to; the selection is
   * already in storage, so they come back to it intact.
   */
  const topUpPath = '/postage';
  const handleTopUpIntent = useCallback(() => {
    rememberPostageReturnTo(`/holiday-card/${externalId}/send`);
  }, [externalId]);

  // Written on entering the review stage, not on the click. The top-up is a
  // `<Link>`, and a click handler racing the navigation it triggers is exactly
  // how the note ends up unwritten on the one trip that needed it.
  useEffect(() => {
    if (stage === 'review') handleTopUpIntent();
  }, [stage, handleTopUpIntent]);

  if (loading && !data) return <LoadingScreen />;
  if (!restored) return <LoadingScreen />;

  if (error || (data && !card)) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-20 text-center">
        <h1 className="text-2xl font-semibold text-gray-900">We could not find that card</h1>
        <p className="mt-2 text-gray-600">
          It may have been deleted, or it may belong to someone else.
        </p>
        <Button className="mt-6" onClick={() => navigate('/dashboard')}>
          Back to dashboard
        </Button>
      </div>
    );
  }

  if (!card) return <LoadingScreen />;

  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50 px-4 py-8">
      <Toaster position="top-center" richColors />
      <div className="mx-auto w-full max-w-4xl">
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
          <div>
            <Button
              variant="ghost"
              size="sm"
              className="-ml-2 gap-1.5"
              onClick={() => navigate(`/holiday-card/${externalId}/edit`)}
            >
              <ArrowLeft className="h-4 w-4" />
              Back to the editor
            </Button>
            <h1 className="mt-1 text-3xl font-bold text-gray-900">Send by post</h1>
            <p className="mt-1 text-gray-600">
              {card.title ? `“${card.title}”` : 'Your holiday card'} — printed and mailed to the
              people you pick.
            </p>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => navigate(`/holiday-card/${externalId}/edit`)}
          >
            <Pencil className="mr-1.5 h-3.5 w-3.5" />
            Edit the design
          </Button>
        </div>

        <div className="mb-6 rounded-xl border border-gray-200 bg-white px-4 py-3">
          <Stepper current={stage} furthest={furthest} onNavigate={goToStage} />
        </div>

        {stage === 'recipients' && (
          <RecipientsStage
            contacts={contacts}
            lists={lists}
            selection={selection}
            onSelectionChange={next => commit({ selection: next })}
            onRefetch={refetch}
            onContinue={() => goToStage('proof')}
          />
        )}

        {stage === 'proof' && (
          <ProofStage
            proofUrl={card.proofUrl}
            proofGeneratedAt={card.proofGeneratedAt}
            proofCurrent={card.proofCurrent}
            proofApproved={card.proofApproved}
            generating={generating}
            approving={approving}
            errors={proofErrors}
            onGenerate={handleGenerateProof}
            onApprove={handleApproveProof}
            onBack={() => goToStage('recipients')}
            onContinue={() => goToStage('review')}
          />
        )}

        {stage === 'review' && (
          <ReviewStage
            quote={quote}
            quoteLoading={quoteLoading}
            quoteError={quoteError}
            selectedCount={selectedContacts.length}
            cardTitle={card.title}
            sending={sending}
            failures={sendFailures}
            onRequote={() => runQuote(selectedIds)}
            onSend={handleSend}
            onRefetch={async () => {
              await refetch();
              await runQuote(selectedIds);
            }}
            onBack={() => goToStage('proof')}
            topUpPath={topUpPath}
          />
        )}

        {stage === 'recipients' && selectedContacts.length > 0 && (
          <p className="mt-4 text-center text-xs text-gray-500">
            {pluralize(selectedContacts.length, 'contact')} selected. Nothing is printed or charged
            until you confirm at the last step.
          </p>
        )}
      </div>
    </div>
  );
};

export default withAuth(HolidayCardSend);
