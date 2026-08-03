import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { gql, useQuery, useMutation, useLazyQuery } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import {
  Calendar,
  Clock,
  MapPin,
  Users,
  Sparkles,
  CalendarPlus,
  Download,
  ArrowLeft,
  Settings,
} from 'lucide-react';
import RSVPForm from './components/RSVPForm';
import RSVPGuestEntry from './components/RSVPGuestEntry';
import OpeningScreen from './components/OpeningScreen';
import { OpeningMessagePlayer } from './components/OpeningMessagePlayer';
import WishListCallout from './components/WishListCallout';
import LoadingScreen from '@/components/Loading';
import { WISH_LIST_FIELDS } from '@/lib/wishList';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from 'sonner';
import type { OpeningMessageConfig } from '@/types/openingMessage';

interface ExistingRsvp {
  id: string;
  guestName: string;
  guestEmail: string;
  status: string;
  plusOne: boolean;
  additionalGuestsCount?: number;
  plusOneName?: string | null;
  message?: string | null;
}

interface CalendarLinks {
  google: string;
  outlook: string;
  yahoo: string;
  ics: string;
}

const GET_INVITATION = gql`
  query GetInvitation($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      externalId
      title
      description
      location
      eventDate
      eventTime
      eventTimezone
      rsvpDeadline
      coverImageUrl
      maxAdditionalGuests
      attire
      customInstructions
      openingMessage
      openingMessageConfig {
        templateId
        text {
          title
          subtitle
          transform {
            x
            y
            rotation
            scale
          }
        }
        theme {
          font
          textColor
        }
        background {
          type
          value
          overlayOpacity
          imageTransform {
            x
            y
            scale
            rotation
          }
        }
        animation {
          preset
          durationMs
        }
      }
      user {
        id
      }
      rsvpCounts {
        going
        maybe
        notGoing
        total
        totalAttendees
      }
      wishList {
        ${WISH_LIST_FIELDS}
      }
    }
  }
`;

const CREATE_RSVP = gql`
  mutation CreateRsvp($input: CreateRsvpInput!) {
    createRsvp(input: $input) {
      rsvp {
        id
        guestName
        guestEmail
        status
        plusOne
        plusOneName
        message
      }
      errors
      calendarLinks {
        google
        outlook
        yahoo
        ics
      }
    }
  }
`;

const CHECK_RSVP = gql`
  query CheckRsvp($invitationId: ID!, $email: String!) {
    checkRsvp(invitationId: $invitationId, email: $email) {
      id
      guestName
      guestEmail
      status
      plusOne
      additionalGuestsCount
      plusOneName
      message
    }
  }
`;

const getSessionStorageKey = (invitationId: string) => `invitation_opened_${invitationId}`;
const getRsvpEmailKey = (invitationId: string) => `rsvp_email_${invitationId}`;
const getLocalStorageRsvpKey = (invitationId: string) => `cardjoy_rsvp_${invitationId}`;

