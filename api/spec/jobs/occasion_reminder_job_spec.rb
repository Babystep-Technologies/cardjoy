# typed: false

require "rails_helper"

RSpec.describe OccasionReminderJob, type: :job do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:) }

  describe "#perform" do
    it "emails the owner of each occasion due within the lead window" do
      occasion = create(:occasion, :non_recurring, contact:, occurs_on: Date.current + 4.days)

      expect {
        described_class.new.perform
      }.to have_enqueued_mail(OccasionReminderMailer, :upcoming_occasion).with(occasion)
    end

    it "stamps last_reminded_at so a second run does not re-send" do
      occasion = create(:occasion, :non_recurring, contact:, occurs_on: Date.current + 4.days)

      described_class.new.perform
      expect(occasion.reload.last_reminded_at).to be_present

      expect {
        described_class.new.perform
      }.not_to have_enqueued_mail(OccasionReminderMailer, :upcoming_occasion)
    end

    it "does not email for occasions outside the lead window" do
      create(:occasion, :non_recurring, contact:, occurs_on: Date.current + 30.days)

      expect {
        described_class.new.perform
      }.not_to have_enqueued_mail(OccasionReminderMailer, :upcoming_occasion)
    end

    it "continues past a failure on one occasion" do
      good = create(:occasion, :non_recurring, contact:, occurs_on: Date.current + 2.days)
      bad = create(:occasion, :non_recurring, contact:, occurs_on: Date.current + 3.days)

      allow(OccasionReminderMailer).to receive(:upcoming_occasion).and_call_original
      allow(OccasionReminderMailer).to receive(:upcoming_occasion).with(bad).and_raise(StandardError, "boom")

      expect { described_class.new.perform }.not_to raise_error
      expect(good.reload.last_reminded_at).to be_present
      expect(bad.reload.last_reminded_at).to be_nil
    end
  end
end
