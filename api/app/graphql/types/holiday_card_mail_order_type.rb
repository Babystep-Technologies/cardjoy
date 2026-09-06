# typed: true

module Types
  # One physical piece of mail (#148): who it went to, what it cost, and where
  # it has got to.
  #
  # **`baseCents` and `rateCardVersion` are deliberately absent**, the same way
  # they are from the mailing quote. The user is charged one number per card;
  # what it is made of is our cost and our margin, and a type that exposed the
  # split would publish the margin on every order anyone ever placed.
  #
  # The recipient is served from `recipient_snapshot`, not from the contact.
  # A contact can be edited or deleted after the card is in the post, and the
  # order has to keep saying where it actually went.
  class HolidayCardMailOrderType < Types::BaseObject
    description "A single holiday card mailed to a single address."

    field :id, ID, null: false

    field :status, String, null: false,
      description: <<~DESC.strip
        Ours, not our print partner's: "pending", "submitted", "printing",
        "processed_for_delivery", "completed", "failed", or "cancelled".
      DESC

    field :charged_cents, Integer, null: false,
      description: "What this piece cost the user, in US cents. Refunded in full if it ends up `failed`."

    field :recipient_name, String, null: true,
      description: "The recipient's name as it was printed."
    field :recipient_address, Types::HolidayCardMailRecipientType, null: false,
      description: "The address as it was at send time. Unaffected by later edits to the contact."

    # Nullable, and stays null for a deleted contact — which is exactly why the
    # snapshot above exists. Present so a client can link an order back to the
    # person while they still exist.
    field :contact_id, ID, null: true

    field :tracking_number, String, null: true,
      description: "Set once the carrier has one. Null before then."
    field :failure_reason, String, null: true,
      description: "Why this piece was not sent. Null unless `status` is \"failed\"."

    field :submitted_at, GraphQL::Types::ISO8601DateTime, null: true
    field :mailed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def recipient_address
      object.recipient_snapshot || {}
    end
  end
end
