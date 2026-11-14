# typed: false

require "rails_helper"
require "jwt"

# The registry list the admin dashboard reads from (#317).
RSpec.describe "Admin registries", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def token_for(claims) = JWT.encode(claims, secret, "HS256")

  def exec(variables: {}, token: token_for(admin_id: admin.id))
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    JSON.parse(response.body)
  end

  let(:query) do
    <<~GRAPHQL
      query AdminRegistries($search: String, $occasion: String, $sort: String, $direction: String) {
        adminRegistries(search: $search, occasion: $occasion, sort: $sort, direction: $direction) {
          registries {
            externalId title occasion passcodeProtected itemCount claimCount purchasedCount
            user { name email }
          }
          totalCount
        }
      }
    GRAPHQL
  end

  def registries(variables = {})
    exec(variables: variables).dig("data", "adminRegistries", "registries")
  end

  it "rejects a customer JWT" do
    expect(exec(token: token_for(user_id: user.id))["errors"].first["message"]).to eq "Not authorized"
  end

  it "lists standalone registries with their counts and leaves out an invitation's own wish list" do
    registry = create(:wish_list, user: owner, title: "Dana's birthday", occasion: "birthday", invitation_id: nil)
    item = create(:wish_list_item, wish_list: registry, title: "Kettle")
    create(:wish_list_item, wish_list: registry, title: "Mug")
    create(:wish_list_reservation, wish_list_item: item, purchased_at: Time.current)
    create(:wish_list, user: owner, title: "Party list", invitation: create(:invitation, user: owner))

    rows = registries

    expect(rows.map { |r| r["title"] }).to eq [ "Dana's birthday" ]
    expect(rows.first).to include("itemCount" => 2, "claimCount" => 1, "purchasedCount" => 1,
      "passcodeProtected" => false)
    expect(rows.first["user"]).to eq("name" => "Dana Host", "email" => "dana@example.com")
  end

  it "searches by title or owner and filters by occasion" do
    create(:wish_list, user: owner, title: "Kitchen", occasion: "wedding", invitation_id: nil)
    create(:wish_list, user: create(:user, email: "sam@example.com"), title: "Toys", occasion: "birthday", invitation_id: nil)

    expect(registries("search" => "dana").map { |r| r["title"] }).to eq [ "Kitchen" ]
    expect(registries("occasion" => "birthday").map { |r| r["title"] }).to eq [ "Toys" ]
  end

  it "reports a bad sort as an error" do
    expect(exec(variables: { sort: "nope" })["errors"].first["message"]).to match(/Invalid sort/)
  end
end
