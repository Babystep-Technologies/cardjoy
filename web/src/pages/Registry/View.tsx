/**
 * `/registry/:externalId` — the page a guest opens from a shared link (#247). No account needed
 * to browse, claim, or follow a cash link. A hidden registry reads as missing to everyone but its
 * owner, so an unpublished one shows the same "not found" a bad link does.
 */
import React, { useEffect, useState } from 'react';
import { gql, useQuery } from '@apollo/client';
import { Link, useParams } from 'react-router-dom';
import { Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import LoadingScreen from '@/components/Loading';
import { GuestWishList } from '@/components/Registry/GuestWishList';
import { useClaimFromLink } from '@/components/Registry/useClaimFromLink';
import { eventCountdown, occasionLabel, WISH_LIST_FIELDS } from '@/lib/wishList';
import { format, parseISO } from 'date-fns';

// Named to match GraphqlController::PUBLIC_OPERATIONS so guests can load it signed out.
const GET_REGISTRY = gql`
  query GetRegistry($externalId: String!, $passcode: String) {
    registry(externalId: $externalId, passcode: $passcode) {
      ownerFirstName
      ${WISH_LIST_FIELDS}
    }
  }
`;

/** Registries are shared by link, not found by search, so keep crawlers off by default. */
const useNoIndex = () => {
  useEffect(() => {
    const meta = document.createElement('meta');
    meta.name = 'robots';
    meta.content = 'noindex';
    document.head.appendChild(meta);
    return () => {
      document.head.removeChild(meta);
    };
  }, []);
};

const passcodeKey = (externalId?: string) => `registry-passcode:${externalId}`;
const rememberedPasscode = (externalId?: string) => {
  try {
    return sessionStorage.getItem(passcodeKey(externalId)) ?? '';
  } catch {
    return '';
  }
};

const RegistryView: React.FC = () => {
  const { externalId } = useParams<{ externalId: string }>();
  useNoIndex();
  const { ready: claimReady } = useClaimFromLink();

  const [passcode, setPasscode] = useState(() => rememberedPasscode(externalId));
  const [typed, setTyped] = useState('');

  const { data, loading, error } = useQuery(GET_REGISTRY, {
    variables: { externalId, passcode: passcode || undefined },
    skip: !externalId,
  });

  useEffect(() => {
    if (data?.registry && passcode) {
      try {
        sessionStorage.setItem(passcodeKey(externalId), passcode);
      } catch {
        // Private mode: the guest just types it again next visit.
      }
    }
  }, [data, passcode, externalId]);

  if (loading || !claimReady) return <LoadingScreen />;

  const lockCode = error?.graphQLErrors?.[0]?.extensions?.code;
  if (lockCode === 'PASSCODE_REQUIRED' || lockCode === 'PASSCODE_INVALID') {
    return (
      <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
        <form
          className="w-full mx-auto px-4 py-8 max-w-sm mt-16 text-center space-y-4"
          onSubmit={e => {
            e.preventDefault();
            setPasscode(typed.trim());
          }}
        >
          <Gift className="w-12 h-12 mx-auto text-gray-400" />
          <h1 className="text-2xl font-bold">This registry has a passcode</h1>
          <p className="text-gray-600">Ask the person who shared it for the passcode.</p>
          <Input
            type="password"
            value={typed}
            onChange={e => setTyped(e.target.value)}
            aria-label="Passcode"
            autoComplete="off"
          />
          {lockCode === 'PASSCODE_INVALID' && (
            <p role="alert" className="text-sm text-red-600">
              That passcode isn&apos;t right.
            </p>
          )}
          <Button type="submit" disabled={!typed.trim()} className="w-full font-bold">
            Open registry
          </Button>
        </form>
      </div>
    );
  }

  const registry = data?.registry;
  if (!registry) {
    return (
      <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
        <div className="w-full mx-auto px-4 py-8 max-w-2xl mt-16 text-center space-y-4">
          <Gift className="w-12 h-12 mx-auto text-gray-400" />
          <h1 className="text-2xl font-bold">We couldn&apos;t find that registry</h1>
          <p className="text-gray-600">
            The link may be mistyped, or the owner hasn&apos;t published it yet.
          </p>
          <Button asChild variant="outline" className="border-2">
            <Link to="/">Go to CardJoy</Link>
          </Button>
        </div>
      </div>
    );
  }

  const occasion = occasionLabel(registry.occasion);
  const subtitle =
    [
      registry.ownerFirstName
        ? `${registry.ownerFirstName}'s ${occasion?.toLowerCase() ?? 'registry'}`
        : occasion,
      registry.eventDate ? format(parseISO(registry.eventDate), 'MMMM d, yyyy') : null,
      eventCountdown(registry.eventDate),
    ]
      .filter(Boolean)
      .join(' · ') || null;

  return (
    <GuestWishList
      wishList={registry}
      passcode={passcode || undefined}
      subtitle={subtitle}
      shareTitle={`${registry.title}${registry.ownerFirstName ? ` — ${registry.ownerFirstName}` : ''}`}
    />
  );
};

export default RegistryView;
