import React, { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Toaster, toast } from 'sonner';
import { StyleType } from '@/types/app';
import {
  X,
  Loader2,
  ArrowLeft,
  Users,
  Sparkles,
  Upload,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import CoverImageDialog from './CoverImageDialog';
import { useMutation, useLazyQuery, gql } from '@apollo/client';

interface EditCardSettingsViewProps {
  cardTitle: string;
  setCardTitle: (val: string) => void;
  occasion: string | undefined;
  occasions: string[];
  setOccasion: (val: string) => void;
  contributorPrompt: string;
  setContributorPrompt: (val: string) => void;
  recipients: string[];
  handleRecipientChange: (index: number, value: string) => void;
  handleRemoveRecipient: (index: number) => void;
  handleAddRecipient: () => void;
  backgroundColorStyles: StyleType[];
  selectedBackgroundColorId: string | null;
  setSelectedBackgroundColorId: (id: string) => void;
  textColorStyles: StyleType[];
  selectedTextColorId: string | null;
  setSelectedTextColorId: (id: string) => void;
  handleUpdateCard: () => Promise<void>;
  setEditingSettings: (val: boolean) => void;
  coverImage: string | Blob | null;
  setCoverImage: (img: string | Blob | null) => void;
  cardId: string;
  refetchCard: () => void;
  maxMessages: number;
  setMaxMessages: (val: number) => void;
  requireLoginToContribute: boolean;
  setRequireLoginToContribute: (val: boolean) => void;
  slug: string;
  setSlug: (val: string) => void;
}

const REMOVE_CARD_COVER_IMAGE = gql`
  mutation RemoveCardCoverImage($input: RemoveCardCoverImageInput!) {
    removeCardCoverImage(input: $input) {
      success
      errors
    }
  }
`;

const CHECK_SLUG_AVAILABILITY = gql`
  query CheckSlugAvailability($slug: String!, $type: String!, $currentId: String) {
    checkSlugAvailability(slug: $slug, type: $type, currentId: $currentId)
  }
`;

const EditCardSettings: React.FC<EditCardSettingsViewProps & { cardId: string }> = ({
  cardTitle,
  setCardTitle,
  occasion,
  occasions,
  setOccasion,
  contributorPrompt,
  setContributorPrompt,
  recipients,
  handleRecipientChange,
  handleRemoveRecipient,
  handleAddRecipient,
  backgroundColorStyles,
  selectedBackgroundColorId,
  setSelectedBackgroundColorId,
  textColorStyles,
  selectedTextColorId,
  setSelectedTextColorId,
  handleUpdateCard,
  setEditingSettings,
  coverImage,
  setCoverImage,
  cardId,
  refetchCard,
  maxMessages,
  setMaxMessages,
  requireLoginToContribute,
  setRequireLoginToContribute,
  slug,
  setSlug,
}) => {
  const [coverDialogOpen, setCoverDialogOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [slugError, setSlugError] = useState<string | null>(null);
  const [slugChecking, setSlugChecking] = useState(false);
  const [slugValid, setSlugValid] = useState(false);
  const debounceRef = useRef<NodeJS.Timeout | null>(null);
  const initialSlugRef = useRef(slug);

  const [removeCardCoverImage] = useMutation(REMOVE_CARD_COVER_IMAGE);
  const [checkSlugAvailability] = useLazyQuery(CHECK_SLUG_AVAILABILITY);

  // Check slug availability with debounce
  useEffect(() => {
    // Clear previous timeout
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    // Reset states
    setSlugError(null);
    setSlugValid(false);

    // Don't check if slug is empty or same as initial
    if (!slug || slug === initialSlugRef.current) {
      setSlugChecking(false);
      return;
    }

    // Validate slug format
    if (slug.length < 3) {
      setSlugError('URL must be at least 3 characters');
      return;
    }

    setSlugChecking(true);

    // Debounce the API call
    debounceRef.current = setTimeout(async () => {
      try {
        const { data } = await checkSlugAvailability({
          variables: { slug, type: 'card', currentId: cardId },
        });

        if (data?.checkSlugAvailability) {
          setSlugValid(true);
          setSlugError(null);
        } else {
          setSlugError('This URL is already taken');
          setSlugValid(false);
        }
      } catch {
        setSlugError('Failed to check availability');
      } finally {
        setSlugChecking(false);
      }
    }, 500);

    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, [slug, cardId, checkSlugAvailability]);

  const handleUpdateCardWithCover = async () => {
    setSaving(true);
    await handleUpdateCard(); // No argument, let parent handle mutation input
    setSaving(false);
  };

  const handleRemoveCoverImage = async () => {
    try {
      setCoverImage(null);
      const { data } = await removeCardCoverImage({ variables: { input: { cardId } } });
      if (data?.removeCardCoverImage?.success) {
        toast.success('Cover image removed successfully');
        refetchCard();
      } else {
        // Optionally show error toast
      }
    } catch {
      // Optionally show error toast
    }
  };

  return (
    <div className="space-y-6">
      <Toaster />
      <div className="flex items-center gap-2 mb-4">
        <button
          type="button"
          onClick={() => setEditingSettings(false)}
          className="flex items-center gap-2 text-purple-600 hover:text-purple-800 focus:outline-none font-semibold transition-colors"
          aria-label="Back to edit"
        >
          <ArrowLeft className="w-5 h-5" />
          <span className="text-base">Back to Edit</span>
        </button>
      </div>

      {/* Card Title Section */}
      <div className="space-y-2">
        <Label htmlFor="title" className="text-base font-semibold flex items-center gap-2">
          Card Title <span className="text-red-500">*</span>
        </Label>
        <Input
          id="title"
          type="text"
          placeholder="e.g., Happy Birthday Sarah!"
          value={cardTitle}
          onChange={e => setCardTitle(e.target.value)}
          className="text-lg border-2 focus:border-purple-400 transition-colors"
        />
      </div>

      {/* Recipients Section */}
      <div className="space-y-2">
        <Label className="text-base font-semibold flex items-center gap-2">
          <Users className="w-4 h-4 text-blue-500" />
          Recipients <span className="text-red-500">*</span>
        </Label>
        <p className="text-sm text-gray-600 mb-2">Who is this card for?</p>
        {recipients.map((recipient, index) => (
          <div key={index} className="flex items-center space-x-2">
            <Input
              placeholder="Recipient Name (e.g. John Doe)"
              value={recipient}
              onChange={e => handleRecipientChange(index, e.target.value)}
              className="border-2"
            />
            {recipients.length > 1 && (
              <Button
                size="icon"
                onClick={() => handleRemoveRecipient(index)}
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
            {occasions.map(occasion => (
              <SelectItem key={occasion} value={occasion}>
                {occasion}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Card Settings Section */}
      <div className="border-4 border-purple-300 rounded-2xl p-6 bg-gradient-to-br from-purple-50 to-pink-50 space-y-4">
        <h3 className="text-xl font-bold flex items-center gap-2">
          <Sparkles className="w-5 h-5 text-purple-600" />
          Card Settings
        </h3>

        {/* Max Messages Setting */}
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

        {/* Require Login Setting */}
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
            Give contributors a bit of context or a question to guide what they write. Shown above
            the message box while they type.
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

        {/* Custom URL Slug */}
        <div className="space-y-2 bg-white/70 p-4 rounded-xl">
          <Label htmlFor="slug" className="text-base font-semibold">
            Custom URL (Optional)
          </Label>
          <p className="text-sm text-gray-600 mb-2">
            Create a memorable link for sharing (e.g., "sarahs-birthday")
          </p>
          <div className="flex items-center gap-2">
            <span className="text-gray-500 text-sm whitespace-nowrap">cardjoy.app/p/card/</span>
            <div className="relative flex-1">
              <Input
                id="slug"
                type="text"
                placeholder="custom-url-name"
                value={slug}
                onChange={e => setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ''))}
                className={`border-2 pr-10 ${
                  slugError
                    ? 'border-red-400 focus:border-red-500'
                    : slugValid
                      ? 'border-green-400 focus:border-green-500'
                      : 'focus:border-purple-400'
                }`}
              />
              {slugChecking && (
                <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-gray-400" />
              )}
              {!slugChecking && slugError && (
                <AlertCircle className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-red-500" />
              )}
              {!slugChecking && slugValid && (
                <CheckCircle2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-green-500" />
              )}
            </div>
          </div>
          {slugError ? (
            <p className="text-xs text-red-500 mt-1">{slugError}</p>
          ) : (
            <p className="text-xs text-gray-500 mt-1">
              Only lowercase letters, numbers, and hyphens allowed
            </p>
          )}
        </div>
      </div>

      {/* Cover Image Picker */}
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
              onClick={handleRemoveCoverImage}
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
        <CoverImageDialog
          open={coverDialogOpen}
          onOpenChange={setCoverDialogOpen}
          onSelectCover={cover => {
            setCoverImage(cover);
            setCoverDialogOpen(false);
          }}
        />
      </div>

      {/* Background Color Picker */}
      <div className="space-y-2">
        <Label className="text-base font-semibold">Background Color</Label>
        <div className="flex flex-wrap gap-3">
          {backgroundColorStyles.map(style => (
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

      {/* Text Color Picker */}
      <div className="space-y-2">
        <Label className="text-base font-semibold">Text Color</Label>
        <div className="flex flex-wrap gap-3">
          {textColorStyles.map(style => (
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

      {/* Action Buttons */}
      <div className="pt-4 flex flex-col sm:flex-row sm:justify-end gap-3">
        <Button
          variant="outline"
          onClick={() => setEditingSettings(false)}
          className="w-full sm:w-auto border-2 hover:border-gray-400 font-bold text-lg h-14"
        >
          Cancel
        </Button>
        <Button
          onClick={handleUpdateCardWithCover}
          disabled={saving || !!slugError || slugChecking}
          className="w-full sm:w-auto bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold text-lg h-14 shadow-lg hover:shadow-xl transition-all disabled:opacity-50"
        >
          {saving ? (
            <>
              <Loader2 className="animate-spin w-4 h-4 mr-2" />
              Saving...
            </>
          ) : (
            'Save Changes'
          )}
        </Button>
      </div>
    </div>
  );
};

export default EditCardSettings;
