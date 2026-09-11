# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::EditPromoCodeByAdmin, type: :request do
  let(:admin) { create(:admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation EditPromoCodeByAdmin($id: ID!, $code: String, $creditAmount: Int, $usageLimit: Int, $expiresAt: ISO8601DateTime) {
        editPromoCodeByAdmin(
          input: { id: $id, code: $code, creditAmount: $creditAmount, usageLimit: $usageLimit, expiresAt: $expiresAt }
        ) {
          promoCode { id code creditAmount usageLimit expiresAt }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{admin_token}" }
    JSON.parse(response.body).dig("data", "editPromoCodeByAdmin")
  end

  it "changes only the fields passed" do
    promo = create(:promo_code, code: "original", credit_amount: 5, usage_limit: 10)

    data = exec(id: promo.id, creditAmount: 25)

    expect(data["errors"]).to be_empty
    expect(data["promoCode"]).to include("code" => "original", "creditAmount" => 25, "usageLimit" => 10)
  end

  it "surfaces the model's own validation as an error rather than raising" do
    assignee = create(:user)
    promo = create(:promo_code, :user_specific, user: assignee)

    data = exec(id: promo.id, usageLimit: 5)

    expect(data["promoCode"]).to be_nil
    expect(data["errors"]).to be_present
    expect(promo.reload.usage_limit).to eq 1
  end

  it "returns an error for an unknown id" do
    data = exec(id: "0", code: "whatever")

    expect(data["promoCode"]).to be_nil
    expect(data["errors"]).to eq [ "Promo code not found" ]
  end
end
