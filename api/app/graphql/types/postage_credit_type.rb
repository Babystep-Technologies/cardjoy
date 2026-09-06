# typed: true

module Types
  # One line of a user's postage wallet (#145), for the postage history UI:
  # when, why, and how much.
  #
  # Only ever reached through Queries::MyPostageLedger, which scopes to the
  # caller — a postage row is personal, so there is no path to anyone else's.
  class PostageCreditType < Types::BaseObject
    field :id, ID, null: false

    # Signed and in **integer US cents**, never a float or a formatted string:
    # positive rows put postage in, negative rows are pieces of mail. Money in
    # cents survives the wire exactly; formatting is the client's job.
    field :amount_cents, Integer, null: false,
      description: "Signed amount in US cents. Positive is a top-up or refund, negative is a piece of mail."
    field :reason, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # The kind of the first audit-trail entry, so the history can label a row
    # ("Top-up", "Postcard to Ada") without the client parsing the jsonb.
    # Null for a row written without events.
    field :event_kind, String, null: true

    def event_kind
      object.events&.first&.dig("event_kind")
    end
  end
end
