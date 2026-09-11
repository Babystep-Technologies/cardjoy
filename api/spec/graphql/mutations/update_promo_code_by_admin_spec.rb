# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::UpdatePromoCodeByAdmin, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation UpdatePromoCodeByAdmin($id: ID!, $action: String!) {
        updatePromoCodeByAdmin(input: { id: $id, action: $action }) {
          promoCode { id status disabledAt expiresAt }
          errors
        }
      }
    GRAPHQL
  end

  def exec_raw(id:, action:, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { id: id, action: action } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def exec(id:, action:, token: admin_token)
    exec_raw(id: id, action: action, token: token).dig("data", "updatePromoCodeByAdmin")
  end

  it "disables an active code" do
    promo = create(:promo_code)

    data = exec(id: promo.id, action: "disable")

    expect(data["errors"]).to be_empty
    expect(data["promoCode"]["status"]).to eq "disabled"
    expect(promo.reload.disabled_at).to be_present
  end

  it "re-enables a disabled code" do
    promo = create(:promo_code, :disabled)

    data = exec(id: promo.id, action: "enable")

    expect(data["errors"]).to be_empty
    expect(data["promoCode"]["status"]).to eq "active"
    expect(promo.reload.disabled_at).to be_nil
  end

  it "expires a code immediately" do
    promo = create(:promo_code, expires_at: 1.week.from_now)

    data = exec(id: promo.id, action: "expire")

    expect(data["errors"]).to be_empty
    expect(data["promoCode"]["status"]).to eq "expired"
    expect(promo.reload.expires_at).to be_past
  end

  it "returns an error for an unknown id" do
    data = exec(id: "0", action: "disable")

    expect(data["promoCode"]).to be_nil
    expect(data["errors"]).to eq [ "Promo code not found" ]
  end

  it "returns an error for an invalid action" do
    promo = create(:promo_code)

    data = exec(id: promo.id, action: "delete")

    expect(data["promoCode"]).to be_nil
    expect(data["errors"]).to eq [ "Invalid action" ]
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    promo = create(:promo_code)

    body = exec_raw(id: promo.id, action: "disable", token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "updatePromoCodeByAdmin")).to be_nil
  end
end
