# typed: true
# frozen_string_literal: true

module Mutations
  # Delivers a 1-on-1 card to a recipient by email. Requires an authenticated
  # user who owns the card; sends `CardMailer#one_on_one_delivery` to the given
  # address. Link-only sharing needs no mutation — the viewable URL is the link.
  #
  # An optional future `deliverAt` schedules the send for that time (write now,
  # deliver on the date) by enqueuing `DeliverCardJob`; a blank or past
  # `deliverAt` delivers immediately.
  class DeliverCard < BaseMutation
    argument :card_id, ID, required: true
    argument :recipient_email, String, required: true
    argument :deliver_at, GraphQL::Types::ISO8601DateTime, required: false

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    def resolve(card_id:, recipient_email:, deliver_at: nil)
      user = context[:current_user]
      return { card: nil, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id)
      return { card: nil, errors: [ "Card not found" ] } unless card
      return { card: nil, errors: [ "Not authorized" ] } unless card.user_id == user.id

      if deliver_at.present? && deliver_at.future?
        card.update!(deliver_at:)
        DeliverCardJob.set(wait_until: deliver_at)
          .perform_later(card.external_id, recipient_email, deliver_at.iso8601)
      else
        CardMailer.one_on_one_delivery(recipient_email, card).deliver_later
      end

      { card:, errors: [] }
    end
  end
end
