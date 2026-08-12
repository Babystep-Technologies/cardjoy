require 'rails_helper'

# Organization-branded email (#123). The companion to mailer_layout_spec, which
# pins the *unbranded* output; this one covers what branding changes and, just
# as importantly, what it must never reach.
RSpec.describe 'organization branding', type: :mailer do
  let(:frontend_url) { 'https://example.com' }
  let(:cardjoy_logo_url) { 'https://cdn.example.com/logo.gif' }

  let(:owner) { create(:user) }
  let(:organization) do
    create(:organization,
           name: 'Acme Corp',
           created_by: owner,
           accent_color: '#ff0055',
           email_footer_text: '© 2026 Acme Corp — sent with CardJoy',
           email_reply_to: 'people@acme.example')
  end

  around do |example|
    original_logo = Rails.application.config.x.app_logo_for_email
    Rails.application.config.x.app_logo_for_email = cardjoy_logo_url
    example.run
    Rails.application.config.x.app_logo_for_email = original_logo
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
    stub_request(:head, cardjoy_logo_url)
  end

  def attach_logo(organization)
    organization.logo.attach(
      io: File.open(Rails.root.join('spec/fixtures/files/test_image.jpg')),
      filename: 'acme-logo.jpg',
      content_type: 'image/jpeg'
    )
  end

  describe 'a collaborator invite for an organization-owned card' do
    let(:card) { create(:card, user: owner, organization: organization) }

    subject(:mail) { CardMailer.collaborator_invite('invitee@example.com', card) }

    before { attach_logo(organization) }

    it "renders the organization's logo rather than CardJoy's" do
      body = mail.body.decoded

      expect(body).to include(organization.logo_url)
      expect(body).to include('alt="Acme Corp"')
      expect(body).not_to include(cardjoy_logo_url)
    end

    it "renders the organization's accent color everywhere the CardJoy accent used to be" do
      body = mail.body.decoded

      expect(body).to include('color: #ff0055;')
      expect(body).to include('border: 2px solid #ff0055;')
      expect(body).not_to include(MailerBrand::ACCENT_COLOR)
    end

    it "renders the organization's footer text" do
      expect(mail.body.decoded).to include('© 2026 Acme Corp — sent with CardJoy')
      expect(mail.body.decoded).not_to include('BabyStep Technologies')
    end

    it "replies to the organization but still sends from CardJoy" do
      expect(mail.reply_to).to eq([ 'people@acme.example' ])
      expect(mail.from).to eq([ 'team.cardjoy@gmail.com' ])
    end

    # The reason MailerBrand resolves the logo lazily: an attached blob is known
    # to exist, so the availability check the global logo needs is pure cost.
    it 'makes no HTTP request to render the organization logo' do
      mail.body.decoded

      expect(a_request(:head, cardjoy_logo_url)).not_to have_been_made
    end
  end

  describe 'an organization with no branding set' do
    let(:bare_organization) { create(:organization, name: 'Plain Co', created_by: owner) }
    let(:card) { create(:card, user: owner, organization: bare_organization) }

    subject(:mail) { CardMailer.collaborator_invite('invitee@example.com', card) }

    it 'falls back to every CardJoy default, including the logo' do
      body = mail.body.decoded

      expect(body).to include(cardjoy_logo_url)
      expect(body).to include('alt="CardJoy Logo"')
      expect(body).to include(MailerBrand::ACCENT_COLOR)
      expect(body).to include('BabyStep Technologies, Inc. All rights reserved.')
    end

    it 'sets no Reply-To header' do
      expect(mail.reply_to).to be_nil
    end
  end

  # An archived organization stops granting access to its former members
  # (OrganizationScoped), and for the same reason stops branding their mail.
  describe 'an archived organization' do
    let(:card) { create(:card, user: owner, organization: organization) }

    it 'falls back to CardJoy branding' do
      attach_logo(organization)
      card
      organization.archive!

      body = CardMailer.collaborator_invite('invitee@example.com', card.reload).body.decoded

      expect(body).to include('BabyStep Technologies, Inc. All rights reserved.')
      expect(body).not_to include('Acme Corp')
    end
  end

  describe 'account mail' do
    before { attach_logo(organization) }

    let(:member) do
      user = create(:user)
      create(:organization_membership, organization: organization, user: user)
      user.update!(active_organization: organization)
      user
    end

    # Account mail is about the CardJoy account itself, not about anything the
    # organization owns, so it must stay CardJoy-branded even for a user whose
    # active organization is fully branded.
    it 'is never organization-branded, even for a member of a branded organization' do
      mail = UserMailer.confirmation_code(user: member)
      body = mail.body.decoded

      expect(body).to include('BabyStep Technologies, Inc. All rights reserved.')
      expect(body).to include(MailerBrand::ACCENT_COLOR)
      expect(body).not_to include('Acme Corp')
      expect(mail.reply_to).to be_nil
    end
  end

  describe 'an organization invitation' do
    let(:invitation) do
      create(:organization_invitation, organization: organization, invited_by: owner)
    end

    it 'is branded by the inviting organization' do
      body = OrganizationMailer.invitation(invitation).body.decoded

      expect(body).to include('© 2026 Acme Corp — sent with CardJoy')
    end
  end
end
