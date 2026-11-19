require 'rails_helper'

# Guards the CardJoy -> Felicito rename in email. The sender's mailbox is still the original
# Gmail address for now (only its display name changed), so we assert on the display name and on
# the rendered content rather than on the address.
RSpec.describe 'email brand name', type: :mailer do
  it 'sends from a Felicito display name' do
    expect(ApplicationMailer.default[:from]).to start_with('Felicito <')
  end

  it 'has no mention of the old brand in the recorded personal-send fixture' do
    html = File.read(Rails.root.join('spec/fixtures/mailers/personal_collaborator_invite.html'))
    expect(html).not_to match(/cardjoy/i)
  end
end
