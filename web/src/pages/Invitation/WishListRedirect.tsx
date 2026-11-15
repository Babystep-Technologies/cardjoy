/**
 * Old `/invitation/:id/wishlist` links (shared before the wish list became a registry, including the
 * "manage your claim" link in claim emails) land here and move on to the invitation's registry,
 * keeping the `?claim=` token. With no registry linked they fall back to the invitation itself.
 */
import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { Navigate, useLocation, useParams } from 'react-router-dom';
import Loading from '@/components/Loading';

const GET_INVITATION_REGISTRY = gql`
  query GetInvitation($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      registry {
        externalId
      }
    }
  }
`;

const InvitationWishListRedirect: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { search } = useLocation();
  const { data, loading, error } = useQuery(GET_INVITATION_REGISTRY, {
    variables: { externalId: id },
    skip: !id,
  });

  if (loading) return <Loading />;

  const registryId: string | undefined = data?.invitation?.registry?.externalId;
  if (error || !registryId) return <Navigate to={`/invitation/${id}`} replace />;
  return <Navigate to={`/registry/${registryId}${search}`} replace />;
};

export default InvitationWishListRedirect;
