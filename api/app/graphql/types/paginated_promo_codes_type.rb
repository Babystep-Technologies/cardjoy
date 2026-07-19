# typed: true

module Types
  class PaginatedPromoCodesType < Types::BaseObject
    field :promo_codes, [ Types::PromoCodeType ], null: false
    field :total_count, Integer, null: false
    field :page, Integer, null: false
    field :per_page, Integer, null: false
    field :total_pages, Integer, null: false
  end
end
