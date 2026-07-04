require 'rails_helper'

RSpec.describe CardMailer, type: :mailer do
  let(:card) { create(:card) }
  let(:email) { 'test@example.com' }
  let(:frontend_url) { 'https://example.com' }

  before do
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

    it 'includes the viewable link in the body' do
      expect(mail.body.encoded).to include("#{frontend_url}/card/#{card.external_id}/viewable")
    end
  end
end
