import React, { useState, useEffect, useMemo } from 'react';
import { gql, useQuery, useMutation } from '@apollo/client';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Toaster, toast } from 'sonner';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { useAuth } from '@/contexts/AuthContext';
import { useOrganization } from '@/contexts/OrganizationContext';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { isInsufficientCreditsError, INSUFFICIENT_CREDITS_REDIRECT } from '@/lib/credits';
import { StyleType } from '@/types/app';
import { cardTypeById } from '@/config/cardTypes';
import { X, Sparkles, Upload, Users, Heart } from 'lucide-react';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import CoverImageDialog from './components/CoverImageDialog';
import { captureError, captureInfo } from '@/lib/posthog-capture';

const CREATE_CARD = gql`
  mutation CreateCard($input: CreateCardInput!) {
    createCard(input: $input) {
      card {
        externalId
        title
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
    backgroundColorStyles: styles(kind: "background_color") {
      id
      name
      value
    }
    textColorStyles: styles(kind: "text_color") {
      id
      name
      value
    }
  }
`;

const CardNew: React.FC = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  // A card started from an organization dashboard belongs to that organization. The
  // server re-checks membership; this only supplies the default context.
  const { activeOrganization } = useOrganization();
  const [searchParams] = useSearchParams();

  const [newCard, setNewCard] = useState({ title: '', recipients: [''] });
  const [creating, setCreating] = useState(false);
  const [coverDialogOpen, setCoverDialogOpen] = useState(false);
  const [signInDialogOpen, setSignInDialogOpen] = useState(false);

  const [coverImage, setCoverImage] = useState<string | Blob | null>(null);
  const [selectedBackgroundColorId, setSelectedBackgroundColorId] = useState<string | null>(null);
  const [selectedTextColorId, setSelectedTextColorId] = useState<string | null>(null);

  // Card settings
  const [maxMessages, setMaxMessages] = useState<number>(20);
  const [requireLoginToContribute, setRequireLoginToContribute] = useState<boolean>(false);
  const [contributorPrompt, setContributorPrompt] = useState<string>('');

  const [createCard] = useMutation(CREATE_CARD);

  const { data: occasionsData } = useQuery(GET_OCCASIONS);
  const occasions = useMemo(() => occasionsData?.cardOccasions || [], [occasionsData]);
  const [occasion, setOccasion] = useState<string | undefined>(undefined);

  // Pre-populate occasion from URL parameter
  useEffect(() => {
    const presetOccasion = searchParams.get('occasion');
    if (presetOccasion && occasions.includes(presetOccasion)) {
      setOccasion(presetOccasion);
    }
  }, [searchParams, occasions]);

  const { data: styleData } = useQuery(GET_STYLES);
  const backgroundColorStyles = useMemo(() => styleData?.backgroundColorStyles || [], [styleData]);
  const textColorStyles = useMemo(() => styleData?.textColorStyles || [], [styleData]);

  const isFormValid =
    newCard.title.trim() !== '' && newCard.recipients.some(name => name.trim() !== '');

  const handleCreateCard = async () => {
    if (!isFormValid) return;

    // Check if user is logged in
    if (!user) {
      setSignInDialogOpen(true);
      return;
    }

    const styleIds = [selectedBackgroundColorId, selectedTextColorId].filter(Boolean);
    setCreating(true);

    try {
      if (coverImage instanceof Blob) {
        // Use FormData for file upload, matching handleUpdateCard
        const formData = new FormData();
        formData.append(
          'operations',
          JSON.stringify({
            query: `
              mutation CreateCard($input: CreateCardInput!) {
                createCard(input: $input) {
                  card { externalId title }
                  errors
                }
              }
            `,
            variables: {
              input: {
                title: newCard.title,
                recipients: newCard.recipients,
                styleIds,
                occasion,
                contributorPrompt: contributorPrompt.trim() || null,
                maxMessages,
                requireLoginToContribute,
                coverImageFile: null,
                organizationId: activeOrganization?.id ?? null,
              },
            },
          })
        );
        formData.append('map', JSON.stringify({ '0': ['variables.input.coverImageFile'] }));
        formData.append('0', coverImage, 'cover.jpg');
        const token = localStorage.getItem(APP_TOKEN_KEY);
        const res = await fetch(import.meta.env.VITE_GRAPHQL_ENDPOINT, {
          method: 'POST',
          body: formData,
          credentials: 'include',
          headers: {
            Authorization: token ? `Bearer ${token}` : '',
          },
        });
        const json = await res.json();
        if (json.errors || json.data.createCard.errors.length > 0) {
          const mutationErrors = json.data?.createCard?.errors ?? json.errors ?? [];
          if (isInsufficientCreditsError(mutationErrors)) {
            navigate(INSUFFICIENT_CREDITS_REDIRECT);
            return;
          }
          toast.error(
            'Upload failed: ' +
              (json.errors?.[0]?.message ?? json.data.createCard.errors.join(', '))
          );
          captureError('Card Creation Error', {
            errors: json.errors || json.data.createCard.errors,
          });
        } else {
          setNewCard({ title: '', recipients: [''] });
          setCoverImage(null);
          setContributorPrompt('');
          toast.success('Card created successfully!');
          captureInfo('Card Created', {
            cardTitle: json.data.createCard.card.title,
            cardId: json.data.createCard.card.externalId,
          });
          setTimeout(() => {
            navigate(`/card/${json.data.createCard.card.externalId}/edit`);
          }, 500);
        }
      } else {
        // Use Apollo mutation for URL or no image
        const input: Record<string, unknown> = {
          title: newCard.title,
          recipients: newCard.recipients,
          styleIds,
          occasion,
          contributorPrompt: contributorPrompt.trim() || null,
          maxMessages,
          requireLoginToContribute,
          organizationId: activeOrganization?.id ?? null,
        };
        if (typeof coverImage === 'string' && coverImage) {
          input.coverImageUrl = coverImage;
        }
        const { data } = await createCard({
          variables: { input },
        });
        if (data.createCard.errors.length === 0) {
          setNewCard({ title: '', recipients: [''] });
          setCoverImage(null);
          setContributorPrompt('');
          toast.success('Card created successfully!');
          captureInfo('Card Created', {
            cardTitle: data.createCard.card.title,
            cardId: data.createCard.card.externalId,
          });
          setTimeout(() => {
            navigate(`/card/${data.createCard.card.externalId}/edit`);
          }, 500);
        } else {
          if (isInsufficientCreditsError(data.createCard.errors)) {
            navigate(INSUFFICIENT_CREDITS_REDIRECT);
            return;
          }
          toast.error(data.createCard.errors.join(', ') || 'Failed to create card');
          captureError('Card Creation Error', {
            errors: data.createCard.errors,
          });
        }
      }
    } catch (err) {
      toast.error('An error occurred while creating the card. Please try again.');
      captureError('Unknown Card Creation Error', {
        error: err instanceof Error ? err.message : String(err),
        userId: user?.user_id || 'unknown',
      });
    } finally {
      setCreating(false);
    }
  };

  const handleAddRecipient = () =>
    setNewCard({ ...newCard, recipients: [...newCard.recipients, ''] });

  const handleRemoveRecipient = (index: number) => {
    if (newCard.recipients.length > 1) {
      const updated = newCard.recipients.filter((_, i) => i !== index);
      setNewCard({ ...newCard, recipients: updated });
    }
  };

  const handleRecipientChange = (index: number, value: string) => {
    const updated = [...newCard.recipients];
    updated[index] = value;
    setNewCard({ ...newCard, recipients: updated });
  };

  useEffect(() => {
    if (!selectedBackgroundColorId && backgroundColorStyles.length > 0) {
      setSelectedBackgroundColorId(backgroundColorStyles[0].id);
    }

    if (!selectedTextColorId && textColorStyles.length > 0) {
      setSelectedTextColorId(textColorStyles[0].id);
    }
  }, [backgroundColorStyles, textColorStyles, selectedBackgroundColorId, selectedTextColorId]);

  return (
    <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="w-full mx-auto px-4 py-8 max-w-full sm:max-w-[85%] lg:max-w-[70%] xl:max-w-[60%] mt-16">
        <Toaster />

        {/* Fun Header */}
        <div className="text-center mb-8">
          <h1
            className={`text-4xl sm:text-5xl font-bold mb-3 bg-gradient-to-r ${cardTypeById.group.gradient} bg-clip-text text-transparent`}
          >
            Create Your Group Card
          </h1>
          <p className="text-gray-600 text-lg">
            Collect heartfelt messages from everyone who cares
          </p>
        </div>

        <Card className="shadow-xl border-2 border-gray-200 bg-white/95 backdrop-blur">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-2xl">
              <Heart className="w-6 h-6 text-pink-500" />
              Card Details
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6 pt-6">
            {/* Card Title */}
            <div className="space-y-2">
              <Label htmlFor="title" className="text-base font-semibold flex items-center gap-2">
                Card Title <span className="text-red-500">*</span>
              </Label>
              <Input
                id="title"
                placeholder="e.g., Happy Birthday Sarah!"
                value={newCard.title}
                onChange={e => setNewCard({ ...newCard, title: e.target.value })}
                className="text-lg border-2 focus:border-purple-400 transition-colors"
              />
            </div>

            {/* Recipients */}
            <div className="space-y-2">
              <Label className="text-base font-semibold flex items-center gap-2">
                <Users className="w-4 h-4 text-blue-500" />
                Recipients <span className="text-red-500">*</span>
              </Label>
              <p className="text-sm text-gray-600 mb-2">Who is this card for?</p>
              {newCard.recipients.map((recipient, i) => (
                <div key={i} className="flex items-center space-x-2">
                  <Input
                    placeholder={`Recipient Name (e.g. John Doe)`}
                    value={recipient}
                    onChange={e => handleRecipientChange(i, e.target.value)}
                    className="border-2"
                  />
                  {newCard.recipients.length > 1 && (
                    <Button
                      size="icon"
                      onClick={() => handleRemoveRecipient(i)}
                      variant="outline"
                      className="border-2 hover:border-red-400 hover:bg-red-50"
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              ))}
              <Button
                variant="outline"
                onClick={handleAddRecipient}
                className="w-full border-2 border-dashed hover:border-purple-400 hover:bg-purple-50"
              >
                + Add Another Recipient
              </Button>
            </div>

            {/* Occasion Picker */}
            <div className="space-y-2">
              <Label className="text-base font-semibold">Occasion (Optional)</Label>
              <Select value={occasion} onValueChange={setOccasion}>
                <SelectTrigger className="border-2">
                  <SelectValue placeholder="Select an Occasion" />
                </SelectTrigger>
                <SelectContent>
                  {occasions.map((occasion: string) => (
                    <SelectItem key={occasion} value={occasion}>
                      {occasion}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Card Settings */}
            <div className="border-4 border-purple-300 rounded-2xl p-6 bg-gradient-to-br from-purple-50 to-pink-50 space-y-4">
              <h3 className="text-xl font-bold flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-purple-600" />
                Card Settings
              </h3>

              {/* Max Messages */}
              <div className="space-y-2">
                <Label htmlFor="maxMessages" className="text-base font-semibold">
                  Maximum Messages
                </Label>
                <p className="text-sm text-gray-600 mb-2">
                  Set the maximum number of messages this card can receive
                </p>
                <div className="flex flex-wrap gap-2">
                  {[20, 50, 100, 500, 1000].map(value => (
                    <button
                      key={value}
                      type="button"
                      onClick={() => setMaxMessages(value)}
                      className={`px-4 py-2 rounded-lg border-2 transition-all font-medium text-sm ${
                        maxMessages === value
                          ? 'border-purple-500 bg-purple-100 text-purple-700 shadow-sm scale-105'
                          : 'bg-white border-gray-200 text-gray-700 hover:border-purple-300 hover:bg-purple-50'
                      }`}
                    >
                      {value}
                    </button>
                  ))}
                </div>
              </div>

              {/* Require Login to Contribute */}
              <div className="flex items-center justify-between bg-white/70 p-4 rounded-xl">
                <div>
                  <Label className="text-base font-semibold">Require Login to Contribute</Label>
                  <p className="text-sm text-gray-600 mt-1">
                    When enabled, only logged-in users can leave messages on this card
                  </p>
                </div>
                <Switch
                  checked={requireLoginToContribute}
                  onCheckedChange={setRequireLoginToContribute}
                />
              </div>

              {/* Contributor Prompt */}
              <div className="space-y-2 bg-white/70 p-4 rounded-xl">
                <Label htmlFor="contributorPrompt" className="text-base font-semibold">
                  Message Prompt for Contributors (Optional)
                </Label>
                <p className="text-sm text-gray-600 mb-2">
                  Give contributors a bit of context or a question to guide what they write. Shown
                  above the message box while they type.
                </p>
                <Textarea
                  id="contributorPrompt"
                  value={contributorPrompt}
                  onChange={e => setContributorPrompt(e.target.value.slice(0, 500))}
                  placeholder="e.g., It's Sarah's first day at her first job — what career advice would you give her?"
                  className="border-2 focus:border-purple-400 resize-none"
                  rows={3}
                />
                <p className="text-xs text-gray-500 text-right">{contributorPrompt.length}/500</p>
              </div>
            </div>

            {/* Cover Image Dialog Trigger */}
            <div className="space-y-2">
              <Label className="text-base font-semibold flex items-center gap-2">
                <Upload className="w-4 h-4" />
                Cover Image (Optional)
              </Label>
              {coverImage ? (
                <div className="relative w-full">
                  <img
                    src={coverImage instanceof Blob ? URL.createObjectURL(coverImage) : coverImage}
                    alt="Selected Cover"
                    className="w-full h-64 object-cover rounded-xl border-4 border-white shadow-lg"
                  />
                  <button
                    type="button"
                    className="absolute top-3 right-3 bg-white/90 hover:bg-white rounded-full p-2 shadow-lg transition-all hover:scale-110"
                    onClick={() => setCoverImage(null)}
                    aria-label="Remove cover image"
                  >
                    <X className="w-5 h-5 text-gray-700" />
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => setCoverDialogOpen(true)}
                  className="w-full h-48 border-4 border-dashed border-gray-300 rounded-xl hover:border-purple-400 hover:bg-purple-50/50 transition-all flex flex-col items-center justify-center gap-3 group"
                >
                  <Upload className="w-12 h-12 text-gray-400 group-hover:text-purple-500 transition-colors" />
                  <span className="text-gray-500 group-hover:text-purple-600 font-medium">
                    Click to add a cover image
                  </span>
                </button>
              )}
            </div>

            {/* Cover Image Dialog */}
            <CoverImageDialog
              open={coverDialogOpen}
              onOpenChange={setCoverDialogOpen}
              onSelectCover={cover => {
                setCoverImage(cover);
                setCoverDialogOpen(false);
              }}
            />

            {/* Sign In Dialog */}
            <Dialog open={signInDialogOpen} onOpenChange={setSignInDialogOpen}>
              <DialogContent className="sm:max-w-md">
                <DialogHeader>
                  <DialogTitle>Sign In Required</DialogTitle>
                  <DialogDescription>You need to sign in to create a card.</DialogDescription>
                </DialogHeader>
                <DialogFooter className="flex-col sm:flex-row gap-2">
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

            {/* Background Colors */}
            <div className="space-y-2">
              <Label className="text-base font-semibold">Background Color</Label>
              <div className="flex flex-wrap gap-3">
                {backgroundColorStyles.map((style: StyleType) => (
                  <button
                    key={style.id}
                    onClick={() => setSelectedBackgroundColorId(style.id)}
                    title={style.name}
                    className={`w-12 h-12 rounded-xl border-2 transition-all hover:scale-110 ${
                      selectedBackgroundColorId === style.id
                        ? 'border-purple-500 ring-4 ring-purple-200 scale-110'
                        : 'border-gray-300 hover:border-purple-300'
                    }`}
                    style={{ backgroundColor: style.value }}
                  />
                ))}
              </div>
            </div>

            {/* Text Colors */}
            <div className="space-y-2">
              <Label className="text-base font-semibold">Text Color</Label>
              <div className="flex flex-wrap gap-3">
                {textColorStyles.map((style: StyleType) => (
                  <button
                    key={style.id}
                    onClick={() => setSelectedTextColorId(style.id)}
                    title={style.name}
                    className={`w-12 h-12 rounded-xl border-2 transition-all hover:scale-110 ${
                      selectedTextColorId === style.id
                        ? 'border-pink-500 ring-4 ring-pink-200 scale-110'
                        : 'border-gray-300 hover:border-pink-300'
                    }`}
                    style={{ backgroundColor: style.value }}
                  />
                ))}
              </div>
            </div>

            {/* Submit Buttons */}
            <div className="pt-4 flex flex-col sm:flex-row sm:justify-end gap-3">
              <Button
                variant="outline"
                onClick={() => navigate('/')}
                className="w-full sm:w-auto border-2 hover:border-gray-400 font-bold text-lg h-14"
              >
                Cancel
              </Button>
              <Button
                onClick={handleCreateCard}
                disabled={!isFormValid || creating}
                className={`w-full sm:w-auto bg-gradient-to-r ${cardTypeById.group.gradient} hover:opacity-90 text-white font-bold text-lg h-14 shadow-lg hover:shadow-xl transition-all`}
              >
                {creating ? 'Creating...' : 'Create Card'}
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default CardNew;
