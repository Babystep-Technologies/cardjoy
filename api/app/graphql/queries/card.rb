# typed: true

module Queries
  # Fetch a single card by its unguessable `external_id`.
  #
  # This is the public reveal query — "Card" is in
  # GraphqlController::PUBLIC_OPERATIONS, so it must keep working signed out,
  # including for a card an organization owns. Access on that path is governed
  # by the unguessable id and Card#require_login_to_contribute, not by
  # membership, and organization ownership does not change it.
  #
  # Passing `organizationId` opts into a context-aware read instead: the card
  # must belong to that organization and the caller must be a member of it.
  # That is what the signed-in dashboard sends, and what makes a non-member's
  # org-scoped read fail rather than silently succeed.
  class Card < BaseQuery
    type Types::CardType, null: true
    argument :card_id, ID, required: true
    argument :show_flagged_messages, Boolean, required: false, default_value: false
    argument :organization_id, ID, required: false

    def resolve(card_id:, show_flagged_messages:, organization_id: nil)
      context[:show_flagged_messages] = show_flagged_messages

      card = ::Card.find_by(external_id: card_id)
      return card if organization_id.blank?
      return nil unless card

      organization = readable_organization(organization_id)
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR if organization == false
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless card.organization_id == organization&.id

      card
    end
  end
end
