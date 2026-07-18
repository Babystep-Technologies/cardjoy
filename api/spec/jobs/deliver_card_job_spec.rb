# typed: false

require "rails_helper"

RSpec.describe DeliverCardJob, type: :job do
  let(:user) { create(:user) }
  let(:deliver_at) { 3.days.from_now.change(usec: 0) }
  let(:card) { create(:card, :one_on_one, user:, deliver_at:) }

  describe "#perform" do
    it "sends the 1-on-1 delivery email when the scheduled time still matches" do
      expect {
        described_class.new.perform(card.external_id, "friend@example.com", deliver_at.iso8601)
      }.to have_enqueued_mail(CardMailer, :one_on_one_delivery).with("friend@example.com", card)
    end

    it "does not send when the scheduled delivery was cancelled" do
      card.update!(deliver_at: nil)

      expect {
        described_class.new.perform(card.external_id, "friend@example.com", deliver_at.iso8601)
      }.not_to have_enqueued_mail(CardMailer, :one_on_one_delivery)
    end

    it "does not send when the card was rescheduled to a different time" do
      card.update!(deliver_at: 10.days.from_now.change(usec: 0))

      expect {
        described_class.new.perform(card.external_id, "friend@example.com", deliver_at.iso8601)
      }.not_to have_enqueued_mail(CardMailer, :one_on_one_delivery)
    end

    it "handles a missing card gracefully" do
      expect {
        described_class.new.perform("ZZZZZZZ", "friend@example.com", deliver_at.iso8601)
      }.not_to raise_error
    end
  end
end
