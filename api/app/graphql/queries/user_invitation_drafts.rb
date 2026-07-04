# typed: false
# frozen_string_literal: true

module Queries
  class UserInvitationDrafts < Queries::BaseQuery
    type [ Types::InvitationDraftType ], null: false
    argument :user_id, ID, required: true

    def resolve(user_id:)
      user = ::User.find(user_id)
      user.invitation_drafts.order(created_at: :desc)
    end
  end
end
