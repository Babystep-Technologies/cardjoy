require "rails_helper"

RSpec.describe Mutations::CreateStripeCheckoutSession, type: :request do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:outsider) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before do
    create(:organization_membership, :admin, organization:, user: admin)
    create(:organization_membership, organization:, user: member)

    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return("https://cardjoy.test")
  end

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation CreateStripeCheckoutSession(
        $priceId: String
        $organizationId: ID
        $product: String
        $topUpCents: Int
      ) {
        createStripeCheckoutSession(input: {
          priceId: $priceId
          organizationId: $organizationId
          product: $product
          topUpCents: $topUpCents
        }) {
          checkoutUrl
          error
        }
      }
    GRAPHQL
  end

  def exec(user:, organization_id: nil, price_id: "price_test", product: nil, top_up_cents: nil)
    variables = { priceId: price_id, organizationId: organization_id, product:, topUpCents: top_up_cents }
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "createStripeCheckoutSession")
  end

  # Capture what we hand Stripe without talking to it.
  def stub_stripe
    session = double(url: "https://checkout.stripe.test/cs_test")
    allow(Stripe::Checkout::Session).to receive(:create) { |args| @stripe_args = args; session }
  end

  before { stub_stripe }

  it "creates a personal session with only the user in metadata" do
    data = exec(user: admin)

    expect(data["error"]).to be_nil
    expect(data["checkoutUrl"]).to eq("https://checkout.stripe.test/cs_test")
    expect(@stripe_args[:metadata]).to eq({ user_id: admin.id, product: "credits" })
    expect(@stripe_args[:line_items]).to eq([ { price: "price_test", quantity: 1 } ])
    expect(@stripe_args[:success_url]).to start_with("https://cardjoy.test/buy_credits/success")
  end

  it "lets an org admin buy into the shared pool and tags the session with the organization" do
    data = exec(user: admin, organization_id: organization.id)

    expect(data["error"]).to be_nil
    expect(data["checkoutUrl"]).to eq("https://checkout.stripe.test/cs_test")
    expect(@stripe_args[:metadata]).to eq(
      { user_id: admin.id, product: "credits", organization_id: organization.id }
    )
  end

  it "refuses a credit session with no price" do
    data = exec(user: admin, price_id: nil)

    expect(data["error"]).to eq(Mutations::CreateStripeCheckoutSession::MISSING_PRICE_ID_ERROR)
    expect(Stripe::Checkout::Session).not_to have_received(:create)
  end

  it "refuses a product it does not sell" do
    data = exec(user: admin, product: "bananas")

    expect(data["error"]).to eq(Mutations::CreateStripeCheckoutSession::UNKNOWN_PRODUCT_ERROR)
    expect(data["checkoutUrl"]).to be_nil
    expect(Stripe::Checkout::Session).not_to have_received(:create)
  end

  describe "postage top-ups" do
    it "tags the session with the product and the tier, and prices it inline" do
      data = exec(user: admin, product: "postage", top_up_cents: 2500, price_id: nil)

      expect(data["error"]).to be_nil
      expect(data["checkoutUrl"]).to eq("https://checkout.stripe.test/cs_test")
      expect(@stripe_args[:metadata]).to eq(
        { user_id: admin.id, product: "postage", postage_cents: 2500 }
      )

      # The amount charged is the tier itself, so it can't drift from the amount
      # the webhook banks.
      line_item = @stripe_args[:line_items].first
      expect(line_item[:price_data][:unit_amount]).to eq(2500)
      expect(line_item[:price_data][:currency]).to eq("usd")
      expect(line_item[:price_data][:product_data][:name]).to eq("CardJoy postage — $25.00")

      expect(@stripe_args[:success_url]).to start_with("https://cardjoy.test/buy_postage/success")
      expect(@stripe_args[:cancel_url]).to eq("https://cardjoy.test/buy_postage/cancel")
    end

    it "sells every tier on the server-side list" do
      PostageCredit::TOP_UP_TIERS_CENTS.each do |cents|
        data = exec(user: admin, product: "postage", top_up_cents: cents, price_id: nil)

        expect(data["error"]).to be_nil
        expect(@stripe_args[:metadata][:postage_cents]).to eq(cents)
      end
    end

    it "will not let the client name its own amount" do
      data = exec(user: admin, product: "postage", top_up_cents: 1, price_id: nil)

      expect(data["error"]).to eq(Mutations::CreateStripeCheckoutSession::INVALID_TOP_UP_ERROR)
      expect(Stripe::Checkout::Session).not_to have_received(:create)
    end

    it "refuses a top-up with no amount at all" do
      data = exec(user: admin, product: "postage", price_id: nil)

      expect(data["error"]).to eq(Mutations::CreateStripeCheckoutSession::INVALID_TOP_UP_ERROR)
      expect(Stripe::Checkout::Session).not_to have_received(:create)
    end

    it "ignores a price id rather than charging it alongside the tier" do
      exec(user: admin, product: "postage", top_up_cents: 1000, price_id: "price_test")

      expect(@stripe_args[:line_items].length).to eq(1)
      expect(@stripe_args[:line_items].first).not_to have_key(:price)
    end

    # The wallet hangs off a user, so there is no organization pool to buy into.
    it "refuses to buy postage into an organization" do
      data = exec(user: admin, product: "postage", top_up_cents: 1000, organization_id: organization.id)

      expect(data["error"]).to eq(Mutations::CreateStripeCheckoutSession::POSTAGE_IS_PERSONAL_ERROR)
      expect(Stripe::Checkout::Session).not_to have_received(:create)
    end
  end

  it "refuses a member who is not an admin" do
    data = exec(user: member, organization_id: organization.id)

    expect(data["error"]).to eq(Mutations::BaseMutation::NOT_AUTHORIZED_ERROR)
    expect(data["checkoutUrl"]).to be_nil
    expect(Stripe::Checkout::Session).not_to have_received(:create)
  end

  it "refuses a non-member" do
    data = exec(user: outsider, organization_id: organization.id)

    expect(data["error"]).to eq(Mutations::BaseMutation::NOT_AUTHORIZED_ERROR)
    expect(Stripe::Checkout::Session).not_to have_received(:create)
  end

  it "refuses an organization that does not exist" do
    data = exec(user: admin, organization_id: "999999")

    expect(data["error"]).to eq(Mutations::BaseMutation::NOT_AUTHORIZED_ERROR)
    expect(Stripe::Checkout::Session).not_to have_received(:create)
  end
end
