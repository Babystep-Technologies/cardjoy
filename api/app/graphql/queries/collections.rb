# typed: false

module Queries
  class Collections < BaseQuery
    type [ Types::CollectionType ], null: false
    argument :name, String, required: false

    def resolve(name: nil)
      scope = Concurrent::Collection.all
      scope = scope.where("name ILIKE ?", "%#{name}%") if name.present?
      scope.order(updated_at: :desc)
    end
  end
end
