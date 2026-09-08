# typed: true
# frozen_string_literal: true

module Queries
  # Can we proof and mail at all? Asked on entry to the send flow so an
  # unconfigured deploy shows an explanation instead of letting someone pick
  # recipients, approve a proof, and only then be told no (#153).
  #
  # Deliberately says nothing about *why* — not which env var is missing, not
  # which mode resolved. That is deployment detail, and this answer is served to
  # anyone signed in.
  class HolidayCardMailingAvailability < BaseQuery
    type Types::HolidayCardMailingAvailabilityType, null: false

    def resolve
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless context[:current_user]

      {
        proofs_available: PostGrid.configured?(mode: ::HolidayCard::ProofGenerator::MODE),
        mailing_available: PostGrid.configured?(mode: ::HolidayCard::MailSubmission::MODE)
      }
    end
  end
end
