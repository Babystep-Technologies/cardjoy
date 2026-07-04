# typed: true

# app/graphql/mutations/update_card_by_admin.rb
module Mutations
  class UpdateCardByAdmin < Mutations::BaseMutation
    argument :external_id, String, required: true
    argument :action, String, required: true

    field :card, Types::CardType, null: true
    field :errors, [ String ], null: false

    VALID_ACTIONS = %w[
      lock unlock
      flag unflag
      archive unarchive
    ].freeze

    def resolve(external_id:, action:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      card = Card.find_by(external_id: external_id)
      return { card: nil, errors: [ "Card not found" ] } unless card
      return { card: nil, errors: [ "Invalid action" ] } unless VALID_ACTIONS.include?(action)

      begin
        case action
        when "lock"      then card.lock!
        when "unlock"    then card.unlock!
        when "flag"      then card.flag!
        when "unflag"    then card.unflag!
        when "archive"   then card.delete!
        when "unarchive" then card.restore!
        end
      rescue => e
        return { card: nil, errors: [ e.message ] }
      end

      { card: card.reload, errors: [] }
    end
  end
end
