# typed: true
# frozen_string_literal: true

module Queries
  class CheckRsvp < Queries::BaseQuery
    description "Check if an email has already RSVPd to an invitation"

    argument :invitation_id, ID, required: true, description: "The invitation ID or external ID"
    argument :email, String, required: true, description: "The guest email to check"

    type Types::RsvpType, null: true

    def resolve(invitation_id:, email:)
      invitation = ::Invitation.find_by(id: invitation_id) || ::Invitation.find_by(external_id: invitation_id)
      return nil unless invitation

      invitation.rsvps.find_by(guest_email: email.downcase.strip)
    end
  end
end
