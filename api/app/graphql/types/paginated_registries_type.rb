# typed: true
# frozen_string_literal: true

module Types
  class PaginatedRegistriesType < Types::BaseObject
    field :registries, [ Types::AdminRegistryType ], null: false
    field :total_count, Integer, null: false
    field :current_page, Integer, null: false
    field :per_page, Integer, null: false
  end
end
