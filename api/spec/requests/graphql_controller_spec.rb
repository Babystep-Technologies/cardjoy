require "rails_helper"

# Guards GraphqlController#public_operation?, which decides whether an operation
# skips the controller-level auth gate. It must match operationName *exactly*: a
# substring match (the old behaviour) let any operation whose name merely contains
# a public name — e.g. "UpdateCard" contains "Card" — bypass authentication.
RSpec.describe "GraphQL authentication gate", type: :request do
  def post_operation(operation_name, query, headers: {})
    post "/graphql",
      params: { query:, operationName: operation_name }.to_json,
      headers: { "Content-Type" => "application/json" }.merge(headers)
  end

  context "a public operation" do
    it "is not challenged when unauthenticated" do
      post_operation("Card", "query Card { __typename }")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig("data", "__typename")).to be_present
      expect(json["errors"]).to be_nil
    end
  end

  context "the organization invitation preview" do
    it "is not challenged when unauthenticated — the invitee may have no account yet" do
      post_operation("OrganizationInvitationPreview", "query OrganizationInvitationPreview { __typename }")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["errors"]).to be_nil
    end

    it "does not make the rest of the invitation flow public" do
      %w[InviteToOrganization AcceptOrganizationInvitation RevokeOrganizationInvitation].each do |operation|
        post_operation(operation, "mutation #{operation} { __typename }")

        expect(response).to have_http_status(:unauthorized), "expected #{operation} to stay behind auth"
      end
    end
  end

  context "a non-public operation whose name contains a public substring" do
    it "is challenged when unauthenticated" do
      post_operation("UpdateCard", "mutation UpdateCard { __typename }")

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to include("Unauthorized")
    end

    it "passes the gate for an authenticated user" do
      user = create(:user)
      token = JWT.encode({ user_id: user.id, exp: 1.hour.from_now.to_i }, Rails.configuration.x.jwt_secret)

      post_operation(
        "UpdateCard",
        "mutation UpdateCard { __typename }",
        headers: { "Authorization" => "Bearer #{token}" }
      )

      expect(response).to have_http_status(:ok)
    end
  end
end
