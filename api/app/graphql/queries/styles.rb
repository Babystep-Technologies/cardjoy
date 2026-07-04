# typed: true

module Queries
  class Styles < BaseQuery
    type [ Types::StyleType ], null: true
    argument :kind, String, required: false
    argument :tag, String, required: false
    argument :limit, Integer, required: false

    def resolve(kind: nil, tag: nil, limit: 9)
      scope = Style.all
      scope = scope.where(kind: kind) if kind.present?
      if tag.present?
        scope = scope.joins(:tags).where("tags.name ILIKE ?", "%#{tag}%")
      end
      scope.limit(limit).uniq
    end
  end
end
