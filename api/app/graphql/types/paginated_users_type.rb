# typed: true

module Types
  class PaginatedUsersType < Types::BaseObject
    field :users, [ Types::UserType ], null: false
    field :total_count, Integer, null: false
    field :page, Integer, null: false
    field :per_page, Integer, null: false
    field :total_pages, Integer, null: false
  end
end
