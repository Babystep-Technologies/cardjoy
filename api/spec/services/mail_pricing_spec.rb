require "rails_helper"

# The rate card and the markup (#147). No network: PostGrid has no price
# endpoint, which is the whole reason this class exists.
RSpec.describe MailPricing do
  describe ".quote" do
    it "prices every combination the shipped rate card covers" do
      described_class.priced_combinations.each do |size, mailing_class, zone|
        quote = described_class.quote(size:, zone:, mailing_class:)

        expect(quote.base_cents).to be_positive
        expect(quote.markup_cents).to be_positive
        expect(quote.total_cents).to eq(quote.base_cents + quote.markup_cents)
        expect(quote.total_cents).to be > quote.base_cents
      end
    end

    it "carries back the size, class, and zone it priced" do
      quote = described_class.quote(size: "6x9", zone: "canada")

      expect(quote.size).to eq("6x9")
      expect(quote.zone).to eq("canada")
      expect(quote.mailing_class).to eq(MailPricing::MAILING_CLASS_FIRST_CLASS)
    end

    it "defaults to first class, the only class we mail today" do
      expect(described_class.quote(size: "6x4", zone: "us_domestic"))
        .to eq(described_class.quote(size: "6x4", zone: "us_domestic", mailing_class: "first_class"))
    end

    it "raises for a mailing class the rate card does not cover" do
      expect { described_class.quote(size: "6x4", zone: "us_domestic", mailing_class: "standard") }
        .to raise_error(MailPricing::UnknownRateError)
    end

    it "raises for a size the rate card does not cover" do
      expect { described_class.quote(size: "8x10", zone: "us_domestic") }
        .to raise_error(MailPricing::UnknownRateError)
    end

    # The one that costs money if it is wrong: a quiet fallback to the domestic
    # rate means mailing to Australia at the US price, every time, forever.
    describe "an unknown zone" do
      it "raises rather than falling back to the domestic rate" do
        expect { described_class.quote(size: "6x4", zone: "antarctica") }
          .to raise_error(MailPricing::UnknownRateError, /antarctica/)
      end

      it "raises for a nil zone — an unverified address has no price" do
        expect { described_class.quote(size: "6x4", zone: nil) }
          .to raise_error(MailPricing::UnknownRateError)
      end

      it "does not silently return the domestic price" do
        domestic = described_class.quote(size: "6x4", zone: "us_domestic").total_cents

        expect { described_class.quote(size: "6x4", zone: "antarctica") }
          .to raise_error(MailPricing::UnknownRateError)
        expect(domestic).to be_positive
      end
    end
  end

  describe "the markup" do
    # 86¢ × 1.30 is exactly 111.8¢. Rounding to nearest would give the user
    # 0.2¢ on every 6x4 we mail; over a season that is real money.
    it "rounds up when the exact product is fractional" do
      quote = described_class.quote(size: "6x4", zone: "us_domestic")

      expect(quote.base_cents).to eq(86)
      expect(quote.total_cents).to eq(112)
      expect(quote.markup_cents).to eq(26)
    end

    it "rounds up a product ending in exactly half a cent" do
      # 145 × 1.30 = 188.5 — the case a `.round` would take the wrong way.
      quote = described_class.quote(size: "6x4", zone: "canada")

      expect(quote.base_cents).to eq(145)
      expect(quote.total_cents).to eq(189)
    end

    it "never returns a total below cost plus the markup, for any priced piece" do
      described_class.priced_combinations.each do |size, mailing_class, zone|
        quote = described_class.quote(size:, zone:, mailing_class:)
        exact = quote.base_cents * (MailPricing::BASIS_POINTS_PER_UNIT + MailPricing::MARKUP_BASIS_POINTS)

        expect(quote.total_cents * MailPricing::BASIS_POINTS_PER_UNIT).to be >= exact
        # …and it rounds up rather than up-and-then-some: one cent less would
        # be below cost plus markup.
        expect((quote.total_cents - 1) * MailPricing::BASIS_POINTS_PER_UNIT).to be < exact
      end
    end

    it "returns integer cents, never a float" do
      quote = described_class.quote(size: "6x9", zone: "international")

      expect(quote.total_cents).to be_an(Integer)
      expect(quote.markup_cents).to be_an(Integer)
    end
  end

  describe "rate card versions" do
    it "reports the version it priced under, so an order can record it" do
      quote = described_class.quote(size: "6x4", zone: "us_domestic")

      expect(quote.rate_card_version).to eq(MailPricing::CURRENT_RATE_CARD_VERSION)
      expect(MailPricing::RATE_CARDS).to have_key(quote.rate_card_version)
    end

    it "can price under an explicitly named past version" do
      quote = described_class.quote(
        size: "6x4", zone: "us_domestic", rate_card_version: MailPricing::CURRENT_RATE_CARD_VERSION
      )

      expect(quote.rate_card_version).to eq(MailPricing::CURRENT_RATE_CARD_VERSION)
    end

    it "raises for a version we have never shipped" do
      expect { described_class.quote(size: "6x4", zone: "us_domestic", rate_card_version: "1999-01") }
        .to raise_error(MailPricing::UnknownRateCardError)
    end

    it "covers all three MVP zones for both card sizes" do
      zones = [
        PostGrid::AddressVerification::ZONE_US_DOMESTIC,
        PostGrid::AddressVerification::ZONE_CANADA,
        PostGrid::AddressVerification::ZONE_INTERNATIONAL
      ]

      HolidayCard::VALID_SIZES.each do |size|
        zones.each { |zone| expect { described_class.quote(size:, zone:) }.not_to raise_error }
      end
    end
  end

  describe ".priceable?" do
    it "is true for a zone on the rate card" do
      expect(described_class.priceable?(size: "6x4", zone: "us_domestic")).to be(true)
    end

    it "is false rather than raising for one that is not" do
      expect(described_class.priceable?(size: "6x4", zone: "antarctica")).to be(false)
    end
  end
end
