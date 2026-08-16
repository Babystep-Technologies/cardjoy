# typed: true
# frozen_string_literal: true

module Mutations
  # Saves the editor's working copy of a holiday card.
  #
  # `designConfig` **replaces** the stored document; it is not deep-merged. The
  # editor holds the whole document in memory and sends it back on every save, and
  # a merge would make deletion impossible to express — there is no way to say
  # "this sticker is gone" in a patch that only ever adds keys. HolidayCard's
  # validator is the gate on what may be stored.
  class UpdateHolidayCard < BaseMutation
    argument :external_id, String, required: true
    argument :title, String, required: false
    argument :design_config, GraphQL::Types::JSON, required: false

    field :holiday_card, Types::HolidayCardType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:, title: nil, design_config: nil)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      holiday_card = HolidayCard.find_by(external_id:)
      return failure("Holiday card not found") unless holiday_card
      return failure(NOT_AUTHORIZED_ERROR) unless holiday_card.user_id == user.id

      holiday_card.title = title unless title.nil?
      holiday_card.design_config = design_config unless design_config.nil?

      # `save` rather than `save!`: a malformed design document is a client
      # mistake, so it belongs in `errors` as a 422-shaped payload, not in a 500.
      return failure(holiday_card.errors.full_messages) unless holiday_card.save

      { holiday_card:, errors: [] }
    end

    private

    def failure(errors)
      { holiday_card: nil, errors: Array(errors) }
    end
  end
end
