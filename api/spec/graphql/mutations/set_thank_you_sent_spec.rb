require "rails_helper"

RSpec.describe Mutations::SetThankYouSent, type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:wish_list, :standalone, user: user, surprise_mode: false) }
  let(:item) { create(:wish_list_item, wish_list: list) }
  let!(:claim) { create(:wish_list_reservation, wish_list_item: item) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def headers_for(account)
    { "Authorization" => "Bearer #{JWT.encode({ user_id: account.id }, secret, 'HS256')}", "Content-Type" => "application/json" }
  end

  def mark(sent: true, id: claim.id, registry: list.external_id, as: user)
    post "/graphql",
      params: { query: <<~GRAPHQL, variables: { rid: registry, cid: id.to_s, sent: sent } }.to_json,
        mutation SetThankYouSent($rid: String!, $cid: ID!, $sent: Boolean) {
          setThankYouSent(input: { registryExternalId: $rid, reservationId: $cid, sent: $sent }) { thanked errors }
        }
      GRAPHQL
      headers: headers_for(as)
    JSON.parse(response.body).dig("data", "setThankYouSent")
  end

  it "ticks a guest off and back on the list, and the list reports it" do
    expect(mark["thanked"]).to be(true)
    expect(claim.reload.thanked_at).to be_present

    expect(mark(sent: false)["thanked"]).to be(false)
    expect(claim.reload.thanked_at).to be_nil
  end

  it "keeps the first time when ticked twice" do
    mark
    first = claim.reload.thanked_at

    mark

    expect(claim.reload.thanked_at).to eq(first)
  end

  it "won't touch someone else's registry" do
    expect(mark(as: create(:user))["errors"]).to eq([ "Registry not found" ])
    expect(claim.reload.thanked_at).to be_nil
  end

  it "won't reach a claim on a different registry" do
    other_claim = create(:wish_list_reservation, wish_list_item: create(:wish_list_item, wish_list: create(:wish_list, :standalone, user: user)))

    expect(mark(id: other_claim.id)["errors"]).to eq([ "Claim not found" ])
  end

  it "stays locked while surprise mode hides who gave what" do
    list.update!(surprise_mode: true, event_date: Date.current + 5)

    expect(mark["errors"].join).to include("hidden until after the event")
    expect(claim.reload.thanked_at).to be_nil
  end
end
