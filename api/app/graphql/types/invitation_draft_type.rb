# typed: true
# frozen_string_literal: true

module Types
  class InvitationDraftType < Types::BaseObject
    field :id, ID, null: false
    field :external_id, String, null: false
    field :preview_title, String, null: true
    field :preview_message, String, null: true
    field :preview_event_date, GraphQL::Types::ISO8601Date, null: true
    field :preview_event_time, String, null: true
    field :preview_location, String, null: true
    field :ai_payload, GraphQL::Types::JSON, null: true
    field :status, String, null: false
    field :approved_at, GraphQL::Types::ISO8601DateTime, null: true
    field :rejected_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: true
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :user, Types::UserType, null: true
  end
end
