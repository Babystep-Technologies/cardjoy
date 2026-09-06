require 'rails_helper'

RSpec.describe PostageCredit, type: :model do
  # PostageCredit shares CreditLedger's events validation with Credit and
  # OrganizationCredit, but keeps its own allowlist and its own non-zero rule.
  # These cover what is specific to the postage ledger; the shared rules
  # themselves are exercised in credit_spec.rb.
  def event(overrides = {})
    {
      "event_kind" => "postage_purchased",
      "event_happened_at" => Time.now.utc.iso8601(3),
      "event_data" => { "amount_cents" => 500 }
    }.merge(overrides)
  end

  describe "events validation" do
    it "accepts a well-formed event" do
      expect(build(:postage_credit, events: [ event ])).to be_valid
    end

    it "accepts a blank events array" do
      expect(build(:postage_credit, events: nil)).to be_valid
      expect(build(:postage_credit, events: [])).to be_valid
    end

    it "accepts every kind on the postage allowlist" do
      PostageCredit::EVENT_KINDS.each do |kind|
        expect(build(:postage_credit, events: [ event("event_kind" => kind) ]))
          .to be_valid, "expected #{kind} to be allowed on a postage row"
      end
    end

    it "rejects a kind belonging to the personal credit ledger" do
      row = build(:postage_credit, events: [ event("event_kind" => "signup_bonus") ])

      expect(row).not_to be_valid
      expect(row.errors[:events].join).to include("'signup_bonus' at index 0 is not allowed")
    end

    it "rejects a kind belonging to the organization ledger" do
      row = build(:postage_credit, events: [ event("event_kind" => "org_credit_purchased") ])

      expect(row).not_to be_valid
      expect(row.errors[:events].join).to include("'org_credit_purchased' at index 0 is not allowed")
    end

    it "rejects an invented kind" do
      row = build(:postage_credit, events: [ event("event_kind" => "postage_teleported") ])

      expect(row).not_to be_valid
      expect(row.errors[:events].join).to include("is not allowed")
    end

    it "rejects a timestamp without milliseconds" do
      row = build(:postage_credit, events: [ event("event_happened_at" => "2026-01-01T00:00:00Z") ])

      expect(row).not_to be_valid
      expect(row.errors[:events].join).to include("must be a valid ISO 8601 string")
    end
  end

  describe "amount_cents" do
    it "rejects a zero row, which would move nothing and only pollute the ledger" do
      row = build(:postage_credit, amount_cents: 0)

      expect(row).not_to be_valid
      expect(row.errors[:amount_cents]).to be_present
    end

    it "rejects a missing amount" do
      expect(build(:postage_credit, amount_cents: nil)).not_to be_valid
    end

    it "accepts a negative row — that is a piece of mail" do
      expect(build(:postage_credit, amount_cents: -86)).to be_valid
    end
  end

  describe ".available" do
    it "returns only the rows that put postage in" do
      user = create(:user)
      topup = create(:postage_credit, user: user, amount_cents: 1000)
      create(:postage_credit, user: user, amount_cents: -86)

      expect(user.postage_credits.available).to contain_exactly(topup)
    end
  end
end
