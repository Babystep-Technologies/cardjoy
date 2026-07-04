# typed: true
# frozen_string_literal: true

module Queries
  class Invitation < Queries::BaseQuery
    type Types::InvitationType, null: false
    argument :external_id, String, required: true

    def resolve(external_id:)
      ::Invitation.find_by!(external_id: external_id)
    end
  end
end
