require 'rails_helper'

RSpec.describe CardMailer, type: :mailer do
  let(:card) { create(:card) }
  let(:email) { 'test@example.com' }
  let(:frontend_url) { 'https://example.com' }

  before do
    # `and_call_original` first: the first example to build a card triggers
    # Card's lazy load, which digs into credentials for storage.yml, and a bare
    # `with` stub rejects that call.
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
  end

  describe '#collaborator_invite' do
    subject(:mail) { described_class.collaborator_invite(email, card) }

    it 'renders the correct headers' do
      expect(mail.to).to eq([ email ])
      expect(mail.subject).to eq("You're invited to collaborate on a CardJoy card!")
    end

    it 'includes the editable link in the body' do
      expect(mail.body.encoded).to include("#{frontend_url}/card/#{card.external_id}/editable")
    end
  end

  describe '#viewer_invite' do
    subject(:mail) { described_class.viewer_invite(email, card) }

    it 'renders the correct headers' do
      expect(mail.to).to eq([ email ])
      expect(mail.subject).to eq("You've received a CardJoy card!")
    end

    it 'links to the preview endpoint so the link unfurls when forwarded' do
      expect(mail.body.encoded).to include("/p/card/#{card.external_id}/viewable")
      expect(mail.body.encoded).not_to include("#{frontend_url}/card/#{card.external_id}/viewable")
    end

    it 'links to an absolute URL on the API host' do
      expect(mail.body.encoded).to include("http://localhost:3000/p/card/#{card.external_id}/viewable")
    end
  end

  describe '#one_on_one_delivery' do
    subject(:mail) { described_class.one_on_one_delivery(email, card) }

    it 'renders the correct headers' do
      expect(mail.to).to eq([ email ])
      expect(mail.subject).to eq("Someone sent you a CardJoy card!")
    end

    it 'links to the preview endpoint so the link unfurls when forwarded' do
      expect(mail.body.encoded).to include("http://localhost:3000/p/card/#{card.external_id}/viewable")
      expect(mail.body.encoded).not_to include("#{frontend_url}/card/#{card.external_id}/viewable")
    end
  end
end
