# typed: true
# frozen_string_literal: true

module Mutations
  class RemoveRegistryCoverImage < BaseMutation
    argument :registry_external_id, String, required: true

    field :wish_list, Types::WishListType, null: true
    field :errors, [ String ], null: false

    def resolve(registry_external_id:)
      user = context[:current_user]
      return { wish_list: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      list = user.wish_lists.find_by(external_id: registry_external_id)
      return { wish_list: nil, errors: [ "Registry not found" ] } unless list

      list.cover_image.purge if list.cover_image.attached?
      { wish_list: list.reload, errors: [] }
    end
  end
end
