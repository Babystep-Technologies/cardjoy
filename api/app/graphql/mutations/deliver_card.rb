# typed: true
# frozen_string_literal: true

module Mutations
  # Delivers a 1-on-1 card to a recipient by email. Requires an authenticated
  # user who may edit the card — its owner, or an admin of the organization that
  # owns it; sends `CardMailer#one_on_one_delivery` to the given address.
  # Link-only sharing needs no mutation — the viewable URL is the link.
  #
  # An optional future `deliverAt` schedules the send for that time (write now,
  # deliver on the date) by enqueuing `DeliverCardJob`; a blank or past
  # `deliverAt` delivers immediately. Scheduling stores the recipient on the
  # card (`deliver_to_email`) so the dashboard can show, reschedule, or cancel
  # the pending send. Sending immediately clears any prior schedule, so a
  # send-now on a previously scheduled card can't be double-delivered by its
  # stale job.
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
      return { card: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless card.editable_by?(user)

      if deliver_at.present? && deliver_at.future?
        card.update!(deliver_at:, deliver_to_email: recipient_email)
        DeliverCardJob.set(wait_until: deliver_at)
          .perform_later(card.external_id, recipient_email, deliver_at.iso8601)
      else
        card.update!(deliver_at: nil, deliver_to_email: nil) if card.deliver_at.present?
        CardMailer.one_on_one_delivery(recipient_email, card).deliver_later
      end

      { card:, errors: [] }
    end
  end
end
