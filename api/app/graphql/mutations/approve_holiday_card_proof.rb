# typed: true
# frozen_string_literal: true

module Mutations
  # Records that the user looked at the PostGrid-rendered proof and accepted it
  # (issue #144). `proof_approved_at` is the signal the send flow (#148) gates
  # on before spending anyone's money.
  #
  # The whole mutation is one guard: **you may only approve a proof that is
  # still current.** Approving a stale one — the design moved after the render,
  # or the PDF link has aged past `HolidayCard::PROOF_MAX_AGE` — is exactly the
  # bug this mechanism exists to prevent, because the thing the user says yes to
  # would not be the thing that prints.
  class ApproveHolidayCardProof < BaseMutation
    NO_PROOF_ERROR = "This card has no proof yet. Generate one before approving it."
    STALE_PROOF_ERROR = "This card has changed since its proof was made. Generate a new proof and review it."

    argument :external_id, String, required: true

    field :holiday_card, Types::HolidayCardType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      holiday_card = ::HolidayCard.find_by(external_id:)
      return failure("Holiday card not found") unless holiday_card
      return failure(NOT_AUTHORIZED_ERROR) unless holiday_card.user_id == user.id

      # Told apart because they need different things from the user: one has
      # never generated a proof, the other is looking at one that no longer
      # matches.
      return failure(NO_PROOF_ERROR) if holiday_card.proof_url.blank?
      return failure(STALE_PROOF_ERROR) unless holiday_card.proof_current?

      holiday_card.update!(proof_approved_at: Time.current)

      { holiday_card:, errors: [] }
    end

    private

    def failure(errors)
      { holiday_card: nil, errors: Array(errors) }
    end
  end
end
