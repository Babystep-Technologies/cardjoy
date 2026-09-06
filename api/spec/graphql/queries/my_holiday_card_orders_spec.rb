require "rails_helper"

# The read side of the send flow (#148): what happened to each piece, scoped to
# the caller, with our cost and our margin nowhere in sight.
RSpec.describe "myHolidayCardOrders", type: :request do
  let(:user) { create(:user) }
  let(:stranger) { create(:user) }
  let(:card) { create(:holiday_card, user:) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:headers) do
    { "Content-Type" => "application/json",
      "Authorization" => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" }
  end

  let(:query) do
    <<~GRAPHQL
      query MyHolidayCardOrders($holidayCardId: ID!) {
        myHolidayCardOrders(holidayCardId: $holidayCardId) {
          id
          status
          chargedCents
          recipientName
          recipientAddress { name addressLine1 addressLine2 city region postalCode countryCode }
          contactId
          trackingNumber
          failureReason
          submittedAt
          createdAt
        }
      }
    GRAPHQL
  end

  def exec(holiday_card_id: card.external_id, request_headers: headers)
    post "/graphql",
      params: { query:, variables: { holidayCardId: holiday_card_id } }.to_json,
      headers: request_headers
    JSON.parse(response.body)
  end

  def orders_for(**) = exec(**).dig("data", "myHolidayCardOrders")

  def error_messages(result) = result.fetch("errors", []).map { |error| error["message"] }

  it "returns the card's orders, newest first" do
    older = create(:holiday_card_mail_order, user:, holiday_card: card, created_at: 2.days.ago)
    newer = create(:holiday_card_mail_order, :submitted, user:, holiday_card: card, created_at: 1.hour.ago)

    expect(orders_for.map { |order| order["id"] }).to eq([ newer.id.to_s, older.id.to_s ])
    expect(orders_for.map { |order| order["status"] }).to eq([ "submitted", "pending" ])
  end

  it "serves the recipient from the snapshot, so a deleted contact still reads" do
    contact = create(:contact, :mailable, user:, name: "Ada Lovelace")
    create(:holiday_card_mail_order, user:, holiday_card: card, recipient: contact)
    contact.destroy!

    order = orders_for.first
    expect(order["contactId"]).to be_nil
    expect(order["recipientName"]).to eq("Ada Lovelace")
    expect(order["recipientAddress"]).to include(
      "name" => "Ada Lovelace", "addressLine1" => "123 Market St", "city" => "San Francisco"
    )
  end

  it "reports a failed piece with its reason" do
    create(:holiday_card_mail_order, :failed, user:, holiday_card: card)

    expect(orders_for.first["failureReason"]).to be_present
    expect(orders_for.first["status"]).to eq("failed")
  end

  it "returns an empty list for a card that has never been sent" do
    expect(orders_for).to eq([])
  end

  it "does not include orders for the caller's other cards" do
    create(:holiday_card_mail_order, user:, holiday_card: create(:holiday_card, user:))

    expect(orders_for).to eq([])
  end

  # Someone else's card and a card that doesn't exist give the same answer, so a
  # stranger can't use this to learn which externalIds are real.
  it "refuses somebody else's card" do
    other = create(:holiday_card, user: stranger)
    create(:holiday_card_mail_order, user: stranger, holiday_card: other)

    result = exec(holiday_card_id: other.external_id)

    # The field is non-null, so the error nullifies the whole selection rather
    # than handing back an empty list that reads like "no orders".
    expect(result["data"]).to be_nil
    expect(error_messages(result)).to eq([ "Not authorized" ])
  end

  it "gives the same answer for a card that doesn't exist" do
    expect(error_messages(exec(holiday_card_id: "ZZZZZZZ"))).to eq([ "Not authorized" ])
  end

  # Our cost and our margin are ours. A type that exposed the split would
  # publish the margin on every order anyone ever placed.
  it "exposes neither baseCents nor rateCardVersion" do
    fields = ApiSchema.types["HolidayCardMailOrder"].fields.keys

    expect(fields).not_to include("baseCents", "rateCardVersion", "markupCents")
    expect(fields).to include("chargedCents")
  end
end
