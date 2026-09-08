/**
 * `/holiday-card/:externalId/edit` — the editor page.
 *
 * This owns everything that talks to the server: the initial load, the debounced
 * autosave, and the photo upload/delete mutations. The `Editor` component below
 * it owns the working copy of the design document and nothing else. That split
 * matters because `updateHolidayCard` replaces `design_config` wholesale — there
 * has to be exactly one holder of the document, and exactly one thing deciding
 * when it goes to the server.
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery } from '@apollo/client';
import { ArrowLeft, Monitor, Send } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { DELETE_HOLIDAY_CARD_PHOTO, GET_EDITOR_DATA } from './queries';
import { normalizeDesign, scrubBlob } from './design';
import { Editor } from './Editor';
import { SaveStatus } from './Editor/SaveStatus';
import { useAutosave } from './Editor/useAutosave';
import type {
  DesignConfig,
  EditorOptions,
  HolidayCard,
  HolidayCardPhoto,
  HolidayCardTemplate,
  Sticker,
} from './types';

/**
 * Below this the editor cannot honestly show a 6-inch card *and* its controls,
 * so it says so rather than rendering something broken. Tablet-width and up is
 * supported; a phone is not, and pretending otherwise would waste the user's
 * time before they discovered it.
 */
const MIN_EDITOR_WIDTH = 700;

interface EditorDataResponse {
  holidayCard: HolidayCard | null;
  holidayCardTemplates: HolidayCardTemplate[];
  holidayCardStickers: Sticker[];
  holidayCardEditorOptions: EditorOptions;
}

interface DeletePhotoResponse {
  deleteHolidayCardPhoto: {
    holidayCard: HolidayCard | null;
    errors: string[];
  };
}

