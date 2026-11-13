# typed: true

module Queries
  # Reads back one claim by its bearer token, so the "manage my claim" link in a guest's email works
  # in a browser that never held the token (#248). Public like reserve and release: the token is the
  # only credential. Unknown tokens read as nil.
  class WishListClaim < BaseQuery
    type Types::WishListClaimType, null: true
    argument :token, String, required: true

    def resolve(token:)
      ::WishListReservation.find_by(token: token)
    end
  end
end
