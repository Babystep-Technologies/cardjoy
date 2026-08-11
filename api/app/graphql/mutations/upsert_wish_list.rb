# typed: false
# frozen_string_literal: true

module Mutations
  # Creates or replaces the wish list attached to an invitation. The host edits the whole list in
  # one form, so items and contributions are sent in full and replace what was there.
  class UpsertWishList < BaseMutation
    argument :invitation_external_id, String, required: true
    argument :title, String, required: false
    argument :intro, String, required: false
    argument :visible, Boolean, required: false
    argument :surprise_mode, Boolean, required: false
    argument :items, [ Types::WishListItemInputType ], required: false
    argument :contributions, [ Types::WishListContributionInputType ], required: false

    field :wish_list, Types::WishListType, null: true
    field :errors, [ String ], null: false

    def resolve(invitation_external_id:, items: nil, contributions: nil, **attributes)
      user = context[:current_user]
      return failure("You must be signed in") unless user

      invitation = Invitation.find_by(external_id: invitation_external_id)
      return failure("Invitation not found") unless invitation&.editable_by?(user)

      wish_list = invitation.wish_list || invitation.build_wish_list
      wish_list.assign_attributes(attributes.compact)

      invalid_kinds = Array(contributions).map { |c| c[:kind] } - WishListContribution::KINDS
      if invalid_kinds.any?
        return failure("Unsupported contribution type: #{invalid_kinds.uniq.join(', ')}")
      end

      WishList.transaction do
        wish_list.save!
        replace_items(wish_list, items) unless items.nil?
        replace_contributions(wish_list, contributions) unless contributions.nil?
      end

      { wish_list: wish_list.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(*e.record.errors.full_messages)
    end

    private

    def failure(*messages)
      { wish_list: nil, errors: messages }
    end

    def replace_items(wish_list, items)
      wish_list.items.destroy_all
      items.each_with_index do |item, index|
        wish_list.items.create!(**item.to_h, position: index)
      end
    end

    def replace_contributions(wish_list, contributions)
      wish_list.contributions.destroy_all
      contributions.each_with_index do |contribution, index|
        wish_list.contributions.create!(**contribution.to_h, position: index)
      end
    end
  end
end
