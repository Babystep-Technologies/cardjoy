# typed: true
# frozen_string_literal: true

module Mutations
  # Owner-only. Ticks a guest off the thank-you list, or puts them back (#308). Only available once
  # the thank-you list itself is, so surprise mode can't be peeked through it.
  class SetThankYouSent < BaseMutation
    argument :registry_external_id, String, required: true
    argument :reservation_id, ID, required: true
    argument :sent, Boolean, required: false, default_value: true

    field :thanked, Boolean, null: true
    field :errors, [ String ], null: false

    def resolve(registry_external_id:, reservation_id:, sent: true)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      list = user.wish_lists.find_by(external_id: registry_external_id)
      return failure("Registry not found") unless list
      return failure("Who gave what is still hidden until after the event") unless list.thank_you_unlocked?

      reservation = list.thank_you_list.find_by(id: reservation_id)
      return failure("Claim not found") unless reservation

      reservation.update!(thanked_at: sent ? (reservation.thanked_at || Time.current) : nil)
      { thanked: reservation.thanked_at.present?, errors: [] }
    end

    private

    def failure(*messages)
      { thanked: nil, errors: messages }
    end
  end
end
