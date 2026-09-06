# typed: true
# frozen_string_literal: true

module Queries
  # The signed-in user's postage wallet history, newest first (#145) — the top
  # of the ledger is the top-up or the piece of mail they just sent, which is
  # what they're checking on.
  #
  # Always scoped to the caller, with no id argument: a postage row is personal,
  # so there is nothing to widen the scope to.
  class MyPostageLedger < BaseQuery
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 200

    type [ Types::PostageCreditType ], null: false

    argument :limit, Integer, required: false,
      description: "How many of the most recent rows to return (default #{DEFAULT_LIMIT}, max #{MAX_LIMIT})."

    # `limit` arrives nil when the client passes an explicit null, which is not
    # the same as omitting the argument — both mean "the default".
    def resolve(limit: nil)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.postage_credits
        .order(created_at: :desc, id: :desc)
        .limit((limit || DEFAULT_LIMIT).clamp(1, MAX_LIMIT))
    end
  end
end
