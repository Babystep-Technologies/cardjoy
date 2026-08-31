require "rails_helper"

RSpec.describe PostGrid::AddressVerification do
  subject(:verification) { described_class.new(mode: :test) }

  before { with_post_grid_key }

  def verify_us
    verification.verify(
      line1: "123 Market St", line2: "Apt 4", city: "San Francisco",
      region: "CA", postal_code: "94103", country_code: "US"
    )
  end

  it "posts to the address-verification product, not the print-mail base" do
    request = stub_verification(body: post_grid_fixture("verification_us_deliverable"))

    verify_us

    expect(request).to have_been_made
    expect(a_request(:post, %r{/print-mail/})).not_to have_been_made
  end

  it "sends the address in PostGrid's field names" do
    stub_verification(body: post_grid_fixture("verification_us_deliverable"))

    verify_us

    expect(
      a_request(:post, PostGridHelpers::VERIFY_URL).with(body: {
        address: {
          line1: "123 Market St", line2: "Apt 4", city: "San Francisco",
          provinceOrState: "CA", postalOrZip: "94103", country: "US"
        }
      })
    ).to have_been_made
  end

  describe "a deliverable US address" do
    before { stub_verification(body: post_grid_fixture("verification_us_deliverable")) }

    it "is deliverable and lands in the us_domestic zone" do
      result = verify_us

      expect(result).to be_deliverable
      expect(result.status).to eq("verified")
      expect(result.zone).to eq(described_class::ZONE_US_DOMESTIC)
    end

    it "returns the canonicalized address in our own column names" do
      expect(verify_us.canonical_address).to eq(
        address_line1: "123 MARKET ST",
        address_line2: "APT 4",
        city: "SAN FRANCISCO",
        region: "CA",
        postal_code: "94103-1741",
        country_code: "US"
      )
    end

    # ZIP+4 is what earns the USPS automation rate, so the two halves PostGrid
    # returns separately get rejoined.
    it "rejoins the ZIP and its +4" do
      expect(verify_us.postal_code).to eq("94103-1741")
    end
  end

  describe "an undeliverable address" do
    before { stub_verification(body: post_grid_fixture("verification_us_undeliverable")) }

    it "reports not deliverable but still resolves a zone for pricing" do
      result = verify_us

      expect(result).not_to be_deliverable
      expect(result.status).to eq("failed")
      expect(result.zone).to eq(described_class::ZONE_US_DOMESTIC)
    end

    it "surfaces PostGrid's per-field complaints" do
      expect(verify_us.errors).to include(
        "The street number could not be found on this street.",
        "The ZIP code does not match the city."
      )
    end
  end

  describe "a Canadian address" do
    before { stub_verification(body: post_grid_fixture("verification_ca_deliverable")) }

    # "corrected" means PostGrid fixed something and it *is* deliverable. The
    # correction comes back as a suggestion; it is not applied here.
    it "treats a corrected result as deliverable, in the canada zone" do
      result = verification.verify(line1: "145 Mulock Ave", city: "Toronto", country_code: "CA")

      expect(result).to be_deliverable
      expect(result.status).to eq("corrected")
      expect(result.zone).to eq(described_class::ZONE_CANADA)
      expect(result.canonical_address[:address_line1]).to eq("20-145 MULOCK AVE")
    end
  end

  describe "an international address" do
    before { stub_verification(body: post_grid_fixture("verification_international_deliverable")) }

    it "lands in the international zone" do
      result = verification.verify(line1: "221b Baker St", city: "London", country_code: "GB")

      expect(result).to be_deliverable
      expect(result.zone).to eq(described_class::ZONE_INTERNATIONAL)
      expect(result.country_code).to eq("GB")
    end

    it "drops blank canonical fields rather than clearing what the user typed" do
      result = verification.verify(line1: "221b Baker St", city: "London", country_code: "GB")

      # PostGrid returns provinceOrState: "" for the UK — that means "no such
      # thing here", not "erase the region".
      expect(result.canonical_address).not_to have_key(:region)
    end
  end

  describe "failures" do
    it "raises AuthenticationError on a bad key" do
      stub_verification(status: 401, body: post_grid_fixture("error_unauthorized"))

      expect { verify_us }.to raise_error(PostGrid::AuthenticationError)
    end

    it "raises ServiceError on a 500" do
      stub_verification(status: 500, body: post_grid_fixture("error_server"))

      expect { verify_us }.to raise_error(PostGrid::ServiceError)
    end

    it "raises ServiceError on a timeout" do
      stub_request(:post, PostGridHelpers::VERIFY_URL).to_timeout

      expect { verify_us }.to raise_error(PostGrid::ServiceError)
    end

    it "raises InvalidRequestError on a 400 and does not retry it" do
      stub_verification(status: 400, body: post_grid_fixture("error_invalid_request"))

      expect { verify_us }.to raise_error(PostGrid::InvalidRequestError)
      expect(a_request(:post, PostGridHelpers::VERIFY_URL)).to have_been_made.once
    end
  end

  describe "#verify_contact" do
    it "reads the address off the contact" do
      stub_verification(body: post_grid_fixture("verification_us_deliverable"))
      contact = create(:contact, :mailable)

      expect(verification.verify_contact(contact)).to be_deliverable
      expect(
        a_request(:post, PostGridHelpers::VERIFY_URL)
          .with { |req| JSON.parse(req.body).dig("address", "line1") == "123 Market St" }
      ).to have_been_made
    end
  end

  describe "Result#differs_from?" do
    it "is true when PostGrid canonicalized something" do
      stub_verification(body: post_grid_fixture("verification_ca_deliverable"))
      contact = create(:contact, address_line1: "145 Mulock Ave", city: "Toronto",
                                 postal_code: "M6N 1G9", country_code: "CA")

      expect(verification.verify_contact(contact)).to be_differs_from(contact)
    end

    # Casing alone is not a difference worth interrupting someone over —
    # PostGrid upcases everything, and "did you mean 123 MARKET ST?" is noise.
    it "ignores a pure casing change" do
      stub_verification(body: post_grid_fixture("verification_us_deliverable"))
      contact = create(:contact, address_line1: "123 Market St", address_line2: "Apt 4",
                                 city: "San Francisco", region: "CA",
                                 postal_code: "94103-1741", country_code: "US")

      expect(verification.verify_contact(contact)).not_to be_differs_from(contact)
    end
  end
end
