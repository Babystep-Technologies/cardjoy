# typed: true
# frozen_string_literal: true

module Queries
  # The caller's mail orders for one holiday card (#148), newest first — how the
  # UI answers "did my forty cards go out?" after `sendHolidayCard` has returned
  # with everything `pending`.
  #
  # Always scoped to the caller. `user_id` is denormalized onto the order, so
  # this is a direct scope rather than a join through the card, and there is no
  # argument that could widen it.
  class MyHolidayCardOrders < BaseQuery
    type [ Types::HolidayCardMailOrderType ], null: false

    argument :holiday_card_id, ID, required: true,
      description: "The card's `externalId`."

    def resolve(holiday_card_id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.holiday_card_mail_orders.for_card(card_for(user, holiday_card_id)).newest_first
    end

    private

    # Someone else's card and a card that doesn't exist give the same answer, so
    # a stranger can't use this to learn which `externalId`s are real. Matches
    # Queries::QuoteHolidayCardMailing.
    def card_for(user, holiday_card_id)
      card = ::HolidayCard.find_by(external_id: holiday_card_id)
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless card && card.user_id == user.id

      card
    end
  end
end
