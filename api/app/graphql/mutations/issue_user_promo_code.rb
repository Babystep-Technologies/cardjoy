# typed: true

# app/graphql/mutations/issue_user_promo_code.rb
module Mutations
  class IssueUserPromoCode < Mutations::BaseMutation
    argument :email, String, required: true
    argument :credit_amount, Integer, required: true
    argument :code, String, required: false
    argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(email:, credit_amount:, code: nil, expires_at: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      user = ::User.find_by(email: email.downcase.strip)
      return { promo_code: nil, errors: [ "User not found" ] } unless user

      promo = PromoCode.create!(
        user: user,
        credit_amount: credit_amount,
        usage_limit: 1,
        times_redeemed: 0,
        code: code.presence || PromoCode.generate_unique_code,
        expires_at: expires_at
      )

      UserMailer.promo_code_issued(user: user, promo_code: promo).deliver_later

      { promo_code: promo, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      { promo_code: nil, errors: e.record.errors.full_messages }
    end
  end
end
