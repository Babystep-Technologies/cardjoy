# typed: false
# frozen_string_literal: true

module Mutations
  # Requires sign-in (like Mutations::UpsertWishList) even though it isn't tied to a specific
  # invitation yet -- the invitation may not exist as a record while a host is still building it in
  # the create flow. Authentication is the abuse guard for an endpoint that fetches arbitrary URLs on
  # the server's behalf; see WishListLinkPreview for the SSRF/timeout/size hardening.
  class PreviewWishListLink < BaseMutation
    argument :url, String, required: true

    field :preview, Types::WishListLinkPreviewType, null: true
    field :errors, [ String ], null: false

    def resolve(url:)
      return { preview: nil, errors: [ "You must be signed in" ] } unless context[:current_user]

      result = WishListLinkPreview.fetch(url)
      return { preview: nil, errors: [ "Couldn't find a preview for that link" ] } unless result

      { preview: result, errors: [] }
    end
  end
end
