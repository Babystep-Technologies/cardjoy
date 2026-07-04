# typed: true
# frozen_string_literal: true

module Queries
  class UserInvitations < Queries::BaseQuery
    type [ Types::InvitationType ], null: false
    argument :user_id, ID, required: true

    def resolve(user_id:)
      user = ::User.find(user_id)
      user.invitations.order(created_at: :desc)
    end
  end
end
