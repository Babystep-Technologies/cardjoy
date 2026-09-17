# typed: true
# frozen_string_literal: true

module Queries
  # The editor's option catalogue: fonts, the type scale, zoom limits, and the
  # other constants the client must agree with the server on. Reference data
  # compiled into the release, so — like the templates and stickers — no auth and
  # no database.
  #
  # It resolves to a constant because every field on
  # Types::PostCardEditorOptionsType reads a Ruby constant off `self`; there
  # is no per-caller object for it to wrap.
  class PostCardEditorOptions < BaseQuery
    type Types::PostCardEditorOptionsType, null: false

    def resolve = {}
  end
end
