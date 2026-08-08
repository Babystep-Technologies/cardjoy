# typed: true

module Types
  # Admin-facing view of an invitation. Every field here reaches the client only
  # through an org-admin-gated mutation; the signed-out join page reads
  # Types::OrganizationInvitationPreviewType instead, which deliberately exposes
  # much less.
  #
  # The token is not a field: it is the credential in the join link, and nothing
  # in the product needs to read it back out of the API.
  class OrganizationInvitationType < Types::BaseObject
    field :id, ID, null: false
    field :email, String, null: false
    field :role, String, null: false
    field :status, String, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false
    field :accepted_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    # Null once the organization is archived — Organization is default-scoped to
    # `deleted_at: nil`, same as OrganizationMembershipType.
    field :organization, Types::OrganizationType, null: true
    field :invited_by, Types::UserType, null: false
  end
end
