# typed: true
# frozen_string_literal: true

module Mutations
  # Renders the card through PostGrid and stores the returned PDF as the proof
  # the user approves before we print (issue #144).
  #
  # **Inline, not a job.** The user is sitting there waiting for this, and it is
  # a single bounded call — `PostGrid::Client` caps itself at 3 × (5s + 15s).
  # An async flow would buy nothing but a poll loop in the editor. If it turns
  # out to be slow in practice, move it to `good_job` then.
  #
  # Every failure lands in `errors` as a sentence rather than as a 500, and
  # leaves the previous proof untouched: a PostGrid outage should cost the user
  # a retry, not the good render they already had.
  class GenerateHolidayCardProof < BaseMutation
    # PostGrid is optional app-wide (CLAUDE.md), so an unconfigured deploy
    # degrades to this rather than raising ConfigurationError out of the client.
    UNAVAILABLE_ERROR = "Proofs are unavailable right now. Please try again later."

    # `PostGrid::ServiceError` and `RateLimitError` have already been retried by
    # the client by the time they reach here, so their messages are PostGrid's
    # internal ones — not something to show a user.
    RETRY_ERROR = "We couldn't reach our print partner. Please try again in a moment."

    argument :external_id, String, required: true

    field :holiday_card, Types::HolidayCardType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      holiday_card = ::HolidayCard.find_by(external_id:)
      return failure("Holiday card not found") unless holiday_card
      return failure(NOT_AUTHORIZED_ERROR) unless holiday_card.user_id == user.id
      return failure(UNAVAILABLE_ERROR) unless PostGrid.configured?(mode: ::HolidayCard::ProofGenerator::MODE)

      generate(holiday_card)
    end

    private

    def generate(holiday_card)
      { holiday_card: ::HolidayCard::ProofGenerator.new(holiday_card).generate!, errors: [] }
    rescue ::HolidayCard::PrintRenderer::UnknownTemplateError
      # The card names a template that has since been retired. Nothing the user
      # can do from the editor, so say what it means rather than echoing an id.
      failure("This card's template is no longer available. Please pick another template.")
    rescue PostGrid::InvalidRequestError => e
      # PostGrid rejected the card itself — an unsupported size, a document it
      # would not render. Its message is the only description of what is wrong,
      # and it is written for a human, so it is worth passing through.
      failure("We couldn't render a proof of this card: #{e.message}")
    rescue PostGrid::AuthenticationError, PostGrid::ConfigurationError
      # Our key, our problem. Never leak which.
      failure(UNAVAILABLE_ERROR)
    rescue PostGrid::Error
      failure(RETRY_ERROR)
    end

    def failure(errors)
      { holiday_card: nil, errors: Array(errors) }
    end
  end
end
