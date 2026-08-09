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
      mutation CreateStripeCheckoutSession($priceId: String!, $organizationId: ID) {
        createStripeCheckoutSession(input: { priceId: $priceId, organizationId: $organizationId }) {
          checkoutUrl
          error
        }
      }
    GRAPHQL
  end

  def exec(user:, organization_id: nil)
    variables = { priceId: "price_test", organizationId: organization_id }
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
    expect(@stripe_args[:metadata]).to eq({ user_id: admin.id })
  end

  it "lets an org admin buy into the shared pool and tags the session with the organization" do
    data = exec(user: admin, organization_id: organization.id)

    expect(data["error"]).to be_nil
    expect(data["checkoutUrl"]).to eq("https://checkout.stripe.test/cs_test")
    expect(@stripe_args[:metadata]).to eq({ user_id: admin.id, organization_id: organization.id })
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
