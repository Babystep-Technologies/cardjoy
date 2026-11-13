# typed: true

module Queries
  # One registry by its public `external_id`. A hidden registry reads as missing to everyone but
  # its owner, so the id can't be used to learn which registries exist or peek at an unpublished
  # one (the owner builds it before sharing).
  class Registry < BaseQuery
    type Types::WishListType, null: true
    argument :external_id, String, required: true

    def resolve(external_id:)
      list = ::WishList.find_by(external_id: external_id)
      return nil unless list
      return list if list.visible || list.owned_by?(context[:current_user])

      nil
    end
  end
end
