# typed: true

module Queries
  class Card < BaseQuery
    type Types::CardType, null: true
    argument :card_id, ID, required: true
    argument :show_flagged_messages, Boolean, required: false, default_value: false

    def resolve(card_id:, show_flagged_messages:)
      context[:show_flagged_messages] = show_flagged_messages
      ::Card.find_by(external_id: card_id)
    end
  end
end
