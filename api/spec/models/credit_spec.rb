require 'rails_helper'

RSpec.describe Credit, type: :model do
  # Credit's events validation now lives in CreditLedger, shared with
  # OrganizationCredit. These cover the extraction: the rules, and the
  # allowlist, must still be Credit's own.
  def event(overrides = {})
    {
      "event_kind" => "credit_purchased",
      "event_happened_at" => Time.now.utc.iso8601(3),
      "event_data" => { "amount" => 1 }
    }.merge(overrides)
  end

  describe "events validation" do
    it "accepts a well-formed event" do
      expect(build(:credit, events: [ event ])).to be_valid
    end

    it "accepts a blank events array" do
      expect(build(:credit, events: nil)).to be_valid
      expect(build(:credit, events: [])).to be_valid
    end

    it "rejects an event kind belonging to the organization ledger" do
      credit = build(:credit, events: [ event("event_kind" => "org_credit_purchased") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("'org_credit_purchased' at index 0 is not allowed")
    end

    it "rejects an event missing event_kind or event_data" do
      credit = build(:credit, events: [ { "event_happened_at" => Time.now.utc.iso8601(3) } ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("must have event_kind and event_data")
    end

    it "rejects a non-hash event_data" do
      credit = build(:credit, events: [ event("event_data" => "nope") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("event_data at index 0 must be a hash")
    end

    it "rejects a timestamp without milliseconds" do
      credit = build(:credit, events: [ event("event_happened_at" => "2026-01-01T00:00:00Z") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("must be a valid ISO 8601 string")
    end

    it "rejects events that are not an array" do
      credit = build(:credit, events: { "event_kind" => "credit_purchased" })

      expect(credit).not_to be_valid
      expect(credit.errors[:events]).to include("must be an array")
    end
  end
end