const HolidayCardEdit: React.FC = () => {
  const { externalId = '' } = useParams<{ externalId: string }>();
  const navigate = useNavigate();

  const { data, loading, error } = useQuery<EditorDataResponse>(GET_EDITOR_DATA, {
    variables: { externalId },
    // The design document is the thing being edited, so a background refetch
    // overwriting it mid-edit would be a data-loss bug rather than a refresh.
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'cache-first',
  });

  // The working copy. `card` tracks the server's answer (photos, ids); `config`,
  // `templateId`, and `title` are the parts the user edits.
  const [card, setCard] = useState<HolidayCard | null>(null);
  const [config, setConfig] = useState<DesignConfig | null>(null);
  const [templateId, setTemplateId] = useState<string>('');
  const [title, setTitle] = useState<string | null>(null);
  const [saved, setSaved] = useState<{
    config: DesignConfig;
    templateId: string;
    title: string | null;
  } | null>(null);
  const [deletingBlobId, setDeletingBlobId] = useState<string | null>(null);
  const [wideEnough, setWideEnough] = useState(true);

  const [deletePhoto] = useMutation<DeletePhotoResponse>(DELETE_HOLIDAY_CARD_PHOTO);

  const options = data?.holidayCardEditorOptions;

  // Seeded once from the server's answer. Re-seeding on every `data` change
  // would clobber whatever the user had typed since.
  useEffect(() => {
    if (!data?.holidayCard || !options || card) return;

    const loaded = normalizeDesign(data.holidayCard.designConfig, options.designConfigVersion);
    setCard(data.holidayCard);
    setConfig(loaded);
    setTemplateId(data.holidayCard.templateId);
    setTitle(data.holidayCard.title);
    setSaved({
      config: loaded,
      templateId: data.holidayCard.templateId,
      title: data.holidayCard.title,
    });
  }, [data, options, card]);

  useEffect(() => {
    const measure = () => setWideEnough(window.innerWidth >= MIN_EDITOR_WIDTH);
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  }, []);

  const handleSaved = useCallback((updated: HolidayCard) => {
    // The server's copy of the photo list is authoritative, but its copy of the
    // *document* is only as new as the request that carried it — the user may
    // have typed since. Take the attachments, keep the working copy.
    setCard(current =>
      current ? { ...current, photos: updated.photos, updatedAt: updated.updatedAt } : updated
    );
    setSaved({
      config: normalizeDesign(updated.designConfig, updated.designConfig?.version ?? 1),
      templateId: updated.templateId,
      title: updated.title,
    });
  }, []);

  const draft = useMemo(
    () => ({ config: config ?? { version: 1 }, templateId, title }),
    [config, templateId, title]
  );

  const autosave = useAutosave({
    externalId,
    draft,
    saved,
    // Only once the working copy has actually been seeded from the server —
    // before that the draft is this component's empty initial state, and saving
    // it would overwrite the user's card with nothing.
    enabled: Boolean(card && config),
    onSaved: handleSaved,
  });

  const template = useMemo(
    () => data?.holidayCardTemplates.find(candidate => candidate.id === templateId),
    [data, templateId]
  );

  const handlePhotoUploaded = useCallback((photo: HolidayCardPhoto) => {
    setCard(current => (current ? { ...current, photos: [...current.photos, photo] } : current));
  }, []);

  const handlePhotoDeleted = useCallback(
    async (blobId: string) => {
      setDeletingBlobId(blobId);
      try {
        // Scrub locally first. The model rejects a document referencing a photo
        // that is not attached, so leaving the placement in place would make the
        // next autosave fail for a reason the user did nothing to cause.
        setConfig(current => (current ? scrubBlob(current, blobId) : current));

        const result = await deletePhoto({ variables: { externalId, blobId } });
        const payload = result.data?.deleteHolidayCardPhoto;

        if (payload?.errors?.length) {
          toast.error(payload.errors.join(' '));
          return;
        }
        if (payload?.holidayCard) {
          setCard(current =>
            current ? { ...current, photos: payload.holidayCard!.photos } : current
          );
        }
      } catch {
        toast.error('Could not remove that photo. Please try again.');
      } finally {
        setDeletingBlobId(null);
      }
    },
    [deletePhoto, externalId]
  );

  const handleTemplateChange = useCallback(
    (next: HolidayCardTemplate, remapped: DesignConfig, dropped: string[]) => {
      setTemplateId(next.id);
      setConfig(remapped);

      if (dropped.length > 0) {
        toast.warning(`${next.name} has no room for ${listOf(dropped)}.`, {
          description:
            'Switch back to the previous layout to get it back — nothing has been sent yet.',
          duration: 10000,
        });
      }
    },
    []
  );

  if (loading && !card) return <LoadingScreen />;

  if (error || (data && !data.holidayCard)) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-20 text-center">
        <h1 className="text-2xl font-semibold text-gray-900">We could not find that card</h1>
        <p className="mt-2 text-gray-600">
          It may have been deleted, or it may belong to someone else.
        </p>
        <Button className="mt-6" onClick={() => navigate('/holiday-card/new')}>
          Start a new holiday card
        </Button>
      </div>
    );
  }

  if (!card || !config || !options || !template) {
    // A card whose template is no longer in the catalogue has no coordinates to
    // render at — the same case `PrintRenderer::UnknownTemplateError` covers.
    if (card && !template) {
      return (
        <div className="mx-auto max-w-2xl px-4 py-20 text-center">
          <h1 className="text-2xl font-semibold text-gray-900">
            This card's layout has been retired
          </h1>
          <p className="mt-2 text-gray-600">
            We can no longer show <code>{templateId}</code>. Please start a new card, and get in
            touch if you need this design back.
          </p>
        </div>
      );
    }
    return <LoadingScreen />;
  }

  if (!wideEnough) {
    return (
      <div className="mx-auto max-w-md px-6 py-20 text-center">
        <Monitor className="mx-auto h-10 w-10 text-gray-400" />
        <h1 className="mt-4 text-xl font-semibold text-gray-900">This needs a bigger screen</h1>
        <p className="mt-2 text-gray-600">
          Arranging photos on a printed card needs more room than a phone gives. Open this on a
          tablet or a computer and your card will be here, exactly as you left it.
        </p>
        <Button variant="outline" className="mt-6" onClick={() => navigate('/dashboard')}>
          Back to dashboard
        </Button>
      </div>
    );
  }

  return (
    // `h-full` rather than a viewport calculation: `RootLayout` treats this
    // route as full-bleed, so `main` is already exactly the space under the
    // header, with no footer below it to push against.
    <div className="flex h-full flex-col">
      <Toaster position="top-center" richColors />

      <header className="flex shrink-0 flex-wrap items-center gap-3 border-b bg-white px-4 py-3">
        <Button
          variant="ghost"
          size="sm"
          className="gap-1.5"
          onClick={() => navigate('/dashboard')}
        >
          <ArrowLeft className="h-4 w-4" />
          Dashboard
        </Button>

        <Input
          value={title ?? ''}
          onChange={event => setTitle(event.target.value)}
          placeholder="Name this card"
          maxLength={255}
          aria-label="Card name"
          className="h-9 w-56 border-transparent bg-gray-50 font-medium hover:border-gray-200 focus:border-gray-300"
        />

        <div className="ml-auto flex items-center gap-3">
          <SaveStatus state={autosave.state} errors={autosave.errors} />
          {/* The way out of the editor and into the send flow (#151). Editing
              invalidates any approved proof, so this is deliberately a
              navigation rather than a "send now" — the proof and the price are
              stages of their own on the other side.

              The pending debounce is flushed first. Leaving mid-debounce would
              have the send flow render a proof of the *previous* design, which
              is the one failure the proof mechanism exists to prevent. */}
          <Button
            size="sm"
            onClick={async () => {
              if (autosave.dirty) await autosave.saveNow();
              navigate(`/holiday-card/${externalId}/send`);
            }}
            disabled={autosave.state === 'saving'}
          >
            <Send className="mr-1.5 h-4 w-4" />
            Send by post
          </Button>
        </div>
      </header>

      <Editor
        card={card}
        template={template}
        templates={data?.holidayCardTemplates ?? []}
        stickers={data?.holidayCardStickers ?? []}
        options={options}
        config={config}
        onConfigChange={setConfig}
        onTemplateChange={handleTemplateChange}
        onPhotoUploaded={handlePhotoUploaded}
        onPhotoDeleted={handlePhotoDeleted}
        deletingBlobId={deletingBlobId}
      />
    </div>
  );
};

/** "a photo on the front and the message “…” on the back" — a readable list. */
function listOf(items: string[]): string {
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`;
}

export default withAuth(HolidayCardEdit);
