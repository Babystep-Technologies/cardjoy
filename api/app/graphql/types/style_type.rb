# typed: strict

module Types
  class StyleType < Types::BaseObject
    extend T::Sig

    field :id, ID, null: false
    field :name, String, null: false
    field :kind, String, null: false
    field :value, String, null: false
    field :tags, [ Types::TagType ], null: true

    # NULL for the global curated gallery, set for an organization's own asset
    # (#124) — what the picker groups its "Our brand" section by.
    field :organization_id, ID, null: true
  end
end
