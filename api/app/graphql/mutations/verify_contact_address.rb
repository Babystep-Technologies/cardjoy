# typed: true

module Mutations
  # Verify a contact's mailing address against PostGrid, on demand.
  #
  # Persists the verdict (so we don't re-verify on every price quote) and hands
  # back PostGrid's canonicalized form as a *suggestion*. It deliberately does
  # not apply that suggestion — see Types::AddressSuggestionType.
  class VerifyContactAddress < BaseMutation
    UNAVAILABLE_ERROR = "Address verification is unavailable"
    INCOMPLETE_ADDRESS_ERROR = "Contact does not have a complete mailing address"

    argument :contact_id, ID, required: true

    field :contact, Types::ContactType, null: true
    field :suggestion, Types::AddressSuggestionType, null: true
    field :errors, [ String ], null: false

    def resolve(contact_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      contact = Contact.find_by(id: contact_id)
      # Not-found and not-yours are the same answer on purpose: a distinct
      # "no such contact" would let a stranger probe which ids exist.
      return failure(NOT_AUTHORIZED_ERROR) unless contact && contact.user_id == user.id
      return failure(INCOMPLETE_ADDRESS_ERROR) unless contact.mailable?

      # Degrade rather than crash when PostGrid isn't set up — the normal state
      # of a fresh clone and of CI, per CLAUDE.md's gating convention.
      return failure(UNAVAILABLE_ERROR) unless PostGrid.configured?

      verify(contact)
    end

    private

    def verify(contact)
      result = PostGrid::AddressVerification.new.verify_contact(contact)
      contact.apply_address_verification!(result)

      { contact:, suggestion: suggestion_for(contact, result), errors: [] }
    rescue PostGrid::InvalidRequestError, PostGrid::AuthenticationError, PostGrid::ServiceError,
           PostGrid::RateLimitError, PostGrid::ConfigurationError => e
      # PostGrid's message can quote the address back at us, so it does not go
      # to the user or the log. The class is the only thing a caller can act on.
      Rails.logger.warn("[PostGrid] address verification failed contact=#{contact.id} error=#{e.class}")
      failure(UNAVAILABLE_ERROR)
    end

    # Only offer a suggestion when PostGrid actually resolved an address.
    # An undeliverable result has nothing useful to canonicalize, and offering
    # the user a half-empty "did you mean" is worse than offering nothing.
    def suggestion_for(contact, result)
      return nil unless result.deliverable?

      result.canonical_address.merge(differs_from_contact: result.differs_from?(contact))
    end

    def failure(message)
      { contact: nil, suggestion: nil, errors: [ message ] }
    end
  end
end
