# typed: true
# frozen_string_literal: true

module Mutations
  # Delivers a 1-on-1 card to a recipient by email. Requires an authenticated
  # user who owns the card; sends `CardMailer#one_on_one_delivery` to the given
  # address. Link-only sharing needs no mutation — the viewable URL is the link.
  class DeliverCard < BaseMutation
    argument :card_id, ID, required: true
    argument :recipient_email, String, required: true

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    def resolve(card_id:, recipient_email:)
      user = context[:current_user]
      return { card: nil, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id)
      return { card: nil, errors: [ "Card not found" ] } unless card
      return { card: nil, errors: [ "Not authorized" ] } unless card.user_id == user.id

      CardMailer.one_on_one_delivery(recipient_email, card).deliver_later

      { card:, errors: [] }
    end
  end
end
