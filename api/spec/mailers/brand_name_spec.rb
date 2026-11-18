require 'rails_helper'

# Guards the CardJoy -> Felicito rename: no email we send may mention the old name,
# neither in the sender nor in the rendered layout.
RSpec.describe 'email brand name', type: :mailer do
  it 'has no mention of the old brand in the default sender' do
    expect(ApplicationMailer.default[:from]).not_to match(/cardjoy/i)
    expect(ApplicationMailer.default[:from]).to match(/felicito/i)
  end

  it 'has no mention of the old brand in the recorded personal-send fixture' do
    html = File.read(Rails.root.join('spec/fixtures/mailers/personal_collaborator_invite.html'))
    expect(html).not_to match(/cardjoy/i)
  end

  it 'has no mention of the old brand in the support mailer' do
    source = File.read(Rails.root.join('app/mailers/support_mailer.rb'))
    expect(source).not_to match(/cardjoy/i)
  end
end
