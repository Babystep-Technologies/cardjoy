# typed: true

module Queries
  # One registry by its public `external_id`. A hidden registry reads as missing to everyone but
  # its owner, so the id can't be used to learn which registries exist or peek at an unpublished
  # one (the owner builds it before sharing).
  class Registry < BaseQuery
    type Types::WishListType, null: true
    argument :external_id, String, required: true
    # For a registry its owner protected: errors with PASSCODE_REQUIRED / PASSCODE_INVALID until the
    # right one is given, so the page knows to ask.
    argument :passcode, String, required: false

    def resolve(external_id:, passcode: nil)
      list = ::WishList.find_by(external_id: external_id)
      return nil unless list
      return nil unless list.visible || list.owned_by?(context[:current_user])
      return list if list.open_to?(context[:current_user], passcode)

      code = passcode.blank? ? "PASSCODE_REQUIRED" : "PASSCODE_INVALID"
      raise GraphQL::ExecutionError.new(
        passcode.blank? ? "This registry needs a passcode" : "That passcode isn't right",
        extensions: { code: code }
      )
    end
  end
end
