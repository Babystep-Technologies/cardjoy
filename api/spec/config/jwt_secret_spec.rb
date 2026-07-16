# typed: false
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "config/initializers/jwt_secret.rb" do
  # The initializer already ran at boot, so re-load it to exercise the check.
  subject(:run_initializer) { load Rails.root.join("config/initializers/jwt_secret.rb") }

  it "boots when a signing secret is configured" do
    expect { run_initializer }.not_to raise_error
  end

  [ nil, "" ].each do |missing|
    it "refuses to boot when the signing secret is #{missing.inspect}" do
      allow(Rails.configuration.x).to receive(:jwt_secret).and_return(missing)

      expect { run_initializer }.to raise_error(/JWT signing secret is missing/)
    end
  end

  it "names both ways to supply the secret, so the error is actionable" do
    allow(Rails.configuration.x).to receive(:jwt_secret).and_return(nil)

    expect { run_initializer }.to raise_error(/JWT_SECRET_KEY.*credentials:edit/m)
  end
end
