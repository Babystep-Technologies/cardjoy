# typed: true
# frozen_string_literal: true

module Mutations
  # Cancels a pending scheduled 1-on-1 delivery by clearing the card's
  # `deliver_at` and `deliver_to_email`. The already-enqueued `DeliverCardJob`
  # then no-ops when it runs (it guards on a blank `deliver_at`), so nothing is
  # sent. Requires an authenticated owner. A card with nothing scheduled is a
  # no-op success.
  class CancelScheduledDelivery < BaseMutation
    argument :card_id, ID, required: true

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    def resolve(card_id:)
      user = context[:current_user]
      return { card: nil, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id)
      return { card: nil, errors: [ "Card not found" ] } unless card
      return { card: nil, errors: [ "Not authorized" ] } unless card.user_id == user.id

      card.update!(deliver_at: nil, deliver_to_email: nil) if card.deliver_at.present?

      { card:, errors: [] }
    end
  end
end
