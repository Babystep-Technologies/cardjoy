# typed: true
# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    # Surfaced in a mutation's `errors` array when the user lacks the credits to
    # create a card or invitation. The web app matches on this exact string to
    # route the user to /buy_credits, so keep it in sync with
    # web/src/lib/credits.ts.
    INSUFFICIENT_CREDITS_ERROR = "Not enough credits"
  end
end
