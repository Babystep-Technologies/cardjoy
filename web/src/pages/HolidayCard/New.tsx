/**
 * `/holiday-card/new` — pick a size and a layout, then straight into the editor.
 *
 * Size and template are chosen up front rather than in the editor because the
 * API pairs them at create time: a template's geometry is drawn for one panel
 * size, so there is no such thing as a card without both. Everything else about
 * the card is editable afterwards, including the layout.
 *
 * Creating a holiday card deliberately spends no credit — the product is the
 * physical piece of card stock, paid for at send time out of the postage wallet.
 * Designing and previewing is free.
 */
import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQuery } from '@apollo/client';
import { Loader2 } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { CREATE_HOLIDAY_CARD, GET_TEMPLATES } from './queries';
import { emptyDesign } from './design';
import { PanelPreview } from './Editor/PanelPreview';
import type { EditorOptions, HolidayCardTemplate } from './types';

interface TemplatesResponse {
  holidayCardTemplates: HolidayCardTemplate[];
}

interface CreateResponse {
  createHolidayCard: {
    holidayCard: { externalId: string } | null;
    errors: string[];
  };
}

/**
 * The thumbnails on this page draw no user content, so they need none of the
 * real option set — only enough of it for `PanelPreview` to compute a type size
 * and clamp a transform that no card here actually has. The editor fetches the
 * real thing.
 */
const PREVIEW_OPTIONS: EditorOptions = {
  designConfigVersion: 1,
  cardSizes: [],
  fonts: [],
  textSizes: [],
  alignments: ['left', 'center', 'right'],
  lineHeight: 1.3,
  textMaxLength: 500,
  minZoom: 0.5,
  maxZoom: 5,
  maxPan: 1,
  maxPhotos: 20,
};

/** Human labels for the sizes the API offers, so the toggle is not "6x9". */
const SIZE_LABELS: Record<string, string> = {
  '6x4': '6″ × 4″ postcard',
  '6x9': '6″ × 9″ oversized',
};

const HolidayCardNew: React.FC = () => {
  const navigate = useNavigate();
  const [size, setSize] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [creatingId, setCreatingId] = useState<string | null>(null);

  const { data, loading, error } = useQuery<TemplatesResponse>(GET_TEMPLATES);
  const [createCard] = useMutation<CreateResponse>(CREATE_HOLIDAY_CARD);

  const templates = useMemo(() => data?.holidayCardTemplates ?? [], [data]);
  // Derived from the catalogue rather than hardcoded, so retiring a size is a
  // backend change on its own.
  const sizes = useMemo(() => [...new Set(templates.map(template => template.size))], [templates]);

  useEffect(() => {
    if (!size && sizes.length > 0) setSize(sizes[0]);
  }, [size, sizes]);

  const handleCreate = async (template: HolidayCardTemplate) => {
    setCreatingId(template.id);
    try {
      const result = await createCard({
        variables: { size: template.size, templateId: template.id, title: title.trim() || null },
      });

      const payload = result.data?.createHolidayCard;
      if (payload?.errors?.length) {
        toast.error(payload.errors.join(' '));
        return;
      }
      if (!payload?.holidayCard) {
        toast.error('Could not start that card. Please try again.');
        return;
      }

      navigate(`/holiday-card/${payload.holidayCard.externalId}/edit`);
    } catch {
      toast.error('Could not start that card. Please try again.');
    } finally {
      setCreatingId(null);
    }
  };

  if (loading) return <LoadingScreen />;

  if (error || templates.length === 0) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-20 text-center">
        <h1 className="text-2xl font-semibold text-gray-900">
          Holiday cards are not available right now
        </h1>
        <p className="mt-2 text-gray-600">
          We could not load the card designs. Please try again in a moment.
        </p>
      </div>
    );
  }

  const shown = templates.filter(template => template.size === size);

  return (
    <div className="mx-auto max-w-5xl px-4 py-10">
      <Toaster position="top-center" />

      <header className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Design a holiday card</h1>
        <p className="mt-2 text-gray-600">
          Pick a size and a layout to start. You can change the layout, your photos, and every word
          on it afterwards.
        </p>
      </header>

      <div className="mb-6 grid gap-6 sm:grid-cols-2">
        <div>
          <Label className="text-sm text-gray-700">Card size</Label>
          <div className="mt-2 flex gap-2">
            {sizes.map(candidate => (
              <button
                key={candidate}
                type="button"
                onClick={() => setSize(candidate)}
                className={`rounded-lg border-2 px-4 py-2 text-sm font-medium transition-colors ${
                  candidate === size
                    ? 'border-[var(--color-brand-yellow)] bg-amber-50 text-gray-900'
                    : 'border-gray-200 text-gray-600 hover:border-gray-400'
                }`}
              >
                {SIZE_LABELS[candidate] ?? candidate}
              </button>
            ))}
          </div>
        </div>

        <div>
          <Label htmlFor="card-title" className="text-sm text-gray-700">
            Name this card <span className="text-gray-400">(optional, never printed)</span>
          </Label>
          <Input
            id="card-title"
            value={title}
            onChange={event => setTitle(event.target.value)}
            placeholder="Shen family 2026"
            maxLength={255}
            className="mt-2"
          />
        </div>
      </div>

      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {shown.map(template => (
          <button
            key={template.id}
            type="button"
            disabled={creatingId !== null}
            onClick={() => handleCreate(template)}
            className="group rounded-xl border-2 border-gray-200 bg-white p-4 text-left transition-colors hover:border-[var(--color-brand-yellow)] disabled:opacity-60"
          >
            <div className="flex justify-center overflow-hidden rounded-md bg-gray-50 p-2">
              <PanelPreview
                template={template}
                panel="front"
                config={emptyDesign(PREVIEW_OPTIONS.designConfigVersion)}
                options={PREVIEW_OPTIONS}
                photos={[]}
                stickers={[]}
                scale={220 / (template.widthInches + template.bleedInches * 2)}
                showGuides
              />
            </div>
            <h2 className="mt-3 flex items-center gap-2 font-semibold text-gray-900">
              {template.name}
              {creatingId === template.id && <Loader2 className="h-4 w-4 animate-spin" />}
            </h2>
            {template.description && (
              <p className="mt-1 text-sm text-gray-600">{template.description}</p>
            )}
          </button>
        ))}
      </div>

      <p className="mt-8 text-sm text-gray-500">
        Designing and previewing a card is free. You only pay when you send one.
      </p>

      <Button variant="ghost" className="mt-4" onClick={() => navigate('/dashboard')}>
        Back to dashboard
      </Button>
    </div>
  );
};

export default withAuth(HolidayCardNew);
