# typed: true

module Queries
  # The cover picker's gallery. `organizationId` selects the context: blank
  # returns only the global curated styles (today's behaviour, and what a
  # Personal context sees), an id adds that organization's own assets on top
  # (#124).
  class Styles < BaseQuery
    type [ Types::StyleType ], null: true
    argument :kind, String, required: false
    argument :tag, String, required: false
    argument :limit, Integer, required: false
    argument :organization_id, ID, required: false

    def resolve(kind: nil, tag: nil, limit: 9, organization_id: nil)
      # A caller who may not read this organization falls back to the global
      # gallery rather than erroring: the picker still works, and an outsider
      # learns nothing about the organization's assets or whether it exists.
      organization = readable_organization(organization_id)
      organization = nil if organization == false

      scope = Style.available_to(organization)
      scope = scope.where(kind: kind) if kind.present?
      if tag.present?
        scope = scope.joins(:tags).where("tags.name ILIKE ?", "%#{tag}%")
      end
      scope.limit(limit).uniq
    end
  end
end
