# typed: true
# frozen_string_literal: true

module Mutations
  # Moderation for one post card (#178).
  #
  # Deliberately identical to Mutations::UpdateCardByAdmin apart from the two
  # actions a post card has no use for: it takes no contributions, so there is
  # nothing to lock. Same argument names, same error strings, same payload shape,
  # so the admin dashboard drives all three products through one component.
  class UpdatePostCardByAdmin < Mutations::BaseMutation
    argument :external_id, String, required: true
    argument :action, String, required: true

    field :post_card, Types::PostCardType, null: true
    field :errors, [ String ], null: false

    VALID_ACTIONS = %w[
      flag unflag
      archive unarchive
    ].freeze

    def resolve(external_id:, action:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Unscoped so `unarchive` can reach a card the archive already hid;
      # PostCard is default-scoped to `deleted_at: nil`.
      card = PostCard.unscope(where: :deleted_at).find_by(external_id: external_id)
      return { post_card: nil, errors: [ "Post card not found" ] } unless card
      return { post_card: nil, errors: [ "Invalid action" ] } unless VALID_ACTIONS.include?(action)

      begin
        case action
        when "flag"      then card.flag!
        when "unflag"    then card.unflag!
        when "archive"   then card.delete!
        when "unarchive" then card.restore!
        end
      rescue => e
        return { post_card: nil, errors: [ e.message ] }
      end

      { post_card: card.reload, errors: [] }
    end
  end
end
