require "rails_helper"

RSpec.describe PostGrid do
  describe ".api_key" do
    it "selects the live or test key from the explicit mode, not from Rails.env" do
      with_post_grid_key(test_key: "test_sk_a", live_key: "live_sk_b")

      expect(described_class.api_key(mode: :test)).to eq("test_sk_a")
      expect(described_class.api_key(mode: :live)).to eq("live_sk_b")
    end

    # The proof run deliberately uses the test key from production. If mode were
    # derived from Rails.env that would be inexpressible — and a staging box
    # booting as `production` would mail real postcards.
    it "still returns the test key when the app is running as production" do
      with_post_grid_key(test_key: "test_sk_a", live_key: "live_sk_b")
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      expect(described_class.api_key(mode: :test)).to eq("test_sk_a")
    end

    it "falls back to Rails credentials when the env var is unset" do
      with_post_grid_key(test_key: nil)
      stub_post_grid_credential(:test_api_key, "test_sk_c")

      expect(described_class.api_key(mode: :test)).to eq("test_sk_c")
    end

    it "rejects an unknown mode rather than quietly picking one" do
      expect { described_class.api_key(mode: :staging) }.to raise_error(ArgumentError, /Unknown PostGrid mode/)
    end
  end

  describe ".configured?" do
    it "is false when no key is set" do
      with_post_grid_key(test_key: nil)
      stub_post_grid_credential(:test_api_key, nil)

      expect(described_class.configured?(mode: :test)).to be(false)
    end

    it "treats a blank env var as unset" do
      with_post_grid_key(test_key: "")
      stub_post_grid_credential(:test_api_key, nil)

      expect(described_class.configured?(mode: :test)).to be(false)
    end

    it "is true once a key is present" do
      with_post_grid_key

      expect(described_class.configured?(mode: :test)).to be(true)
    end
  end

  describe ".default_mode" do
    it "defaults to test, the safe direction to be wrong in" do
      with_post_grid_key(mode: nil)
      stub_post_grid_credential(:mode, nil)

      expect(described_class.default_mode).to eq(:test)
    end

    it "is live only when POSTGRID_MODE says so exactly" do
      with_post_grid_key(mode: "live")
      expect(described_class.default_mode).to eq(:live)
    end

    it "treats a typo as test rather than promoting the deploy to live mail" do
      with_post_grid_key(mode: "LIVEE")
      expect(described_class.default_mode).to eq(:test)
    end
  end

  describe "error hierarchy" do
    it "marks 5xx and rate-limit failures retryable and the rest not" do
      expect(PostGrid::ServiceError.new).to be_retryable
      expect(PostGrid::RateLimitError.new).to be_retryable
      expect(PostGrid::InvalidRequestError.new).not_to be_retryable
      expect(PostGrid::AuthenticationError.new).not_to be_retryable
      expect(PostGrid::ConfigurationError.new).not_to be_retryable
    end

    it "carries the status and PostGrid's error type for logging" do
      error = PostGrid::InvalidRequestError.new("bad", status: 400, error_code: "invalid_request_error")

      expect(error.status).to eq(400)
      expect(error.error_code).to eq("invalid_request_error")
    end
  end
end
