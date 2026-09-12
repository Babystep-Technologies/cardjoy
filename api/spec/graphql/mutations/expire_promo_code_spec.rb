# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::ExpirePromoCode, type: :request do
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
      mutation ExpirePromoCode($id: ID!) {
        expirePromoCode(input: { id: $id }) {
          promoCode { id expiresAt }
          errors
        }
      }
    GRAPHQL
  end

  def exec(id:, headers: admin_headers)
    post "/graphql", params: { query: mutation, variables: { id: id } }.to_json, headers: headers
    JSON.parse(response.body)
  end

  it "moves expiresAt into the past" do
    promo = create(:promo_code, expires_at: 1.week.from_now)

    payload = exec(id: promo.id).dig("data", "expirePromoCode")

    expect(payload["errors"]).to be_empty
    expect(Time.zone.parse(payload.dig("promoCode", "expiresAt"))).to be < Time.current
  end

  it "reports an unknown code as not found" do
    payload = exec(id: "0").dig("data", "expirePromoCode")
    expect(payload["errors"]).to eq [ "Promo code not found" ]
  end

  it "refuses a regular user's token" do
    promo = create(:promo_code)
    body = exec(id: promo.id, headers: user_headers)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(promo.reload.expires_at).to be > Time.current
  end
end
