# frozen_string_literal: true

# Shared helpers for the PostGrid specs.
#
# Nothing here ever reaches the network — webmock is on globally via
# rails_helper, so an unstubbed call fails the example rather than sending one.
module PostGridHelpers
  FIXTURE_DIR = Rails.root.join("spec/fixtures/post_grid")

  # Obviously fake, but the right shape — so a spec asserting "this string never
  # appears in the logs" is asserting something real.
  TEST_API_KEY = "test_sk_specsuitefakekeydonotuse"
  LIVE_API_KEY = "live_sk_specsuitefakekeydonotuse"

  VERIFY_URL = "#{PostGrid::Client::ADDRESS_VERIFICATION_BASE_URL}#{PostGrid::AddressVerification::VERIFY_PATH}"
  POSTCARDS_URL = "#{PostGrid::Client::BASE_URL}#{HolidayCard::ProofGenerator::POSTCARDS_PATH}"

  def post_grid_fixture(name)
    FIXTURE_DIR.join("#{name}.json").read
  end

  # Put keys in the environment for the duration of an example. Real ENV writes,
  # restored afterwards, rather than a partial double on ENV#[] — stubbing that
  # method breaks the Rack round-trip a request spec depends on, and setting it
  # for real exercises the same lookup production uses.
  def with_post_grid_key(test_key: TEST_API_KEY, live_key: nil, mode: nil)
    set_post_grid_env("POSTGRID_TEST_API_KEY", test_key)
    set_post_grid_env("POSTGRID_API_KEY", live_key)
    set_post_grid_env("POSTGRID_MODE", mode)
  end

  def set_post_grid_env(key, value)
    @post_grid_env_backup ||= {}
    @post_grid_env_backup[key] = ENV[key] unless @post_grid_env_backup.key?(key)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end

  def restore_post_grid_env
    @post_grid_env_backup&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    @post_grid_env_backup = nil
  end

  # Credentials are consulted for jwt/gcs/etc. all over a request, so a `with`
  # constraint has to be preceded by a pass-through or every other lookup raises.
  def stub_post_grid_credential(key, value)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:post_grid, key).and_return(value)
  end

  def stub_verification(body:, status: 200)
    stub_request(:post, VERIFY_URL).to_return(
      status:, body:, headers: { "Content-Type" => "application/json" }
    )
  end

  # Defaults to the created-postcard fixture, so the happy path reads as one
  # line. The returned stub is what a spec asserts request headers and body on.
  def stub_postcard_create(body: post_grid_fixture("postcard_test_created"), status: 200)
    stub_request(:post, POSTCARDS_URL).to_return(
      status:, body:, headers: { "Content-Type" => "application/json" }
    )
  end
end

RSpec.configure do |config|
  config.include PostGridHelpers
  config.after { restore_post_grid_env }
end
