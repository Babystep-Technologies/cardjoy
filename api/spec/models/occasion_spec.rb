require "rails_helper"

RSpec.describe Occasion, type: :model do
  describe "validations" do
    it "requires kind, occurs_on and a known kind" do
      expect(build(:occasion, kind: nil)).not_to be_valid
      expect(build(:occasion, occurs_on: nil)).not_to be_valid
      expect(build(:occasion, kind: "Not A Real Occasion")).not_to be_valid
      expect(build(:occasion, kind: "Birthday")).to be_valid
    end
  end

  describe "#next_occurrence" do
    it "returns occurs_on unchanged for a non-recurring occasion" do
      occasion = build(:occasion, recurring: false, occurs_on: Date.new(2020, 1, 1))
      expect(occasion.next_occurrence).to eq(Date.new(2020, 1, 1))
    end

    it "rolls a recurring occasion forward to this year when still upcoming" do
      from = Date.new(2026, 1, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(1990, 6, 15))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2026, 6, 15))
    end

    it "rolls a recurring occasion to next year once this year's date has passed" do
      from = Date.new(2026, 7, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(1990, 6, 15))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2027, 6, 15))
    end

    it "clamps a Feb 29 recurring occasion to Feb 28 in a non-leap year" do
      from = Date.new(2025, 1, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(2004, 2, 29))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2025, 2, 28))
    end
  end

  describe ".upcoming" do
    let(:user) { create(:user) }
    let(:contact) { create(:contact, user:) }

    it "includes only occasions whose next occurrence is within the window, soonest first" do
      soon = create(:occasion, contact:, recurring: true,
        occurs_on: Date.new(1990, (Date.current + 5.days).month, (Date.current + 5.days).day))
      later = create(:occasion, contact:, recurring: true,
        occurs_on: Date.new(1990, (Date.current + 20.days).month, (Date.current + 20.days).day))
      # Non-recurring occasion in the past is excluded.
      create(:occasion, contact:, recurring: false, occurs_on: Date.current - 10.days)

      result = described_class.upcoming(user:, within_days: 10)
      expect(result).to eq([ soon ])

      result = described_class.upcoming(user:, within_days: 30)
      expect(result).to eq([ soon, later ])
    end

    it "does not return another user's occasions" do
      create(:occasion, contact:, occurs_on: Date.current + 1.day, recurring: true)
      other_user = create(:user)
      expect(described_class.upcoming(user: other_user, within_days: 30)).to be_empty
    end
  end

  describe ".due_for_reminder" do
    it "includes occasions within the lead window across all users, soonest first" do
      soon = create(:occasion, :non_recurring, occurs_on: Date.current + 2.days)
      also_soon = create(:occasion, :non_recurring, occurs_on: Date.current + 6.days)
      # Outside the 7-day window.
      create(:occasion, :non_recurring, occurs_on: Date.current + 20.days)
      # Already in the past.
      create(:occasion, :non_recurring, occurs_on: Date.current - 3.days)

      expect(described_class.due_for_reminder).to eq([ soon, also_soon ])
    end

    it "excludes occasions already reminded for the current occurrence" do
      occasion = create(:occasion, :non_recurring, occurs_on: Date.current + 3.days,
        last_reminded_at: Time.current)
      expect(described_class.due_for_reminder).not_to include(occasion)
    end

    it "re-includes a recurring occasion once a new year's occurrence enters the window" do
      # Reminded for last year's occurrence; this year's is coming up now.
      occasion = create(:occasion, recurring: true,
        occurs_on: Date.new(1990, (Date.current + 4.days).month, (Date.current + 4.days).day),
        last_reminded_at: 1.year.ago)
      expect(described_class.due_for_reminder).to include(occasion)
    end
  end

  describe "#reminded_for? / #record_reminder!" do
    let(:occasion) { create(:occasion, :non_recurring, occurs_on: Date.current + 3.days) }
    let(:occurrence) { occasion.next_occurrence }

    it "is false when never reminded" do
      expect(occasion.reminded_for?(occurrence)).to be(false)
    end

    it "is true after recording a reminder for the current occurrence" do
      occasion.record_reminder!
      expect(occasion.reminded_for?(occurrence)).to be(true)
    end

    it "treats a reminder before the current occurrence's window as not yet reminded" do
      occasion.update!(last_reminded_at: (occurrence - 30.days).to_time)
      expect(occasion.reminded_for?(occurrence)).to be(false)
    end
  end
end
