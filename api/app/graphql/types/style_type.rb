# typed: strict

module Types
  class StyleType < Types::BaseObject
    extend T::Sig

    field :id, ID, null: false
    field :name, String, null: false
    field :kind, String, null: false
    field :value, String, null: false
    field :tags, [ Types::TagType ], null: true
  end
end
