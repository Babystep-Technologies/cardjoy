import React, { useEffect, useMemo, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { format } from 'date-fns';
import { Check, Copy, Heart, Mail, PenLine, Send, Sparkles, Upload, X } from 'lucide-react';
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { useAuth } from '@/contexts/AuthContext';
import { captureError, captureInfo } from '@/lib/posthog-capture';
import { isInsufficientCreditsError, INSUFFICIENT_CREDITS_REDIRECT } from '@/lib/credits';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';
import { isEffectSlug, type EffectSlug } from '@/components/effects';
import { StyleType } from '@/types/app';
import { detectTimezone, formatInTimezone, zonedWallTimeToUtcISO } from '@/lib/timezone';
import CoverImageDialog from './components/CoverImageDialog';
import CardPreview from './components/CardPreview';
import EffectPicker from './components/EffectPicker';
import SchedulePicker from './components/SchedulePicker';
import { cardTypeById } from '@/config/cardTypes';

const CREATE_ONE_ON_ONE_CARD_DOCUMENT = `
  mutation CreateOneOnOneCard($input: CreateOneOnOneCardInput!) {
    createOneOnOneCard(input: $input) {
      card {
        externalId
        title
      }
      errors
    }
  }
`;

const CREATE_ONE_ON_ONE_CARD = gql`
  ${CREATE_ONE_ON_ONE_CARD_DOCUMENT}
`;

const DELIVER_CARD = gql`
  mutation DeliverCard($input: DeliverCardInput!) {
    deliverCard(input: $input) {
      card {
        externalId
      }
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

interface CreatedCard {
  externalId: string;
  title: string;
}

/** Reads naturally for every occasion in `Card::OCCASIONS`, which are all nouns. */
const suggestTitle = (occasion: string | undefined, recipient: string) => {
  const name = recipient.trim();
  if (!name) return '';
  return occasion ? `${occasion} — ${name}` : `For ${name}`;
};

const CardOneOnOneNew: React.FC = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();

  const [title, setTitle] = useState('');
  const [titleEdited, setTitleEdited] = useState(false);
  const [recipient, setRecipient] = useState('');
  const [text, setText] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [occasion, setOccasion] = useState<string | undefined>(undefined);

  const [coverImage, setCoverImage] = useState<string | Blob | null>(null);
  const [coverDialogOpen, setCoverDialogOpen] = useState(false);
  const [signInDialogOpen, setSignInDialogOpen] = useState(false);

  const [selectedBackgroundColorId, setSelectedBackgroundColorId] = useState<string | null>(null);
  const [selectedTextColorId, setSelectedTextColorId] = useState<string | null>(null);
  const [selectedEffectId, setSelectedEffectId] = useState<string | null>(null);

  const [creating, setCreating] = useState(false);
  const [createdCard, setCreatedCard] = useState<CreatedCard | null>(null);
  const [recipientEmail, setRecipientEmail] = useState('');
  const [delivering, setDelivering] = useState(false);
  const [delivered, setDelivered] = useState(false);
  const [scheduled, setScheduled] = useState(false);
  const [linkCopied, setLinkCopied] = useState(false);

  const [deliveryMode, setDeliveryMode] = useState<'now' | 'schedule'>('now');
  const [scheduleDate, setScheduleDate] = useState<Date | undefined>(undefined);
  const [scheduleTime, setScheduleTime] = useState('');
  const [scheduleTimezone, setScheduleTimezone] = useState(() => detectTimezone());

  const [createOneOnOneCard] = useMutation(CREATE_ONE_ON_ONE_CARD);
  const [deliverCard] = useMutation(DELIVER_CARD);

  const { data: occasionsData } = useQuery(GET_OCCASIONS);
  const occasions = useMemo(() => occasionsData?.cardOccasions || [], [occasionsData]);

  const { data: styleData } = useQuery(GET_STYLES);
  const backgroundColorStyles = useMemo(() => styleData?.backgroundColorStyles || [], [styleData]);
  const textColorStyles = useMemo(() => styleData?.textColorStyles || [], [styleData]);
  const effectStyles = useMemo(() => styleData?.effectStyles || [], [styleData]);

  const findValue = (styles: StyleType[], id: string | null) =>
    styles.find((style: StyleType) => style.id === id)?.value;

  const backgroundColor = findValue(backgroundColorStyles, selectedBackgroundColorId) || '#FDFCF9';
  const textColor = findValue(textColorStyles, selectedTextColorId) || '#1E293B';
  const effectValue = findValue(effectStyles, selectedEffectId);
  const effect: EffectSlug | null = isEffectSlug(effectValue) ? effectValue : null;

  const shareUrl = createdCard
    ? `${import.meta.env.VITE_PREVIEW_ENDPOINT}/card/${createdCard.externalId}/viewable`
    : '';

  const isFormValid = title.trim() !== '' && recipient.trim() !== '' && text.trim() !== '';

  useEffect(() => {
    const presetOccasion = searchParams.get('occasion');
    if (presetOccasion && occasions.includes(presetOccasion)) {
      setOccasion(presetOccasion);
    }
  }, [searchParams, occasions]);

  // Default to the first colour of each kind, and to Confetti, so the preview is
  // never blank. Matches pages/Card/New.tsx.
  useEffect(() => {
    if (!selectedBackgroundColorId && backgroundColorStyles.length > 0) {
      setSelectedBackgroundColorId(backgroundColorStyles[0].id);
    }
    if (!selectedTextColorId && textColorStyles.length > 0) {
      setSelectedTextColorId(textColorStyles[0].id);
    }
  }, [backgroundColorStyles, textColorStyles, selectedBackgroundColorId, selectedTextColorId]);

  const [effectDefaulted, setEffectDefaulted] = useState(false);
  useEffect(() => {
    if (effectDefaulted || effectStyles.length === 0) return;
    const confetti = effectStyles.find((style: StyleType) => style.value === 'confetti');
    setSelectedEffectId(confetti?.id ?? effectStyles[0].id);
    setEffectDefaulted(true);
  }, [effectStyles, effectDefaulted]);

  // Keep the title in step with the occasion and recipient until it is hand-edited.
  useEffect(() => {
    if (titleEdited) return;
    setTitle(suggestTitle(occasion, recipient));
  }, [occasion, recipient, titleEdited]);

  const handleCreateCard = async () => {
    if (!isFormValid) return;

    if (!user) {
      setSignInDialogOpen(true);
      return;
    }

    const styleIds = [selectedBackgroundColorId, selectedTextColorId, selectedEffectId].filter(
      Boolean
    );
    const input: Record<string, unknown> = {
      title,
      recipient,
      text,
      styleIds,
      occasion,
    };
    if (displayName.trim()) input.displayName = displayName.trim();

    setCreating(true);

    try {
      let card: CreatedCard | null = null;
      let errors: string[] = [];

      if (coverImage instanceof Blob) {
        const json = await uploadGraphQLMutation<{
          createOneOnOneCard: { card: CreatedCard | null; errors: string[] };
        }>({
          query: CREATE_ONE_ON_ONE_CARD_DOCUMENT,
          input: { ...input, coverImageFile: null },
          filePath: 'variables.input.coverImageFile',
          file: coverImage,
          filename: 'cover.jpg',
        });

        if (json.errors?.length) {
          errors = json.errors.map(error => error.message);
        } else {
          card = json.data?.createOneOnOneCard.card ?? null;
          errors = json.data?.createOneOnOneCard.errors ?? [];
        }
      } else {
        if (typeof coverImage === 'string' && coverImage) input.coverImageUrl = coverImage;
        const { data } = await createOneOnOneCard({ variables: { input } });
        card = data.createOneOnOneCard.card;
        errors = data.createOneOnOneCard.errors;
      }

      if (errors.length === 0 && card) {
        setCreatedCard(card);
        toast.success('Card created! Now send it.');
        captureInfo('One-on-One Card Created', { cardTitle: card.title, cardId: card.externalId });
      } else if (isInsufficientCreditsError(errors)) {
        navigate(INSUFFICIENT_CREDITS_REDIRECT);
      } else {
        toast.error(errors.join(', ') || 'Failed to create card');
        captureError('One-on-One Card Creation Error', { errors: errors.join(', ') });
      }
    } catch (err) {
      toast.error('An error occurred while creating the card. Please try again.');
      captureError('Unknown One-on-One Card Creation Error', {
        error: err instanceof Error ? err.message : String(err),
        userId: user?.user_id || 'unknown',
      });
    } finally {
      setCreating(false);
    }
  };

  const handleCopyLink = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      setLinkCopied(true);
      toast.success('Link copied to clipboard');
      setTimeout(() => setLinkCopied(false), 2000);
    } catch {
      toast.error('Could not copy the link. Select and copy it manually.');
    }
  };

  const isScheduling = deliveryMode === 'schedule';
  const scheduleReady = scheduleDate !== undefined && scheduleTime !== '';
  // UTC instant for the chosen wall-clock time, or null until both date and time
  // are set — an empty time would build an Invalid Date and throw in toISOString.
  const deliverAtIso =
    isScheduling && scheduleReady && scheduleDate
      ? zonedWallTimeToUtcISO(format(scheduleDate, 'yyyy-MM-dd'), scheduleTime, scheduleTimezone)
      : null;
  const scheduleInPast = deliverAtIso !== null && new Date(deliverAtIso).getTime() <= Date.now();
  const canDeliver =
    recipientEmail.trim() !== '' && (!isScheduling || (scheduleReady && !scheduleInPast));

  const handleDeliver = async () => {
    if (!createdCard || !canDeliver) return;
    setDelivering(true);

    try {
      // `cardId` resolves by external_id on the API, not the database id.
      const { data } = await deliverCard({
        variables: {
          input: {
            cardId: createdCard.externalId,
            recipientEmail,
            ...(deliverAtIso ? { deliverAt: deliverAtIso } : {}),
          },
        },
      });

      if (data.deliverCard.errors.length === 0) {
        if (deliverAtIso) {
          setScheduled(true);
          toast.success(
            `Scheduled for ${recipientEmail} on ${formatInTimezone(deliverAtIso, scheduleTimezone)}`
          );
          captureInfo('One-on-One Card Scheduled', {
            cardId: createdCard.externalId,
            deliverAt: deliverAtIso,
          });
        } else {
          setDelivered(true);
          toast.success(`Sent to ${recipientEmail}`);
          captureInfo('One-on-One Card Delivered', { cardId: createdCard.externalId });
        }
      } else {
        toast.error(data.deliverCard.errors.join(', ') || 'Failed to send card');
        captureError('One-on-One Card Delivery Error', {
          errors: data.deliverCard.errors.join(', '),
        });
      }
    } catch (err) {
      toast.error('An error occurred while sending the card. Please try again.');
      captureError('Unknown One-on-One Card Delivery Error', {
        error: err instanceof Error ? err.message : String(err),
      });
    } finally {
      setDelivering(false);
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

  return (
    <div className="flex min-h-screen flex-grow flex-col bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="mx-auto mt-16 w-full max-w-full px-4 py-8 sm:max-w-[90%] xl:max-w-6xl">
        <Toaster />

        <div className="mb-8 text-center">
          <h1
            className={`mb-3 bg-gradient-to-r ${cardTypeById.one_on_one.gradient} bg-clip-text text-4xl font-bold text-transparent sm:text-5xl`}
          >
            Send a Card
          </h1>
          <p className="text-lg text-gray-600">
            Pick a design, write your message, send it. That&apos;s it.
          </p>
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
                      onChange={e => {
                        setTitleEdited(true);
                        setTitle(e.target.value);
                      }}
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

              {/* --- 3. Deliver --- */}
              <section className="border-t-2 border-gray-100 pt-6">
                {sectionHeading(3, <Send className="h-5 w-5 text-blue-500" />, 'Deliver')}

                {!createdCard ? (
                  <div className="space-y-4">
                    <p className="text-sm text-gray-600">
                      Create the card to get a shareable link and send it by email.
                    </p>
                    <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
                      <Button
                        variant="outline"
                        onClick={() => navigate('/')}
                        className="h-14 w-full border-2 text-lg font-bold hover:border-gray-400 sm:w-auto"
                      >
                        Cancel
                      </Button>
                      <Button
                        onClick={handleCreateCard}
                        disabled={!isFormValid || creating}
                        className={`h-14 w-full bg-gradient-to-r ${cardTypeById.one_on_one.gradient} text-lg font-bold text-white shadow-lg transition-all hover:opacity-90 hover:shadow-xl sm:w-auto`}
                      >
                        {creating ? 'Creating…' : 'Create Card'}
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-5 rounded-2xl border-4 border-purple-300 bg-gradient-to-br from-purple-50 to-pink-50 p-6">
                    <div className="space-y-2">
                      <Label className="text-base font-semibold">Shareable link</Label>
                      <div className="flex gap-2">
                        <Input readOnly value={shareUrl} className="border-2 bg-white text-sm" />
                        <Button
                          variant="outline"
                          onClick={handleCopyLink}
                          className="shrink-0 gap-2 border-2 bg-white"
                        >
                          {linkCopied ? (
                            <Check className="h-4 w-4 text-green-600" />
                          ) : (
                            <Copy className="h-4 w-4" />
                          )}
                          {linkCopied ? 'Copied' : 'Copy'}
                        </Button>
                      </div>
                    </div>

                    <div className="space-y-3">
                      <Label htmlFor="recipientEmail" className="text-base font-semibold">
                        Or send by email
                      </Label>
                      <Input
                        id="recipientEmail"
                        type="email"
                        placeholder="sarah@example.com"
                        value={recipientEmail}
                        onChange={e => {
                          setDelivered(false);
                          setScheduled(false);
                          setRecipientEmail(e.target.value);
                        }}
                        className="border-2 bg-white"
                      />

                      <div className="grid grid-cols-2 gap-2 rounded-xl bg-white/70 p-1">
                        {(['now', 'schedule'] as const).map(mode => (
                          <button
                            key={mode}
                            type="button"
                            onClick={() => {
                              setDeliveryMode(mode);
                              setDelivered(false);
                              setScheduled(false);
                            }}
                            className={`rounded-lg px-3 py-2 text-sm font-semibold transition-all ${
                              deliveryMode === mode
                                ? 'bg-blue-600 text-white shadow'
                                : 'text-gray-600 hover:bg-white'
                            }`}
                          >
                            {mode === 'now' ? 'Send now' : 'Schedule for a date'}
                          </button>
                        ))}
                      </div>

                      {isScheduling && (
                        <div className="space-y-3 rounded-xl border-2 border-blue-200 bg-white p-4">
                          <SchedulePicker
                            date={scheduleDate}
                            time={scheduleTime}
                            timezone={scheduleTimezone}
                            onDateChange={date => {
                              setScheduled(false);
                              setScheduleDate(date);
                            }}
                            onTimeChange={time => {
                              setScheduled(false);
                              setScheduleTime(time);
                            }}
                            onTimezoneChange={tz => {
                              setScheduled(false);
                              setScheduleTimezone(tz);
                            }}
                          />
                          {deliverAtIso && scheduleReady && (
                            <p
                              className={`text-sm ${scheduleInPast ? 'text-red-600' : 'text-gray-600'}`}
                            >
                              {scheduleInPast
                                ? 'Pick a time in the future.'
                                : `Sends ${formatInTimezone(deliverAtIso, scheduleTimezone)}`}
                            </p>
                          )}
                        </div>
                      )}

                      <Button
                        onClick={handleDeliver}
                        disabled={!canDeliver || delivering || delivered || scheduled}
                        className="w-full shrink-0 gap-2 bg-blue-600 font-bold text-white hover:bg-blue-700"
                      >
                        {delivered || scheduled ? (
                          <Check className="h-4 w-4" />
                        ) : isScheduling ? (
                          <Send className="h-4 w-4" />
                        ) : (
                          <Mail className="h-4 w-4" />
                        )}
                        {delivering
                          ? isScheduling
                            ? 'Scheduling…'
                            : 'Sending…'
                          : scheduled
                            ? 'Scheduled'
                            : delivered
                              ? 'Sent'
                              : isScheduling
                                ? 'Schedule send'
                                : 'Send'}
                      </Button>
                    </div>

                    <Button
                      variant="outline"
                      onClick={() => navigate(`/card/${createdCard.externalId}/viewable`)}
                      className="w-full gap-2 border-2 bg-white font-bold"
                    >
                      <Heart className="h-4 w-4 text-pink-500" />
                      View the card
                    </Button>
                  </div>
                )}
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

        <Dialog open={signInDialogOpen} onOpenChange={setSignInDialogOpen}>
          <DialogContent className="sm:max-w-md">
            <DialogHeader>
              <DialogTitle>Sign In Required</DialogTitle>
              <DialogDescription>You need to sign in to create a card.</DialogDescription>
            </DialogHeader>
            <DialogFooter className="flex-col gap-2 sm:flex-row">
              <Button
                variant="outline"
                onClick={() => setSignInDialogOpen(false)}
                className="w-full sm:w-auto"
              >
                Cancel
              </Button>
              <Button
                onClick={() => {
                  const currentUrl = window.location.pathname + window.location.search;
                  window.location.href = `/sign_in?redirect=${encodeURIComponent(currentUrl)}`;
                }}
                className="w-full sm:w-auto"
              >
                Sign In
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
};

export default CardOneOnOneNew;
