# typed: true

module Types
  class PromoCodeType < Types::BaseObject
    field :id, ID, null: false
    field :code, String, null: false
    field :credit_amount, Integer, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
    field :usage_limit, Integer, null: true
    field :times_redeemed, Integer, null: true
    field :user, Types::UserType, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
