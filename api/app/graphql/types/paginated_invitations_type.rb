# typed: true
# frozen_string_literal: true

module Types
  class PaginatedInvitationsType < Types::BaseObject
    field :invitations, [ Types::InvitationType ], null: false
    field :total_count, Integer, null: false
    field :current_page, Integer, null: false
    field :per_page, Integer, null: false
  end
end
