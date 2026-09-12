# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::UpdatePromoCode, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:admin_headers) do
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{JWT.encode({ admin_id: admin.id }, secret, 'HS256')}" }
  end
  let(:user_headers) do
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" }
  end

  let(:mutation) do
    <<~GRAPHQL
      mutation UpdatePromoCode($id: ID!, $creditAmount: Int, $usageLimit: Int, $expiresAt: ISO8601DateTime) {
        updatePromoCode(input: { id: $id, creditAmount: $creditAmount, usageLimit: $usageLimit, expiresAt: $expiresAt }) {
          promoCode { id creditAmount usageLimit }
          errors
        }
      }
    GRAPHQL
  end

  def exec(id:, variables: {}, headers: admin_headers)
    post "/graphql", params: { query: mutation, variables: { id: id, **variables } }.to_json, headers: headers
    JSON.parse(response.body)
  end

  it "updates amount and usage limit on an unredeemed code" do
    promo = create(:promo_code, credit_amount: 5, usage_limit: 10, times_redeemed: 0)

    payload = exec(id: promo.id, variables: { creditAmount: 20, usageLimit: 50 }).dig("data", "updatePromoCode")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("promoCode", "creditAmount")).to eq 20
    expect(payload.dig("promoCode", "usageLimit")).to eq 50
  end

  it "refuses a code that has already been redeemed" do
    promo = create(:promo_code, credit_amount: 5, usage_limit: 10, times_redeemed: 1)

    payload = exec(id: promo.id, variables: { creditAmount: 20 }).dig("data", "updatePromoCode")

    expect(payload["errors"]).to eq [ "Promo code has already been redeemed and cannot be edited" ]
    expect(promo.reload.credit_amount).to eq 5
  end

  it "reports an unknown code as not found" do
    payload = exec(id: "0", variables: { creditAmount: 20 }).dig("data", "updatePromoCode")
    expect(payload["errors"]).to eq [ "Promo code not found" ]
  end

  it "refuses a regular user's token" do
    promo = create(:promo_code, credit_amount: 5)
    body = exec(id: promo.id, variables: { creditAmount: 20 }, headers: user_headers)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(promo.reload.credit_amount).to eq 5
  end
end
