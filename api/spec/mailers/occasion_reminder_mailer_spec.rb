require "rails_helper"

RSpec.describe OccasionReminderMailer, type: :mailer do
  let(:frontend_url) { "https://example.com" }
  let(:user) { create(:user, name: "Alex", email: "alex@example.com") }
  let(:contact) { create(:contact, user:, name: "Jordan") }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
  end

  describe "#upcoming_occasion" do
    let(:occasion) do
      create(:occasion, :non_recurring, contact:, kind: "Birthday", occurs_on: Date.current + 5.days)
    end

    subject(:mail) { described_class.upcoming_occasion(occasion) }

    it "addresses the contact's owner and names the person and occasion" do
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("Jordan")
      expect(mail.subject).to include("Birthday")
    end

    it "includes a curated design suggestion in the body" do
      suggestion = OccasionDesignSuggestion.for("Birthday")
      expect(mail.body.encoded).to include(suggestion.headline)
    end

    it "deep-links into the pre-filled create flow with occasion and recipient" do
      body = mail.body.encoded
      expect(body).to include("#{frontend_url}/one-on-one-card/new?")
      expect(body).to include("occasion=Birthday")
      expect(body).to include("recipient=Jordan")
    end

    it "names the person in the reminder body" do
      expect(mail.body.encoded).to include("Jordan")
    end
  end
end