const InvitationView: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [hasRSVPd, setHasRSVPd] = useState(false);
  const [rsvpStatus, setRsvpStatus] = useState<string | null>(null);
  const [calendarLinks, setCalendarLinks] = useState<CalendarLinks | null>(null);
  const [isOpened, setIsOpened] = useState(false);
  const [isRevealing, setIsRevealing] = useState(false);
  const [isGuestMode, setIsGuestMode] = useState(false);
  const [existingRsvp, setExistingRsvp] = useState<ExistingRsvp | null>(null);
  const [isUpdatingRsvp, setIsUpdatingRsvp] = useState(false);

  const { data, loading, error } = useQuery(GET_INVITATION, {
    variables: { externalId: id },
    skip: !id,
    onError: err => {
      console.error(err);
      toast.error('Failed to load invitation');
      navigate('/');
    },
  });

  const invitation = data?.invitation;

  // Check if current user is the creator of this invitation
  const isCreator = user?.user_id && invitation?.user?.id && user.user_id === invitation.user.id;

  const [createRsvp] = useMutation(CREATE_RSVP, {
    refetchQueries: [{ query: GET_INVITATION, variables: { externalId: id } }],
  });

  const [checkRsvp] = useLazyQuery(CHECK_RSVP, {
    fetchPolicy: 'network-only',
    onCompleted: data => {
      if (data?.checkRsvp) {
        setExistingRsvp(data.checkRsvp);
        setHasRSVPd(true);
        setRsvpStatus(data.checkRsvp.status);
      }
    },
  });

  // Check storage on mount for opened state
  useEffect(() => {
    if (id) {
      const wasOpened = sessionStorage.getItem(getSessionStorageKey(id));
      if (wasOpened === 'true') {
        setIsOpened(true);
      }
    }
  }, [id]);

  // Check for existing RSVP once invitation is loaded
  useEffect(() => {
    if (id && invitation?.id) {
      // Priority for checking existing RSVP:
      // 1. Logged-in user's email
      // 2. Email stored in localStorage (persists across sessions)
      // 3. Email stored in sessionStorage (legacy, for backwards compatibility)
      const emailToCheck =
        user?.email ||
        localStorage.getItem(getLocalStorageRsvpKey(id)) ||
        sessionStorage.getItem(getRsvpEmailKey(id));

      if (emailToCheck) {
        // Use invitation.id (internal ID) not id (external ID from URL)
        checkRsvp({ variables: { invitationId: invitation.id, email: emailToCheck } });
      }
    }
  }, [id, invitation?.id, user?.email, checkRsvp]);

  const handleOpenInvitation = () => {
    if (id) {
      sessionStorage.setItem(getSessionStorageKey(id), 'true');
    }
    setIsRevealing(true);
    // Small delay for the fade-out animation before showing content
    setTimeout(() => {
      setIsOpened(true);
    }, 300);
  };
  const rsvpCounts = invitation?.rsvpCounts || {
    going: 0,
    maybe: 0,
    notGoing: 0,
    total: 0,
    totalAttendees: 0,
  };

  if (loading) return <LoadingScreen />;
  if (error || !invitation) {
    return null; // Will redirect in onError
  }

  // Transform GraphQL response to OpeningMessageConfig format
  const getOpeningMessageConfig = (): OpeningMessageConfig | null => {
    if (invitation.openingMessageConfig) {
      const config = invitation.openingMessageConfig;
      return {
        template_id: config.templateId,
        text: {
          title: config.text.title,
          subtitle: config.text.subtitle,
        },
        theme: config.theme
          ? {
              font: config.theme.font,
              text_color: config.theme.textColor,
            }
          : undefined,
        background: config.background
          ? {
              type: config.background.type,
              value: config.background.value,
              overlay_opacity: config.background.overlayOpacity,
            }
          : undefined,
        animation: config.animation
          ? {
              preset: config.animation.preset,
              duration_ms: config.animation.durationMs,
            }
          : undefined,
      };
    }
    return null;
  };

  const openingConfig = getOpeningMessageConfig();

  // Show opening screen if not yet opened (skip for creators)
  if (!isOpened && !isCreator) {
    // Use new OpeningMessagePlayer if config exists
    if (openingConfig) {
      return (
        <OpeningMessagePlayer
          config={openingConfig}
          onComplete={handleOpenInvitation}
          isVisible={!isRevealing}
        />
      );
    }
    // Fallback to legacy OpeningScreen
    return (
      <div
        className={`transition-opacity duration-300 ${isRevealing ? 'opacity-0' : 'opacity-100'}`}
      >
        <OpeningScreen message={invitation.openingMessage} onOpen={handleOpenInvitation} />
      </div>
    );
  }

  const handleRSVPSubmit = async (data: {
    status: 'going' | 'maybe' | 'not-going';
    guestName: string;
    guestEmail: string;
    plusOne: boolean;
    additionalGuestsCount: number;
    plusOneName?: string;
    message?: string;
  }) => {
    const isUpdate = !!existingRsvp;

    try {
      const result = await createRsvp({
        variables: {
          input: {
            invitationId: invitation.id,
            guestName: data.guestName,
            guestEmail: data.guestEmail,
            status: data.status,
            plusOne: data.plusOne,
            additionalGuestsCount: data.additionalGuestsCount,
            plusOneName: data.plusOneName,
            message: data.message,
          },
        },
      });

      if (result.data?.createRsvp?.errors?.length > 0) {
        toast.error(result.data.createRsvp.errors[0]);
        return;
      }

      // Store email in localStorage for future visits (persists across browser sessions)
      if (id) {
        localStorage.setItem(getLocalStorageRsvpKey(id), data.guestEmail);
        // Also keep sessionStorage for backwards compatibility
        sessionStorage.setItem(getRsvpEmailKey(id), data.guestEmail);
      }

      setHasRSVPd(true);
      setRsvpStatus(data.status);
      setIsUpdatingRsvp(false);
      setExistingRsvp(result.data?.createRsvp?.rsvp || null);

      if (result.data?.createRsvp?.calendarLinks) {
        setCalendarLinks(result.data.createRsvp.calendarLinks);
      }

      if (isUpdate) {
        toast.success('RSVP updated!');
      }
    } catch (error) {
      console.error('RSVP error:', error);
      throw error;
    }
  };

  const downloadIcsFile = () => {
    if (!calendarLinks?.ics) return;

    const blob = new Blob([calendarLinks.ics], { type: 'text/calendar;charset=utf-8' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${invitation.title.replace(/[^a-z0-9]/gi, '_')}.ics`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  };

  const eventDate = new Date(`${invitation.eventDate}T${invitation.eventTime}`);
  const isRSVPClosed = invitation.rsvpDeadline
    ? new Date(invitation.rsvpDeadline) < new Date()
    : false;

  return (
    <div className="flex flex-col min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50 animate-fade-in">
      {/* Creator Navigation Bar */}
      {isCreator && (
        <div className="fixed top-0 left-0 right-0 z-50 bg-white/95 backdrop-blur border-b shadow-sm">
          <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
            <Link
              to="/"
              className="flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              <span className="font-medium">Dashboard</span>
            </Link>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-500">Viewing as creator</span>
              <Link to={`/invitation/${id}/edit`}>
                <Button variant="outline" size="sm" className="gap-2">
                  <Settings className="w-4 h-4" />
                  Edit
                </Button>
              </Link>
            </div>
          </div>
        </div>
      )}

      <div
        className={`w-full mx-auto px-4 py-8 max-w-full sm:max-w-[90%] lg:max-w-[80%] xl:max-w-[70%] ${isCreator ? 'mt-20' : 'mt-16'}`}
      >
        {/* Cover Image */}
        {invitation.coverImageUrl && (
          <div className="mb-8">
            <img
              src={invitation.coverImageUrl}
              alt={invitation.title}
              className="w-full h-64 sm:h-80 md:h-96 object-cover rounded-3xl shadow-2xl border-8 border-white"
            />
          </div>
        )}

        {/* Main Content */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Event Details */}
          <div className="lg:col-span-2 space-y-6">
            {/* Title and Description */}
            <Card className="p-8 bg-white/95 backdrop-blur border-2 shadow-xl">
              <h1 className="text-4xl sm:text-5xl font-bold mb-4 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent">
                {invitation.title}
              </h1>

              {invitation.description && (
                <p className="text-lg text-gray-700 leading-relaxed">{invitation.description}</p>
              )}
            </Card>

            {/* Event Info */}
            <Card className="p-6 bg-white/95 backdrop-blur border-2 space-y-4">
              <div className="flex items-start gap-4">
                <div className="bg-gradient-to-br from-pink-400 to-pink-600 p-3 rounded-xl">
                  <Calendar className="w-6 h-6 text-white" />
                </div>
                <div>
                  <div className="font-semibold text-gray-600">Date</div>
                  <div className="text-xl font-bold">
                    {eventDate.toLocaleDateString('en-US', {
                      weekday: 'long',
                      year: 'numeric',
                      month: 'long',
                      day: 'numeric',
                    })}
                  </div>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="bg-gradient-to-br from-blue-400 to-blue-600 p-3 rounded-xl">
                  <Clock className="w-6 h-6 text-white" />
                </div>
                <div>
                  <div className="font-semibold text-gray-600">Time</div>
                  <div className="text-xl font-bold">
                    {eventDate.toLocaleTimeString('en-US', {
                      hour: 'numeric',
                      minute: '2-digit',
                      hour12: true,
                    })}
                  </div>
                </div>
              </div>

              {invitation.location && (
                <div className="flex items-start gap-4">
                  <div className="bg-gradient-to-br from-green-400 to-green-600 p-3 rounded-xl">
                    <MapPin className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <div className="font-semibold text-gray-600">Location</div>
                    <div className="text-xl font-bold">{invitation.location}</div>
                  </div>
                </div>
              )}
            </Card>

            {/* Special Instructions */}
            {((invitation.maxAdditionalGuests || 0) > 0 ||
              invitation.attire ||
              invitation.customInstructions) && (
              <Card className="p-6 bg-gradient-to-br from-yellow-50 to-pink-50 border-4 border-yellow-300 shadow-xl">
                <h3 className="text-2xl font-bold mb-4 flex items-center gap-2">
                  <Sparkles className="w-6 h-6 text-yellow-600" />
                  Special Instructions
                </h3>

                <div className="space-y-3">
                  {(invitation.maxAdditionalGuests || 0) > 0 && (
                    <div className="bg-white/70 p-4 rounded-xl border-2 border-purple-200">
                      <div className="font-bold text-purple-700">Additional Guests Welcome!</div>
                      <div className="text-gray-700">
                        You may bring up to {invitation.maxAdditionalGuests} additional{' '}
                        {invitation.maxAdditionalGuests === 1 ? 'guest' : 'guests'}
                      </div>
                    </div>
                  )}

                  {invitation.attire && (
                    <div className="bg-white/70 p-4 rounded-xl border-2 border-blue-200">
                      <div className="font-bold text-blue-700">Dress Code</div>
                      <div className="text-gray-700">{invitation.attire}</div>
                    </div>
                  )}

                  {invitation.customInstructions && (
                    <div className="bg-white/70 p-4 rounded-xl border-2 border-pink-200">
                      <div className="font-bold text-pink-700">Additional Info</div>
                      <div className="text-gray-700 whitespace-pre-wrap">
                        {invitation.customInstructions}
                      </div>
                    </div>
                  )}
                </div>
              </Card>
            )}
          </div>

          {/* Right Column - RSVP */}
          <div className="space-y-6">
            {/* RSVP Stats */}
            <Card className="p-5 bg-white/95 backdrop-blur border">
              <h3 className="text-base font-semibold mb-4 flex items-center gap-2 text-gray-700">
                <Users className="w-4 h-4" />
                Responses
              </h3>

              <div className="space-y-2">
                <div className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-green-500"></span>
                    <span className="text-sm text-gray-600">Going</span>
                  </div>
                  <span className="text-lg font-semibold text-gray-900">{rsvpCounts.going}</span>
                </div>

                <div className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-amber-500"></span>
                    <span className="text-sm text-gray-600">Maybe</span>
                  </div>
                  <span className="text-lg font-semibold text-gray-900">{rsvpCounts.maybe}</span>
                </div>

                <div className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-gray-400"></span>
                    <span className="text-sm text-gray-600">Can't go</span>
                  </div>
                  <span className="text-lg font-semibold text-gray-900">{rsvpCounts.notGoing}</span>
                </div>

                {rsvpCounts.totalAttendees > 0 && (
                  <div className="pt-3 mt-2 border-t border-gray-200">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-gray-500">Expected attendees</span>
                      <span className="font-semibold text-gray-900">
                        {rsvpCounts.totalAttendees}
                      </span>
                    </div>
                  </div>
                )}
              </div>
            </Card>

            {/* Wish List entry point — sits right above the RSVP call to action */}
            {invitation.wishList && id && (
              <WishListCallout invitationId={id} wishList={invitation.wishList} />
            )}

            {/* RSVP Form */}
            {(!hasRSVPd || isUpdatingRsvp) && !isRSVPClosed ? (
              // Show guest entry choice if not logged in and not in guest mode
              !user && !isGuestMode && !isUpdatingRsvp ? (
                <RSVPGuestEntry
                  invitationId={id || ''}
                  onContinueAsGuest={() => setIsGuestMode(true)}
                />
              ) : (
                <div className="space-y-3">
                  {isUpdatingRsvp && (
                    <Button
                      variant="outline"
                      onClick={() => setIsUpdatingRsvp(false)}
                      className="w-full border-2"
                    >
                      Cancel Update
                    </Button>
                  )}
                  <RSVPForm
                    invitationId={invitation.id}
                    maxAdditionalGuests={invitation.maxAdditionalGuests || 0}
                    onSubmit={handleRSVPSubmit}
                    existingRsvp={existingRsvp}
                    defaultName={user?.name || ''}
                    defaultEmail={user?.email || ''}
                  />
                </div>
              )
            ) : hasRSVPd ? (
              <Card className="p-6 bg-gray-900 text-white text-center">
                <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-white/10 flex items-center justify-center">
                  {rsvpStatus === 'going' ? (
                    <span className="text-green-400 text-2xl font-bold">✓</span>
                  ) : rsvpStatus === 'maybe' ? (
                    <span className="text-amber-400 text-2xl font-bold">?</span>
                  ) : (
                    <span className="text-gray-400 text-2xl font-bold">✗</span>
                  )}
                </div>
                <div className="text-lg font-semibold">Response Received</div>
                <div className="mt-1 text-white/70 text-sm">
                  {rsvpStatus === 'going'
                    ? "We'll see you there"
                    : rsvpStatus === 'maybe'
                      ? 'Hope to see you there'
                      : 'Maybe next time'}
                </div>

                {/* Calendar Links - only show for "going" status */}
                {rsvpStatus === 'going' && calendarLinks && (
                  <div className="mt-5 pt-4 border-t border-white/10">
                    <div className="flex items-center justify-center gap-2 mb-3 text-sm text-white/70">
                      <CalendarPlus className="w-4 h-4" />
                      <span>Add to calendar</span>
                    </div>
                    <div className="flex flex-wrap gap-2 justify-center">
                      <a
                        href={calendarLinks.google}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded-md text-sm transition-colors"
                      >
                        Google
                      </a>
                      <a
                        href={calendarLinks.outlook}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded-md text-sm transition-colors"
                      >
                        Outlook
                      </a>
                      <a
                        href={calendarLinks.yahoo}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded-md text-sm transition-colors"
                      >
                        Yahoo
                      </a>
                      <button
                        onClick={downloadIcsFile}
                        className="px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded-md text-sm transition-colors flex items-center gap-1"
                      >
                        <Download className="w-3 h-3" />
                        .ics
                      </button>
                    </div>
                  </div>
                )}

                {/* Wish list reminder in the post-RSVP confirmation */}
                {invitation.wishList && id && (
                  <WishListCallout
                    invitationId={id}
                    wishList={invitation.wishList}
                    variant="onDark"
                  />
                )}

                {/* Update Response Button */}
                {!isRSVPClosed && (
                  <div className="mt-4 pt-4 border-t border-white/10">
                    <button
                      onClick={() => setIsUpdatingRsvp(true)}
                      className="text-sm text-white/60 hover:text-white/90 transition-colors"
                    >
                      Change response
                    </button>
                  </div>
                )}
              </Card>
            ) : (
              <Card className="p-6 bg-gray-100 text-center">
                <Clock className="w-8 h-8 mx-auto mb-2 text-gray-400" />
                <div className="text-lg font-semibold text-gray-700">RSVP Closed</div>
                <div className="mt-1 text-gray-500 text-sm">The deadline has passed</div>
              </Card>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default InvitationView;
