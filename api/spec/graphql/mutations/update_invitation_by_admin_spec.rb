# typed: false

require "rails_helper"
require "jwt"

# Moderation for one invitation (#177) — the actions the admin dashboard had for
# cards and not for invitations, so an abuse report about an invitation had no
# answer at all.
RSpec.describe "UpdateInvitationByAdmin", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let!(:invitation) { create(:invitation, user: user) }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation UpdateInvitationByAdmin($externalId: String!, $action: String!) {
        updateInvitationByAdmin(input: { externalId: $externalId, action: $action }) {
          invitation { externalId locked flagged deleted }
          errors
        }
      }
    GRAPHQL
  end

  def act(action, external_id: invitation.external_id, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { externalId: external_id, action: action } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  it "rejects a customer JWT" do
    expect(act("flag", token: user_token)["errors"].first["message"]).to eq "Not authorized"
  end

  it "flags and unflags" do
    expect(act("flag").dig("data", "updateInvitationByAdmin", "invitation", "flagged")).to be true
    expect(act("unflag").dig("data", "updateInvitationByAdmin", "invitation", "flagged")).to be false
  end

  it "locks and unlocks" do
    expect(act("lock").dig("data", "updateInvitationByAdmin", "invitation", "locked")).to be true
    expect(act("unlock").dig("data", "updateInvitationByAdmin", "invitation", "locked")).to be false
  end

  it "archives, and can still reach the invitation afterwards to restore it" do
    expect(act("archive").dig("data", "updateInvitationByAdmin", "invitation", "deleted")).to be true
    expect(Invitation.find_by(external_id: invitation.external_id)).to be_nil

    payload = act("unarchive").dig("data", "updateInvitationByAdmin")

    expect(payload["invitation"]["deleted"]).to be false
    expect(Invitation.find_by(external_id: invitation.external_id)).to be_present
  end

  it "reports an unknown action rather than doing nothing quietly" do
    payload = act("banish").dig("data", "updateInvitationByAdmin")

    expect(payload["errors"]).to eq [ "Invalid action" ]
    expect(payload["invitation"]).to be_nil
  end

  it "reports a missing invitation" do
    payload = act("flag", external_id: "nope").dig("data", "updateInvitationByAdmin")

    expect(payload["errors"]).to eq [ "Invitation not found" ]
  end

  it "offers the same action vocabulary as the card mutation it mirrors" do
    expect(Mutations::UpdateInvitationByAdmin::VALID_ACTIONS)
      .to eq Mutations::UpdateCardByAdmin::VALID_ACTIONS
  end
end
