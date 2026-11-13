/**
 * `/registry/:externalId` — the page a guest opens from a shared link (#247). No account needed
 * to browse, claim, or follow a cash link. A hidden registry reads as missing to everyone but its
 * owner, so an unpublished one shows the same "not found" a bad link does.
 */
import React, { useEffect } from 'react';
import { gql, useQuery } from '@apollo/client';
import { Link, useParams } from 'react-router-dom';
import { Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import LoadingScreen from '@/components/Loading';
import { GuestWishList } from '@/components/Registry/GuestWishList';
import { useClaimFromLink } from '@/components/Registry/useClaimFromLink';
import { occasionLabel, WISH_LIST_FIELDS } from '@/lib/wishList';
import { format, parseISO } from 'date-fns';

// Named to match GraphqlController::PUBLIC_OPERATIONS so guests can load it signed out.
const GET_REGISTRY = gql`
  query GetRegistry($externalId: String!) {
    registry(externalId: $externalId) {
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

const RegistryView: React.FC = () => {
  const { externalId } = useParams<{ externalId: string }>();
  useNoIndex();
  const { ready: claimReady } = useClaimFromLink();

  const { data, loading } = useQuery(GET_REGISTRY, {
    variables: { externalId },
    skip: !externalId,
  });

  if (loading || !claimReady) return <LoadingScreen />;

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
    ]
      .filter(Boolean)
      .join(' · ') || null;

  return (
    <GuestWishList
      wishList={registry}
      subtitle={subtitle}
      shareTitle={`${registry.title}${registry.ownerFirstName ? ` — ${registry.ownerFirstName}` : ''}`}
    />
  );
};

export default RegistryView;
