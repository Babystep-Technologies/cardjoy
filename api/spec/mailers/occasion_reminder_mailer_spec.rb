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

    describe "when the contact has a registry on CardJoy" do
      let(:contact) { create(:contact, user:, name: "Jordan", email: "Jordan@Example.com") }
      let(:friend) { create(:user, email: "jordan@example.com") }

      it "links to the registry matched by email" do
        list = create(:wish_list, :standalone, user: friend, title: "Jordan's 30th")

        expect(mail.body.encoded).to include("#{frontend_url}/registry/#{list.external_id}")
        expect(mail.body.encoded).to include("Jordan&#39;s 30th")
      end

      it "skips a hidden registry" do
        friend
        create(:wish_list, :standalone, user: friend, visible: false)

        expect(mail.body.encoded).not_to include("/registry/")
      end

      it "skips a registry whose event has passed" do
        create(:wish_list, :standalone, user: friend, event_date: Date.current - 1)

        expect(mail.body.encoded).not_to include("/registry/")
      end

      it "prefers a registry for the occasion over a sooner one for something else" do
        create(:wish_list, :standalone, user: friend, occasion: "wedding", event_date: Date.current + 1)
        birthday = create(:wish_list, :standalone, user: friend, occasion: "birthday", event_date: Date.current + 40)

        expect(mail.body.encoded).to include("/registry/#{birthday.external_id}")
      end
    end

    it "mentions no registry for a contact without a matching account" do
      expect(mail.body.encoded).not_to include("/registry/")
    end

    it "includes a curated design suggestion in the body" do
      suggestion = OccasionDesignSuggestion.for("Birthday")
      expect(mail.body.encoded).to include(suggestion.headline)
    end

    it "deep-links into the pre-filled create flow with occasion, recipient, effect and deliverAt" do
      body = mail.body.encoded
      expect(body).to include("#{frontend_url}/one-on-one-card/new?")
      expect(body).to include("occasion=Birthday")
      expect(body).to include("recipient=Jordan")
      # The curated Birthday suggestion pre-selects the confetti effect, and the
      # send is pre-scheduled for the occasion's next occurrence.
      expect(body).to include("effect=confetti")
      expect(body).to include("deliverAt=#{occasion.next_occurrence.iso8601}")
    end

    it "includes the occasion id for reminder-to-card conversion attribution (#30)" do
      expect(mail.body.encoded).to include("occasionId=#{occasion.id}")
    end

    it "names the person in the reminder body" do
      expect(mail.body.encoded).to include("Jordan")
    end
  end
end
