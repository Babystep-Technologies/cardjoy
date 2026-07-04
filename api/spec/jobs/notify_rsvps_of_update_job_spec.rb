# typed: false

require "rails_helper"

RSpec.describe NotifyRsvpsOfUpdateJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user) }
    let(:invitation) { create(:invitation, user: user) }
    let!(:going_rsvp) { create(:rsvp, invitation: invitation, status: "going", guest_email: "going@example.com") }
    let!(:maybe_rsvp) { create(:rsvp, invitation: invitation, status: "maybe", guest_email: "maybe@example.com") }
    let!(:not_going_rsvp) { create(:rsvp, invitation: invitation, status: "not-going", guest_email: "notgoing@example.com") }

    it "sends notifications to RSVPs with 'going' status" do
      expect(RsvpMailer).to receive(:invitation_updated).with(going_rsvp).and_call_original
      expect(RsvpMailer).to receive(:invitation_updated).with(maybe_rsvp).and_call_original

      described_class.new.perform(invitation.id)
    end

    it "does not send notifications to RSVPs with 'not-going' status" do
      expect(RsvpMailer).to receive(:invitation_updated).with(going_rsvp).and_call_original
      expect(RsvpMailer).to receive(:invitation_updated).with(maybe_rsvp).and_call_original
      expect(RsvpMailer).not_to receive(:invitation_updated).with(not_going_rsvp)

      described_class.new.perform(invitation.id)
    end

    it "handles missing invitation gracefully" do
      expect {
        described_class.new.perform(999_999)
      }.not_to raise_error
    end

    it "logs the notification count" do
      allow(Rails.logger).to receive(:info)

      described_class.new.perform(invitation.id)

      expect(Rails.logger).to have_received(:info).with(/Sending update notifications to 2 RSVPs/)
    end

    it "continues processing if one RSVP notification fails" do
      allow(RsvpMailer).to receive(:invitation_updated).with(going_rsvp).and_raise(StandardError, "Email service error")
      allow(RsvpMailer).to receive(:invitation_updated).with(maybe_rsvp).and_call_original
      allow(Rails.logger).to receive(:error)

      expect {
        described_class.new.perform(invitation.id)
      }.not_to raise_error

      expect(Rails.logger).to have_received(:error).with(/Failed to send update notification to going@example\.com/)
    end
  end
end
