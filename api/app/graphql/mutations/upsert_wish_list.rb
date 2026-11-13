# typed: false
# frozen_string_literal: true

module Mutations
  # Creates or replaces a registry (#245). It targets, in order: the list attached to the invitation
  # named by `invitation_external_id`; the caller's standalone registry named by
  # `registry_external_id`; or, with neither, a brand-new standalone registry for the caller. The
  # host edits the whole list in
  # one form, so items and contributions are sent in full and replace what was there -- except that
  # an item carrying its existing id is updated in place rather than destroyed and recreated, so a
  # WishListReservation against it survives the edit. Items without an id (new ones, or a client that
  # hasn't been updated to round-trip ids) are still created fresh, matching the old behavior.
  class UpsertWishList < BaseMutation
    argument :invitation_external_id, String, required: false
    argument :registry_external_id, String, required: false
    argument :occasion, String, required: false
    argument :event_date, GraphQL::Types::ISO8601Date, required: false
    argument :title, String, required: false
    argument :intro, String, required: false
    argument :visible, Boolean, required: false
    argument :surprise_mode, Boolean, required: false
    argument :share_address, Boolean, required: false
    argument :items, [ Types::WishListItemInputType ], required: false
    argument :contributions, [ Types::WishListContributionInputType ], required: false

    field :wish_list, Types::WishListType, null: true
    field :errors, [ String ], null: false

    def resolve(invitation_external_id: nil, registry_external_id: nil, items: nil, contributions: nil,
                **attributes)
      user = context[:current_user]
      return failure("You must be signed in") unless user
      if invitation_external_id.present? && registry_external_id.present?
        return failure("Pass an invitation or a registry, not both")
      end

      wish_list = find_target(user, invitation_external_id, registry_external_id)
      return failure(@target_error) unless wish_list

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
    rescue ActiveRecord::RecordNotFound
      failure("Item not found")
    end

    private

    # Sets @target_error and returns nil when the caller may not write to the named target.
    def find_target(user, invitation_external_id, registry_external_id)
      if invitation_external_id.present?
        invitation = Invitation.find_by(external_id: invitation_external_id)
        @target_error = "Invitation not found"
        return nil unless invitation&.editable_by?(user)

        invitation.wish_list || invitation.build_wish_list
      elsif registry_external_id.present?
        @target_error = "Registry not found"
        user.wish_lists.find_by(external_id: registry_external_id)
      else
        user.wish_lists.build
      end
    end

    def failure(*messages)
      { wish_list: nil, errors: messages }
    end

    def replace_items(wish_list, items)
      kept_ids = items.filter_map { |item| item[:id] }
      wish_list.items.where.not(id: kept_ids).destroy_all

      items.each_with_index do |item, index|
        attrs = item.to_h.except(:id)
        if item[:id].present?
          wish_list.items.find(item[:id]).update!(**attrs, position: index)
        else
          wish_list.items.create!(**attrs, position: index)
        end
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
