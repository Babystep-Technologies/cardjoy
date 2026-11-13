import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { useParams, useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Gift, ArrowLeft } from 'lucide-react';
import LoadingScreen from '@/components/Loading';
import { GuestWishList } from '@/components/Registry/GuestWishList';
import { useClaimFromLink } from '@/components/Registry/useClaimFromLink';
import { WISH_LIST_FIELDS } from '@/lib/wishList';

// Named to match GraphqlController::PUBLIC_OPERATIONS so guests can load it signed out.
const GET_INVITATION_WISH_LIST = gql`
  query GetInvitationWishList($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      externalId
      title
      eventDate
      wishList {
        ${WISH_LIST_FIELDS}
      }
    }
  }
`;

const InvitationWishList: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { ready: claimReady } = useClaimFromLink();

  const { loading, data } = useQuery(GET_INVITATION_WISH_LIST, {
    variables: { externalId: id },
    skip: !id,
  });

  const invitation = data?.invitation;
  const wishList = invitation?.wishList;

  if (loading || !claimReady) return <LoadingScreen />;

  if (!wishList) {
    return (
      <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
        <div className="w-full mx-auto px-4 py-8 max-w-2xl mt-16 text-center space-y-4">
          <Gift className="w-12 h-12 mx-auto text-gray-400" />
          <h1 className="text-2xl font-bold">No wish list yet</h1>
          <p className="text-gray-600">This invitation doesn't have a wish list to show.</p>
          {id && (
            <Button
              variant="outline"
              className="border-2"
              onClick={() => navigate(`/invitation/${id}`)}
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to invitation
            </Button>
          )}
        </div>
      </div>
    );
  }

  return (
    <GuestWishList
      wishList={wishList}
      subtitle={invitation?.title ? `for ${invitation.title}` : null}
      shareTitle={`${wishList.title ?? 'Wish List'} — ${invitation?.title ?? ''}`.trim()}
      backLink={{ to: `/invitation/${id}`, label: 'Back to invitation' }}
    />
  );
};

export default InvitationWishList;
