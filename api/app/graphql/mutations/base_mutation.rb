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

    NOT_AUTHENTICATED_ERROR = "Not authenticated"
    NOT_AUTHORIZED_ERROR = "Not authorized"

    private

    # Organization authorization helpers, shared by every org-scoped mutation.
    #
    # These are predicates rather than `require_*!` bang methods on purpose: a
    # user-facing failure here belongs in the mutation's `errors` array, so the
    # caller has to early-return its own payload shape. Raising is reserved for
    # the internal admin gate (see Mutations::UpdateCardByAdmin).
    #
    #   return { organization: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_admin?(organization)

    def current_membership(organization)
      organization&.membership_for(context[:current_user])
    end

    def org_member?(organization)
      current_membership(organization).present?
    end

    def org_admin?(organization)
      current_membership(organization)&.admin? || false
    end

    # The organization a creation mutation should write into, resolved from its
    # optional `organizationId` argument. Per the epic's cross-cutting rule the
    # client passes the context explicitly and the server validates it; we never
    # read `active_organization_id` here.
    #
    # Returns nil for a blank id — Personal is a valid context, not a missing
    # one — and `false` when the caller may not write there, so one call tells
    # the two apart:
    #
    #   organization = writable_organization(organization_id)
    #   return failure(NOT_AUTHORIZED_ERROR) if organization == false
    #
    # An unknown id is denied rather than reported as not-found, so a stranger
    # can't probe which organization ids exist. Callers must run this *before*
    # spending a credit, so a rejected create never bills anyone.
    def writable_organization(organization_id)
      return nil if organization_id.blank?

      organization = Organization.find_by(id: organization_id)
      return false unless organization && org_member?(organization)

      organization
    end
  end
end
