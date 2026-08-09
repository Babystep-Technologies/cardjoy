require "rails_helper"

RSpec.describe OrganizationCredit, type: :model do
  def event(overrides = {})
    {
      "event_kind" => "org_credit_purchased",
      "event_happened_at" => Time.now.utc.iso8601(3),
      "event_data" => { "amount" => 5 }
    }.merge(overrides)
  end

  describe "events validation" do
    it "accepts a well-formed event" do
      expect(build(:organization_credit, events: [ event ])).to be_valid
    end

    it "accepts a blank events array" do
      expect(build(:organization_credit, events: nil)).to be_valid
      expect(build(:organization_credit, events: [])).to be_valid
    end

    it "rejects an event kind outside this ledger's allowlist" do
      credit = build(:organization_credit, events: [ event("event_kind" => "signup_bonus") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("'signup_bonus' at index 0 is not allowed")
    end

    it "rejects an event missing event_kind or event_data" do
      credit = build(:organization_credit, events: [ { "event_happened_at" => Time.now.utc.iso8601(3) } ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("must have event_kind and event_data")
    end

    it "rejects a non-hash event_data" do
      credit = build(:organization_credit, events: [ event("event_data" => "nope") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("event_data at index 0 must be a hash")
    end

    it "rejects a timestamp without milliseconds" do
      credit = build(:organization_credit, events: [ event("event_happened_at" => "2026-01-01T00:00:00Z") ])

      expect(credit).not_to be_valid
      expect(credit.errors[:events].join).to include("must be a valid ISO 8601 string")
    end

    it "rejects events that are not an array" do
      credit = build(:organization_credit, events: { "event_kind" => "org_credit_purchased" })

      expect(credit).not_to be_valid
      expect(credit.errors[:events]).to include("must be an array")
    end
  end

  describe "scopes" do
    it "available returns only positive rows" do
      organization = create(:organization)
      grant = create(:organization_credit, organization:, amount: 5)
      create(:organization_credit, organization:, amount: -2)

      expect(organization.organization_credits.available).to contain_exactly(grant)
    end
  end
end
