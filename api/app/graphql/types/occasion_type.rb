# typed: true

module Types
  class OccasionType < Types::BaseObject
    field :id, ID, null: false
    field :kind, String, null: false
    field :occurs_on, GraphQL::Types::ISO8601Date, null: false
    field :recurring, Boolean, null: false
    field :contact, Types::ContactType, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # The next date this occasion falls on (next anniversary when recurring).
    field :next_occurrence, GraphQL::Types::ISO8601Date, null: false
    def next_occurrence
      object.next_occurrence
    end
  end
end
