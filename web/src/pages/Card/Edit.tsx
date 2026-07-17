'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardContent, CardFooter } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { gql, useQuery, useMutation } from '@apollo/client';
import { useParams } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import getCroppedImg from '@/lib/crop-image';
import { Toaster, toast } from 'sonner';
import { StyleType, UserMessageType, GuestMessageType } from '@/types/app';
import { Area } from 'react-easy-crop';
import GuestEntry from './components/GuestEntry';
import ImageUploaderWithGiphy from './components/ImageUploaderWithGiphy';
import EditCardSettings from './components/EditCardSettings';
import CardOneOnOneEdit from './OneOnOneEdit';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { X } from 'lucide-react';
import { getGuestMessageIdKey } from '@/lib/utils';

const GET_CARD_KIND = gql`
  query CardKind($cardId: ID!) {
    card(cardId: $cardId) {
      kind
    }
  }
`;

const GET_CARD = gql`
  query Card($cardId: ID!) {
    card(cardId: $cardId) {
      title
      slug
      user {
        id
      }
      occasion
      recipients
      maxMessages
      requireLoginToContribute
      styles {
        id
        kind
        value
      }
      coverImageUrl
      messages {
        id
        title
        text
        imageUrl
        displayName
        user {
          id
        }
      }
      guestMessages {
        id
        name
        title
        text
        imageUrl
      }
    }
  }
`;

