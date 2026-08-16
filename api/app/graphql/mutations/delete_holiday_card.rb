# typed: true
# frozen_string_literal: true

module Mutations
  # Soft-deletes a holiday card, matching `Card`: the row stays for support and
  # for any print job that already referenced it, and `HolidayCard`'s default
  # scope takes it out of `myHolidayCards`.
  class DeleteHolidayCard < BaseMutation
    argument :external_id, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      holiday_card = HolidayCard.find_by(external_id:)
      return failure("Holiday card not found") unless holiday_card
      return failure(NOT_AUTHORIZED_ERROR) unless holiday_card.user_id == user.id

      holiday_card.delete!
      { success: true, errors: [] }
    end

    private

    def failure(errors)
      { success: false, errors: Array(errors) }
    end
  end
end
