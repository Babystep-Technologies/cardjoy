# typed: true
# frozen_string_literal: true

module Types
  class RsvpType < Types::BaseObject
    field :id, ID, null: false
    field :invitation_id, ID, null: false
    field :user_id, ID, null: true
    field :guest_name, String, null: true
    field :guest_email, String, null: true
    field :status, String, null: false
    field :plus_one, Boolean, null: false
    field :additional_guests_count, Integer, null: false
    field :plus_one_name, String, null: true
    field :message, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :user, Types::UserType, null: true
    field :invitation, Types::InvitationType, null: false
  end
end