const UPDATE_CARD = gql`
  mutation UpdateCard($input: UpdateCardInput!) {
    updateCard(input: $input) {
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

interface CardInput {
  cardId: string | undefined;
  title: string;
  text?: string;
  file?: File;
  imageUrl?: string | null;
  userId?: string;
  guestName?: string;
  displayName?: string;
}

function PageEdit() {
  const { user, loading: userLoading } = useAuth();
  const [guestName, setGuestName] = useState<string | null>(null);
  const { cardExternalId } = useParams();
  const guestMessageIdKey = getGuestMessageIdKey(cardExternalId!);
  const guestMessageId = localStorage.getItem(guestMessageIdKey);
  const {
    data,
    loading: cardLoading,
    error: cardError,
    refetch,
  } = useQuery(GET_CARD, {
    variables: { cardId: cardExternalId },
    skip: !user && !guestMessageId,
  });

  const { data: occasionsData } = useQuery(GET_OCCASIONS);
  const occasions = occasionsData?.cardOccasions || [];
  const { data: styleData } = useQuery(GET_STYLES);
  const backgroundColorStyles = styleData?.backgroundColorStyles || [];
  const textColorStyles = styleData?.textColorStyles || [];
  const navigate = useNavigate();
  const [updateCard] = useMutation(UPDATE_CARD);

  const cardData = data?.card;
  const isCreator = String(cardData?.user.id) === String(user?.user_id);
  const [submitting, setSubmitting] = useState(false);

  const [cardTitle, setCardTitle] = useState('');
  const [recipients, setRecipients] = useState<string[]>([]);
  const [occasion, setOccasion] = useState<string | undefined>(undefined);
  const [messageTitle, setMessageTitle] = useState('');
  const [titleError, setTitleError] = useState<string | null>(null);
  const [text, setText] = useState('');
  const [textError, setTextError] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState('');
  const [editingSettings, setEditingSettings] = useState(false);

  // image
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [uploadError, setUploadError] = useState('');

  // card styles
  const backgroundColorStyle = cardData?.styles.find(
    (style: StyleType) => style.kind === 'background_color'
  );
  const textColorStyle = cardData?.styles.find((style: StyleType) => style.kind === 'text_color');
  const [selectedBackgroundColorId, setSelectedBackgroundColorId] = useState<string | null>(null);
  const [selectedTextColorId, setSelectedTextColorId] = useState<string | null>(null);

  // Add state for cover image for settings
  const [coverImage, setCoverImage] = useState<string | Blob | null>(null);
  const [showImageUploader, setShowImageUploader] = useState(false);

  // Card settings
  const [maxMessages, setMaxMessages] = useState<number>(20);
  const [requireLoginToContribute, setRequireLoginToContribute] = useState<boolean>(false);
  const [slug, setSlug] = useState<string>('');

  // Scroll to top on component mount (especially useful for mobile)
  useEffect(() => {
    window.scrollTo(0, 0);
  }, []);

  // Scroll to top when exiting edit settings mode
  useEffect(() => {
    if (!editingSettings) {
      window.scrollTo(0, 0);
    }
  }, [editingSettings]);

  const validations = { minLength: 10, maxLength: 5000, maxTitleLength: 100 };
  const validateText = useCallback(
    (value: string): string | null => {
      if (value.length < validations.minLength)
        return `Message is too short (minimum ${validations.minLength} characters required)`;
      if (value.length > validations.maxLength)
        return `Message is too long (maximum ${validations.maxLength} characters allowed)`;
      return null;
    },
    [validations.minLength, validations.maxLength]
  );

  const validateTitle = useCallback(
    // A 1-on-1 card's message carries no title, so this can be null.
    (title: string | null | undefined): string | null => {
      // Remove required check:
      if ((title?.length ?? 0) > validations.maxTitleLength)
        return `Message title is too long (maximum ${validations.maxTitleLength} characters allowed)`;
      return null;
    },
    [validations.maxTitleLength]
  );

  useEffect(() => {
    if (cardData) {
      const userMessage = cardData?.messages.find(
        (msg: UserMessageType) => String(msg.user.id) === String(user?.user_id)
      );
      const guestMessage = cardData?.guestMessages?.find(
        (msg: GuestMessageType) => String(msg.id) === String(guestMessageId)
      );
      setSelectedBackgroundColorId(backgroundColorStyle?.id || null);
      setSelectedTextColorId(textColorStyle?.id || null);
      setCardTitle(cardData.title);
      setRecipients(cardData.recipients);
      setMaxMessages(cardData.maxMessages || 20);
      setRequireLoginToContribute(cardData.requireLoginToContribute || false);
      setSlug(cardData.slug || '');
      if (userMessage) {
        setMessageTitle(userMessage.title ?? '');
        setText(userMessage.text);
        setDisplayName(userMessage.displayName || user?.name || '');
        setImageUrl(userMessage.imageUrl || null);
        setImagePreview(userMessage.imageUrl || null);
        setTitleError(validateTitle(userMessage.title));
        setTextError(validateText(userMessage.text));
      } else if (guestMessage) {
        setMessageTitle(guestMessage.title ?? '');
        setText(guestMessage.text ?? '');
        setGuestName(guestMessage.name);
        setImageUrl(guestMessage.imageUrl || null);
        setImagePreview(guestMessage.imageUrl || null);
        setTitleError(validateTitle(guestMessage.title));
        setTextError(validateText(guestMessage.text));
      } else {
        // Set default display name for new messages
        if (user) {
          setDisplayName(user.name || '');
        }
        setTitleError(validateTitle(''));
        setTextError(validateText(''));
      }
      // Always sync coverImage with cardData.coverImageUrl
      setCoverImage(cardData.coverImageUrl ?? null);
    }
  }, [
    cardData,
    validateText,
    validateTitle,
    guestMessageId,
    user,
    backgroundColorStyle?.id,
    textColorStyle?.id,
  ]);

  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value;
    setText(value);
    setTextError(validateText(value));
  };

  const handleMessageTitleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setMessageTitle(value);
    setTitleError(validateTitle(value));
  };

  const isCardMessageValid =
    !textError &&
    text.length >= validations.minLength &&
    text.length <= validations.maxLength &&
    !titleError &&
    messageTitle.length <= validations.maxTitleLength;

  // Update handleUpdateCard to handle file upload via FormData if coverImage is a Blob
  const handleUpdateCard = async () => {
    const selectedStyleIds = [selectedBackgroundColorId, selectedTextColorId].filter(Boolean);

    if (coverImage instanceof Blob) {
      // Use FormData upload (like CreateCoverStyleSheet)
      const formData = new FormData();
      formData.append(
        'operations',
        JSON.stringify({
          query: `
            mutation UpdateCard($input: UpdateCardInput!) {
              updateCard(input: $input) {
                success
                errors
              }
            }
          `,
          variables: {
            input: {
              cardId: cardExternalId,
              title: cardTitle,
              recipients,
              styleIds: selectedStyleIds,
              occasion,
              maxMessages,
              requireLoginToContribute,
              slug: slug.trim() || null,
              coverImageFile: null,
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
      if (json.errors || json.data.updateCard.errors.length > 0) {
        toast.error(
          'Upload failed: ' + (json.errors?.[0]?.message ?? json.data.updateCard.errors.join(', '))
        );
        return;
      }
    } else {
      // Use Apollo mutation for URL
      const input: Record<string, unknown> = {
        cardId: cardExternalId,
        title: cardTitle,
        recipients,
        styleIds: selectedStyleIds,
        occasion,
        maxMessages,
        requireLoginToContribute,
        slug: slug.trim() || null,
      };
      if (typeof coverImage === 'string' && coverImage) {
        input.coverImageUrl = coverImage;
      }
      await updateCard({
        variables: { input },
      });
    }
    setEditingSettings(false);
    refetch();
  };

  const handleUpsertMessage = async () => {
    if (!isCardMessageValid) return;
    setSubmitting(true);

    try {
      let fileToUpload = null;

      if (imageFile && imagePreview && croppedAreaPixels) {
        const croppedBlob = await getCroppedImg(imagePreview, croppedAreaPixels);
        fileToUpload = new File([croppedBlob], imageFile.name, { type: 'image/jpeg' });
      }

      const input: CardInput = {
        cardId: cardExternalId,
        title: messageTitle,
        text,
        file: undefined, // placeholder for file
        imageUrl: !fileToUpload ? imageUrl : null,
      };

      if (user) {
        input.userId = user.user_id;
        input.displayName = displayName;
      } else if (guestName) {
        input.guestName = guestName;
      }

      const formData = new FormData();

      formData.append(
        'operations',
        JSON.stringify({
          operationName: 'UpsertMessage',
          query: `
            mutation UpsertMessage($input: UpsertMessageInput!) {
              upsertMessage(input: $input) {
                success
                errors
                messageId
              }
            }
          `,
          variables: { input },
        })
      );

      formData.append('map', JSON.stringify({ '0': ['variables.input.file'] }));

      if (fileToUpload) {
        formData.append('0', fileToUpload);
      }

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

      if (json.errors || json.data.upsertMessage.errors.length > 0) {
        toast.error(
          'Upload failed: ' +
            (json.errors?.[0]?.message ?? json.data.upsertMessage.errors.join(', '))
        );
        return;
      } else {
        if (!user && json.data.upsertMessage.messageId) {
          localStorage.setItem(guestMessageIdKey, json.data.upsertMessage.messageId);
        }

        toast.success('Message updated successfully');
        navigate(`/card/${cardExternalId}/viewable`);
      }
    } catch (error) {
      console.error(error);
      toast.error('Unexpected error uploading message');
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemoveRecipient = (index: number) => {
    if (recipients.length > 1) {
      const updatedRecipients = recipients.filter((_, i) => i !== index);
      setRecipients(updatedRecipients);
    }
  };

  const handleAddRecipient = () => {
    setRecipients([...recipients, '']);
  };

  const handleRecipientChange = (index: number, value: string) => {
    const updatedRecipients = [...recipients];
    updatedRecipients[index] = value;
    setRecipients(updatedRecipients);
  };

  if (cardLoading || userLoading) return <LoadingScreen />;
  if (cardError) {
    console.log(cardError);
    return <ErrorScreen />;
  }

  // Check if login is required to contribute and user is not logged in and not creator
  if (cardData?.requireLoginToContribute && !user && !isCreator) {
    // Redirect to login with redirect back to edit page
    window.location.href = `/sign_in?redirect=/card/${cardExternalId}/edit`;
    return <LoadingScreen />; // Show loading while redirecting
  }

  if (!user && !guestName) {
    return (
      <GuestEntry
        onContinueAsGuest={name => setGuestName(name)}
        redirectToLogin={`/sign_in?redirect=/card/${cardExternalId}/edit`}
      />
    );
  }

  return (
    <div>
      <div className="min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 px-4 py-6 sm:px-10 sm:py-10">
        <Toaster />
        <Card className="w-full sm:max-w-4xl mx-auto p-4 sm:p-6 shadow-xl border-2 border-gray-200 bg-white/95 backdrop-blur">
          <CardHeader>
            {isCreator && !editingSettings ? (
              <>
                <h1
                  className="text-3xl font-bold cursor-pointer hover:underline transition bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent hover:from-purple-700 hover:via-pink-700 hover:to-blue-700"
                  onClick={() => navigate(`/card/${cardExternalId}/editable`)}
                >
                  {cardTitle}
                </h1>
                <div className="mt-4 flex flex-col sm:flex-row sm:items-start sm:gap-4">
                  <Button
                    className="w-full sm:w-[220px] mb-2 sm:mb-0 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 font-semibold"
                    onClick={() => setEditingSettings(true)}
                  >
                    Change Card Settings
                  </Button>
                  <Button
                    type="button"
                    className="w-full sm:w-[220px] mb-2 sm:mb-0 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 font-semibold"
                    onClick={() => setShowImageUploader(true)}
                  >
                    Add or Change Image
                  </Button>
                </div>
              </>
            ) : isCreator && editingSettings ? (
              <EditCardSettings
                cardTitle={cardTitle}
                occasion={occasion}
                occasions={occasions}
                setOccasion={setOccasion}
                setCardTitle={setCardTitle}
                recipients={recipients}
                handleRecipientChange={handleRecipientChange}
                handleRemoveRecipient={handleRemoveRecipient}
                handleAddRecipient={handleAddRecipient}
                backgroundColorStyles={backgroundColorStyles}
                selectedBackgroundColorId={selectedBackgroundColorId}
                setSelectedBackgroundColorId={setSelectedBackgroundColorId}
                textColorStyles={textColorStyles}
                selectedTextColorId={selectedTextColorId}
                setSelectedTextColorId={setSelectedTextColorId}
                handleUpdateCard={handleUpdateCard}
                setEditingSettings={setEditingSettings}
                coverImage={coverImage}
                setCoverImage={setCoverImage}
                cardId={cardExternalId!}
                refetchCard={refetch}
                maxMessages={maxMessages}
                setMaxMessages={setMaxMessages}
                requireLoginToContribute={requireLoginToContribute}
                setRequireLoginToContribute={setRequireLoginToContribute}
                slug={slug}
                setSlug={setSlug}
              />
            ) : (
              <>
                <h1
                  className="text-3xl font-bold cursor-pointer hover:underline transition bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent hover:from-purple-700 hover:via-pink-700 hover:to-blue-700"
                  onClick={() => navigate(`/card/${cardExternalId}/editable`)}
                >
                  {cardTitle}
                </h1>
                {!editingSettings && (
                  <div className="mt-4 flex flex-col sm:flex-row sm:items-start sm:gap-4">
                    <Button
                      type="button"
                      className="w-full sm:w-[220px] mb-2 sm:mb-0 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 font-semibold"
                      onClick={() => setShowImageUploader(true)}
                    >
                      Add or Change Image
                    </Button>
                  </div>
                )}
              </>
            )}
          </CardHeader>

          <CardContent>
            {!editingSettings && (
              <div>
                {imagePreview && (
                  <div className="w-full sm:w-[400px] lg:w-[480px] xl:w-[520px] relative mb-6">
                    <img
                      src={imagePreview}
                      alt="Selected"
                      className="w-full h-auto aspect-[3/2] object-cover rounded border"
                      style={{ maxHeight: '266px' }}
                    />
                    <button
                      type="button"
                      className="absolute top-2 right-2 z-10 bg-white rounded-full p-1 shadow hover:bg-gray-100"
                      onClick={() => {
                        setImageFile(null);
                        setImageUrl(null);
                        setImagePreview(null);
                        setCroppedAreaPixels(null);
                        setUploadError('');
                      }}
                      aria-label="Remove image"
                    >
                      <X className="w-5 h-5 text-gray-800" />
                    </button>
                  </div>
                )}
                <ImageUploaderWithGiphy
                  imagePreview={imagePreview}
                  setImageFile={setImageFile}
                  setImageUrl={setImageUrl}
                  setImagePreview={setImagePreview}
                  setCroppedAreaPixels={setCroppedAreaPixels}
                  uploadError={uploadError}
                  setUploadError={setUploadError}
                  crop={crop}
                  setCrop={setCrop}
                  zoom={zoom}
                  setZoom={setZoom}
                  showSheet={showImageUploader}
                  setShowSheet={setShowImageUploader}
                />

                {/* Message Text Area Section */}
                <div className="mb-6 space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="message-title" className="text-base font-semibold">
                      Message Title (Optional)
                    </Label>
                    <Input
                      id="message-title"
                      value={messageTitle}
                      onChange={handleMessageTitleChange}
                      placeholder="Give your message a title..."
                      className="w-full border-2 focus:border-purple-400"
                    />
                    {titleError && <p className="text-sm text-red-500 mt-1">{titleError}</p>}
                  </div>

                  {/* Display Name Field - only for logged in users */}
                  {user && (
                    <div className="space-y-2">
                      <Label htmlFor="display-name" className="text-base font-semibold">
                        Display Name
                      </Label>
                      <Input
                        id="display-name"
                        value={displayName}
                        onChange={e => setDisplayName(e.target.value)}
                        placeholder="How should your name appear on this message?"
                        className="w-full border-2 focus:border-blue-400"
                      />
                    </div>
                  )}

                  <div className="space-y-2">
                    <Label htmlFor="message" className="text-base font-semibold">
                      Your Message
                    </Label>
                    <Textarea
                      id="message"
                      value={text}
                      onChange={handleTextChange}
                      placeholder="Write your heartfelt message here..."
                      className="w-full border-2 focus:border-pink-400 resize-none"
                      style={{ height: '35vh' }}
                    />
                    {textError && <p className="text-sm text-red-500 mt-1">{textError}</p>}
                  </div>
                </div>

                <CardFooter className="flex justify-center pt-6">
                  <Button
                    type="submit"
                    disabled={!isCardMessageValid || submitting}
                    onClick={handleUpsertMessage}
                    className="w-full sm:w-auto bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold text-lg py-6 px-8 shadow-lg hover:shadow-xl transition-all"
                  >
                    {submitting ? 'Submitting...' : 'Submit Message'}
                  </Button>
                </CardFooter>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

// A 1-on-1 card is a single message with no message wall or contributor
// settings, so it gets its own editor. Dispatch on kind before rendering either.
function CardEdit() {
  const { cardExternalId } = useParams();
  const { data, loading } = useQuery(GET_CARD_KIND, {
    variables: { cardId: cardExternalId },
  });

  if (loading) return <LoadingScreen />;
  if (data?.card?.kind === 'one_on_one') return <CardOneOnOneEdit />;
  return <PageEdit />;
}

export default CardEdit;
