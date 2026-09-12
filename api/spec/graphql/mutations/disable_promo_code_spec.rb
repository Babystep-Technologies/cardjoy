# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::DisablePromoCode, type: :request do
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
      mutation DisablePromoCode($id: ID!) {
        disablePromoCode(input: { id: $id }) {
          promoCode { id }
          errors
        }
      }
    GRAPHQL
  end

  def exec(id:, headers: admin_headers)
    post "/graphql", params: { query: mutation, variables: { id: id } }.to_json, headers: headers
    JSON.parse(response.body)
  end

  it "disables the code so it can no longer be redeemed" do
    promo = create(:promo_code)

    payload = exec(id: promo.id).dig("data", "disablePromoCode")

    expect(payload["errors"]).to be_empty
    expect(promo.reload.disabled_at).to be_present
    expect { promo.redeem!(user: user) }.to raise_error(PromoCode::DisabledError)
  end

  it "reports an unknown code as not found" do
    payload = exec(id: "0").dig("data", "disablePromoCode")
    expect(payload["errors"]).to eq [ "Promo code not found" ]
  end

  it "refuses a regular user's token" do
    promo = create(:promo_code)
    body = exec(id: promo.id, headers: user_headers)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(promo.reload.disabled_at).to be_nil
  end
end
