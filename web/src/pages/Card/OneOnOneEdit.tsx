import React, { useEffect, useMemo, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { useNavigate, useParams } from 'react-router-dom';
import { Heart, PenLine, Sparkles, Upload, X } from 'lucide-react';
import { Toaster, toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import CardNotFound from './components/CardNotFound';
import { useAuth } from '@/contexts/AuthContext';
import { captureError, captureInfo } from '@/lib/posthog-capture';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';
import { isEffectSlug, type EffectSlug } from '@/components/effects';
import { StyleType } from '@/types/app';
import CoverImageDialog from './components/CoverImageDialog';
import CardPreview from './components/CardPreview';
import EffectPicker from './components/EffectPicker';
import { cardTypeById } from '@/config/cardTypes';

const GET_CARD = gql`
  query OneOnOneEditCard($cardId: ID!) {
    card(cardId: $cardId) {
      title
      kind
      occasion
      recipients
      coverImageUrl
      user {
        id
      }
      styles {
        id
        kind
        value
      }
      messages {
        id
        text
        displayName
        user {
          id
        }
      }
    }
  }
`;

const UPDATE_CARD_DOCUMENT = `
  mutation UpdateCard($input: UpdateCardInput!) {
    updateCard(input: $input) {
      success
      errors
    }
  }
`;

const UPDATE_CARD = gql`
  ${UPDATE_CARD_DOCUMENT}
`;

const UPSERT_MESSAGE = gql`
  mutation UpsertMessage($input: UpsertMessageInput!) {
    upsertMessage(input: $input) {
      success
      errors
    }
  }
`;

const GET_OCCASIONS = gql`
  query GetOccasions {
    cardOccasions
  }
`;

const GET_STYLES = gql`
  query GetStyles {
    backgroundColorStyles: styles(kind: "background_color", limit: 20) {
      id
      name
      value
    }
    textColorStyles: styles(kind: "text_color", limit: 20) {
      id
      name
      value
    }
    effectStyles: styles(kind: "effect", limit: 20) {
      id
      name
      value
    }
  }
`;

const CardOneOnOneEdit: React.FC = () => {
  const navigate = useNavigate();
  const { user, loading: userLoading } = useAuth();
  const { cardExternalId } = useParams<{ cardExternalId: string }>();

  const [title, setTitle] = useState('');
  const [recipient, setRecipient] = useState('');
  const [text, setText] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [occasion, setOccasion] = useState<string | undefined>(undefined);

  const [coverImage, setCoverImage] = useState<string | Blob | null>(null);
  const [coverDialogOpen, setCoverDialogOpen] = useState(false);

  const [selectedBackgroundColorId, setSelectedBackgroundColorId] = useState<string | null>(null);
  const [selectedTextColorId, setSelectedTextColorId] = useState<string | null>(null);
  const [selectedEffectId, setSelectedEffectId] = useState<string | null>(null);

  // The card's own style values, used as a preview fallback when a style is not
  // among the pickable options (e.g. a custom colour).
  const [cardBackgroundColor, setCardBackgroundColor] = useState<string | null>(null);
  const [cardTextColor, setCardTextColor] = useState<string | null>(null);
  const [cardEffect, setCardEffect] = useState<EffectSlug | null>(null);

  const [saving, setSaving] = useState(false);
  const [prefilled, setPrefilled] = useState(false);

  const [updateCard] = useMutation(UPDATE_CARD);
  const [upsertMessage] = useMutation(UPSERT_MESSAGE);

  const {
    data: cardResult,
    loading: cardLoading,
    error: cardError,
  } = useQuery(GET_CARD, {
    variables: { cardId: cardExternalId },
    fetchPolicy: 'network-only',
  });
  const card = cardResult?.card;

  const { data: occasionsData } = useQuery(GET_OCCASIONS);
  const occasions = useMemo(() => occasionsData?.cardOccasions || [], [occasionsData]);

  const { data: styleData } = useQuery(GET_STYLES);
  const backgroundColorStyles = useMemo(() => styleData?.backgroundColorStyles || [], [styleData]);
  const textColorStyles = useMemo(() => styleData?.textColorStyles || [], [styleData]);
  const effectStyles = useMemo(() => styleData?.effectStyles || [], [styleData]);

  const findValue = (styles: StyleType[], id: string | null) =>
    styles.find((style: StyleType) => style.id === id)?.value;

  const backgroundColor =
    findValue(backgroundColorStyles, selectedBackgroundColorId) || cardBackgroundColor || '#FDFCF9';
  const textColor = findValue(textColorStyles, selectedTextColorId) || cardTextColor || '#1E293B';
  const effectValue = findValue(effectStyles, selectedEffectId);
  const effect: EffectSlug | null = isEffectSlug(effectValue) ? effectValue : cardEffect;

  const isFormValid = title.trim() !== '' && recipient.trim() !== '' && text.trim() !== '';

  const isCreator =
    user?.user_id && card?.user?.id && String(user.user_id) === String(card.user.id);

  // Seed the form from the loaded card exactly once, so later edits are not
  // clobbered by a refetch.
  useEffect(() => {
    if (prefilled || !card) return;

    const styleId = (kind: string) =>
      card.styles?.find((s: StyleType) => s.kind === kind)?.id ?? null;
    const styleVal = (kind: string) =>
      card.styles?.find((s: StyleType) => s.kind === kind)?.value ?? null;

    setTitle(card.title ?? '');
    setRecipient(card.recipients?.[0] ?? '');
    setOccasion(card.occasion ?? undefined);
    setCoverImage(card.coverImageUrl ?? null);

    setSelectedBackgroundColorId(styleId('background_color'));
    setSelectedTextColorId(styleId('text_color'));
    setSelectedEffectId(styleId('effect'));
    setCardBackgroundColor(styleVal('background_color'));
    setCardTextColor(styleVal('text_color'));
    const eff = styleVal('effect');
    setCardEffect(isEffectSlug(eff) ? eff : null);

    const message = card.messages?.[0];
    setText(message?.text ?? '');
    setDisplayName(message?.displayName ?? user?.name ?? '');

    setPrefilled(true);
  }, [card, prefilled, user]);

  const handleSave = async () => {
    if (!isFormValid || !cardExternalId) return;
    setSaving(true);

    const styleIds = [selectedBackgroundColorId, selectedTextColorId, selectedEffectId].filter(
      Boolean
    );

    try {
      // 1. Card-level fields (title, recipient, styles, occasion, cover image).
      let cardErrors: string[] = [];
      if (coverImage instanceof Blob) {
        const json = await uploadGraphQLMutation<{
          updateCard: { success: boolean; errors: string[] };
        }>({
          query: UPDATE_CARD_DOCUMENT,
          input: {
            cardId: cardExternalId,
            title,
            recipients: [recipient],
            styleIds,
            occasion,
            coverImageFile: null,
          },
          filePath: 'variables.input.coverImageFile',
          file: coverImage,
          filename: 'cover.jpg',
        });
        cardErrors = json.errors?.map(e => e.message) ?? json.data?.updateCard.errors ?? [];
      } else {
        const input: Record<string, unknown> = {
          cardId: cardExternalId,
          title,
          recipients: [recipient],
          styleIds,
          occasion,
        };
        if (typeof coverImage === 'string' && coverImage) input.coverImageUrl = coverImage;
        const { data } = await updateCard({ variables: { input } });
        cardErrors = data.updateCard.errors;
      }

      if (cardErrors.length > 0) {
        toast.error(cardErrors.join(', ') || 'Failed to save card');
        captureError('One-on-One Card Update Error', { errors: cardErrors.join(', ') });
        return;
      }

      // 2. The single message body and signature.
      const { data: messageData } = await upsertMessage({
        variables: {
          input: {
            cardId: cardExternalId,
            userId: user?.user_id,
            text,
            displayName: displayName.trim() || undefined,
          },
        },
      });

      const messageErrors: string[] = messageData.upsertMessage.errors;
      if (messageErrors.length > 0) {
        toast.error(messageErrors.join(', ') || 'Failed to save message');
        captureError('One-on-One Message Update Error', { errors: messageErrors.join(', ') });
        return;
      }

      captureInfo('One-on-One Card Updated', { cardId: cardExternalId });
      toast.success('Card saved');
      navigate(`/card/${cardExternalId}/viewable`);
    } catch (err) {
      toast.error('An error occurred while saving. Please try again.');
      captureError('Unknown One-on-One Card Update Error', {
        error: err instanceof Error ? err.message : String(err),
      });
    } finally {
      setSaving(false);
    }
  };

  const sectionHeading = (step: number, icon: React.ReactNode, label: string) => (
    <h2 className="mb-4 flex items-center gap-2 text-xl font-bold">
      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-purple-100 text-sm font-bold text-purple-700">
        {step}
      </span>
      {icon}
      {label}
    </h2>
  );

  if (cardLoading || userLoading) return <LoadingScreen />;
  if (cardError) return <ErrorScreen />;
  if (!card) return <CardNotFound />;

  if (!isCreator) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-4 text-center">
        <h1 className="mb-3 text-2xl font-semibold">You can&apos;t edit this card</h1>
        <p className="mb-6 text-gray-600">Only the person who created it can make changes.</p>
        <Button onClick={() => navigate(`/card/${cardExternalId}/viewable`)}>View the card</Button>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-grow flex-col bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="mx-auto mt-16 w-full max-w-full px-4 py-8 sm:max-w-[90%] xl:max-w-6xl">
        <Toaster />

        <div className="mb-8 text-center">
          <h1
            className={`mb-3 bg-gradient-to-r ${cardTypeById.one_on_one.gradient} bg-clip-text text-4xl font-bold text-transparent sm:text-5xl`}
          >
            Edit Card
          </h1>
          <p className="text-lg text-gray-600">Update the design and message, then save.</p>
        </div>

        <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_360px]">
          {/* ===== FORM ===== */}
          <Card className="border-2 border-gray-200 bg-white/95 shadow-xl backdrop-blur">
            <CardContent className="space-y-8 pt-6">
              {/* --- 1. Design --- */}
              <section>
                {sectionHeading(1, <Sparkles className="h-5 w-5 text-purple-600" />, 'Design')}

                <div className="space-y-5">
                  <div className="space-y-2">
                    <Label className="flex items-center gap-2 text-base font-semibold">
                      <Upload className="h-4 w-4" />
                      Cover Image (Optional)
                    </Label>
                    {coverImage ? (
                      <div className="relative w-full">
                        <img
                          src={
                            coverImage instanceof Blob
                              ? URL.createObjectURL(coverImage)
                              : coverImage
                          }
                          alt="Selected Cover"
                          className="h-40 w-full rounded-xl border-4 border-white object-cover shadow-lg"
                        />
                        <button
                          type="button"
                          className="absolute top-3 right-3 rounded-full bg-white/90 p-2 shadow-lg transition-all hover:scale-110 hover:bg-white"
                          onClick={() => setCoverImage(null)}
                          aria-label="Remove cover image"
                        >
                          <X className="h-5 w-5 text-gray-700" />
                        </button>
                      </div>
                    ) : (
                      <button
                        type="button"
                        onClick={() => setCoverDialogOpen(true)}
                        className="group flex h-32 w-full flex-col items-center justify-center gap-2 rounded-xl border-4 border-dashed border-gray-300 transition-all hover:border-purple-400 hover:bg-purple-50/50"
                      >
                        <Upload className="h-8 w-8 text-gray-400 transition-colors group-hover:text-purple-500" />
                        <span className="font-medium text-gray-500 transition-colors group-hover:text-purple-600">
                          Click to add a cover image
                        </span>
                      </button>
                    )}
                  </div>

                  <div className="space-y-2">
                    <Label className="text-base font-semibold">Background Color</Label>
                    <div className="flex flex-wrap gap-3">
                      {backgroundColorStyles.map((style: StyleType) => (
                        <button
                          key={style.id}
                          type="button"
                          onClick={() => setSelectedBackgroundColorId(style.id)}
                          title={style.name}
                          aria-label={style.name}
                          className={`h-10 w-10 rounded-xl border-2 transition-all hover:scale-110 ${
                            selectedBackgroundColorId === style.id
                              ? 'scale-110 border-purple-500 ring-4 ring-purple-200'
                              : 'border-gray-300 hover:border-purple-300'
                          }`}
                          style={{ backgroundColor: style.value }}
                        />
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label className="text-base font-semibold">Text Color</Label>
                    <div className="flex flex-wrap gap-3">
                      {textColorStyles.map((style: StyleType) => (
                        <button
                          key={style.id}
                          type="button"
                          onClick={() => setSelectedTextColorId(style.id)}
                          title={style.name}
                          aria-label={style.name}
                          className={`h-10 w-10 rounded-xl border-2 transition-all hover:scale-110 ${
                            selectedTextColorId === style.id
                              ? 'scale-110 border-pink-500 ring-4 ring-pink-200'
                              : 'border-gray-300 hover:border-pink-300'
                          }`}
                          style={{ backgroundColor: style.value }}
                        />
                      ))}
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label className="text-base font-semibold">Effect</Label>
                    <p className="text-sm text-gray-600">
                      Plays when they open the card. Tap again to turn it off.
                    </p>
                    <EffectPicker
                      styles={effectStyles}
                      selectedId={selectedEffectId}
                      onSelect={setSelectedEffectId}
                    />
                  </div>
                </div>
              </section>

              {/* --- 2. Message --- */}
              <section className="border-t-2 border-gray-100 pt-6">
                {sectionHeading(2, <PenLine className="h-5 w-5 text-pink-500" />, 'Message')}

                <div className="space-y-5">
                  <div className="space-y-2">
                    <Label htmlFor="recipient" className="text-base font-semibold">
                      To <span className="text-red-500">*</span>
                    </Label>
                    <Input
                      id="recipient"
                      placeholder="e.g., Sarah"
                      value={recipient}
                      onChange={e => setRecipient(e.target.value)}
                      className="border-2 transition-colors focus:border-purple-400"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label className="text-base font-semibold">Occasion (Optional)</Label>
                    <Select value={occasion} onValueChange={setOccasion}>
                      <SelectTrigger className="border-2">
                        <SelectValue placeholder="Select an Occasion" />
                      </SelectTrigger>
                      <SelectContent>
                        {occasions.map((name: string) => (
                          <SelectItem key={name} value={name}>
                            {name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="title" className="text-base font-semibold">
                      Card Title <span className="text-red-500">*</span>
                    </Label>
                    <Input
                      id="title"
                      placeholder="e.g., Happy Birthday Sarah!"
                      value={title}
                      onChange={e => setTitle(e.target.value)}
                      className="border-2 text-lg transition-colors focus:border-purple-400"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="text" className="text-base font-semibold">
                      Your Message <span className="text-red-500">*</span>
                    </Label>
                    <Textarea
                      id="text"
                      placeholder="Write something heartfelt…"
                      value={text}
                      onChange={e => setText(e.target.value)}
                      rows={6}
                      className="border-2 transition-colors focus:border-purple-400"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="displayName" className="text-base font-semibold">
                      From (Optional)
                    </Label>
                    <Input
                      id="displayName"
                      placeholder="How you want to be signed"
                      value={displayName}
                      onChange={e => setDisplayName(e.target.value)}
                      className="border-2 transition-colors focus:border-purple-400"
                    />
                  </div>
                </div>
              </section>

              {/* --- 3. Save --- */}
              <section className="border-t-2 border-gray-100 pt-6">
                <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
                  <Button
                    variant="outline"
                    onClick={() => navigate(`/card/${cardExternalId}/viewable`)}
                    className="h-14 w-full border-2 text-lg font-bold hover:border-gray-400 sm:w-auto"
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleSave}
                    disabled={!isFormValid || saving}
                    className={`h-14 w-full bg-gradient-to-r ${cardTypeById.one_on_one.gradient} text-lg font-bold text-white shadow-lg transition-all hover:opacity-90 hover:shadow-xl sm:w-auto`}
                  >
                    {saving ? 'Saving…' : 'Save Changes'}
                  </Button>
                </div>
              </section>
            </CardContent>
          </Card>

          {/* ===== LIVE PREVIEW ===== */}
          <div className="lg:sticky lg:top-24 lg:self-start">
            <p className="mb-3 text-center text-sm font-semibold text-gray-500">Live preview</p>
            <CardPreview
              title={title}
              recipient={recipient}
              text={text}
              displayName={displayName}
              coverImage={coverImage}
              backgroundColor={backgroundColor}
              textColor={textColor}
              effect={effect}
            />
            <Button
              variant="outline"
              onClick={() => navigate(`/card/${cardExternalId}/viewable`)}
              className="mt-4 w-full gap-2 border-2 bg-white font-bold"
            >
              <Heart className="h-4 w-4 text-pink-500" />
              View the card
            </Button>
          </div>
        </div>

        <CoverImageDialog
          open={coverDialogOpen}
          onOpenChange={setCoverDialogOpen}
          onSelectCover={cover => {
            setCoverImage(cover);
            setCoverDialogOpen(false);
          }}
        />
      </div>
    </div>
  );
};

export default CardOneOnOneEdit;
