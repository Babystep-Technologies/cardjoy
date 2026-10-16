require "rails_helper"

RSpec.describe PostCard::ReturnAddress do
  describe ".address" do
    it "reads every field from the environment" do
      with_cardjoy_return_address(
        line1: "1 Spec Way", city: "Specville", region: "IL", postal_code: "60000", country: "US"
      )

      expect(described_class.address).to include(
        addressLine1: "1 Spec Way", city: "Specville", provinceOrState: "IL",
        postalOrZip: "60000", countryCode: "US"
      )
    end

    it "falls back to Rails credentials when an env var is unset" do
      with_cardjoy_return_address(line1: nil)
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cardjoy, :return_address, :address_line1).and_return("1 Credential Way")

      expect(described_class.address[:addressLine1]).to eq("1 Credential Way")
    end

    it "leaves addressLine2 blank when unset, rather than a literal nil string" do
      with_cardjoy_return_address

      expect(described_class.address[:addressLine2]).to be_nil
    end
  end

  describe ".configured?" do
    it "is false when any required field is missing" do
      with_cardjoy_return_address(line1: nil)

      expect(described_class.configured?).to be(false)
    end

    it "treats a blank env var as unset, same as PostGrid's own keys" do
      with_cardjoy_return_address(line1: "")

      expect(described_class.configured?).to be(false)
    end

    it "is true once every required field is present" do
      with_cardjoy_return_address

      expect(described_class.configured?).to be(true)
    end

    it "does not require addressLine2" do
      with_cardjoy_return_address

      expect(described_class.configured?).to be(true)
      expect(described_class.address[:addressLine2]).to be_nil
    end
  end
end
