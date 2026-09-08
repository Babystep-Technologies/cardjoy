require "rails_helper"

# Asked on entry to the send flow (#153) so an unconfigured deploy can say so
# up front, instead of walking someone to the charge step and refusing there.
RSpec.describe "holidayCardMailingAvailability", type: :request do
  let(:user) { create(:user) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:headers) do
    { "Content-Type" => "application/json",
      "Authorization" => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" }
  end

  let(:query) do
    <<~GRAPHQL
      query HolidayCardMailingAvailability {
        holidayCardMailingAvailability { proofsAvailable mailingAvailable }
      }
    GRAPHQL
  end

  def exec(request_headers: headers)
    post "/graphql", params: { query: }.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  def availability = exec.dig("data", "holidayCardMailingAvailability")

  # The state of every local clone and of CI: no keys, so nothing may be
  # offered. This is the default the spec suite runs in.
  it "reports both halves unavailable when no key is configured" do
    expect(availability).to eq("proofsAvailable" => false, "mailingAvailable" => false)
  end

  # The two halves read different keys on purpose — proofs run in test mode,
  # mailing in live — so a deploy with only a test key must not be told it can
  # mail. That would be the exact late failure this query exists to prevent.
  it "reports proofs available but mailing unavailable with only a test key" do
    with_post_grid_key(test_key: PostGridHelpers::TEST_API_KEY, live_key: nil)

    expect(availability).to eq("proofsAvailable" => true, "mailingAvailable" => false)
  end

  it "reports both available when both keys are configured" do
    with_post_grid_key(
      test_key: PostGridHelpers::TEST_API_KEY, live_key: PostGridHelpers::LIVE_API_KEY
    )

    expect(availability).to eq("proofsAvailable" => true, "mailingAvailable" => true)
  end

  # It says nothing secret, but it says something about our deployment, and the
  # only caller is a signed-in send flow.
  it "refuses an anonymous caller" do
    result = exec(request_headers: { "Content-Type" => "application/json" })

    expect(result["data"]&.fetch("holidayCardMailingAvailability", nil)).to be_nil
    expect(result.fetch("errors", [])).not_to be_empty
  end
end
