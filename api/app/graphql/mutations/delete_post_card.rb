# typed: true
# frozen_string_literal: true

module Mutations
  # Soft-deletes a post card, matching `Card`: the row stays for support and
  # for any print job that already referenced it, and `PostCard`'s default
  # scope takes it out of `myPostCards`.
  #
  # Only a card that has never been mailed may be deleted (#205). A card with
  # orders against it is the thing `PostCardMailOrder#recipient_snapshot` and
  # the postage ledger both point back at — it is a record of money spent and
  # paper in the postal system, and the orders view is built on being able to
  # read it. The rule lives here rather than only in the dashboard because the
  # mutation is reachable without it.
  class DeletePostCard < BaseMutation
    MAILED_ERROR = "This card has already been mailed, so it can't be deleted"

    argument :external_id, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      post_card = PostCard.find_by(external_id:)
      return failure("Post card not found") unless post_card
      return failure(NOT_AUTHORIZED_ERROR) unless post_card.user_id == user.id
      return failure(MAILED_ERROR) if post_card.mail_orders.exists?

      post_card.delete!
      { success: true, errors: [] }
    end

    private

    def failure(errors)
      { success: false, errors: Array(errors) }
    end
  end
end
