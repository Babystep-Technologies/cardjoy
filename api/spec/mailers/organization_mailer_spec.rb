require "rails_helper"

RSpec.describe OrganizationMailer, type: :mailer do
  let(:frontend_url) { "https://example.com" }
  let(:inviter) { create(:user, name: "Dana Host") }
  let(:organization) { create(:organization, name: "Acme Corp", description: "We send cards", created_by: inviter) }

  before { allow(AppConfig).to receive(:frontend_url).and_return(frontend_url) }

  describe "#invitation" do
    let(:invitation) do
      create(:organization_invitation, organization:, invited_by: inviter, email: "invitee@example.com")
    end

    subject(:mail) { described_class.invitation(invitation) }

    it "goes to the invited address and names the inviter and organization" do
      expect(mail.to).to eq([ "invitee@example.com" ])
      expect(mail.subject).to eq("Dana Host invited you to join Acme Corp on CardJoy")
    end

    it "links to the join page with the invitation token" do
      expect(mail.body.encoded).to include("#{frontend_url}/organizations/join?token=#{invitation.token}")
    end

    it "names the role being offered" do
      expect(mail.body.encoded).to include("a member")

      admin_invite = create(:organization_invitation, :admin, organization:, invited_by: inviter,
                                                              email: "boss@example.com")
      expect(described_class.invitation(admin_invite).body.encoded).to include("an admin")
    end

    it "says when the invitation expires" do
      expect(mail.body.encoded).to include(invitation.expires_at.strftime("%B %-d, %Y"))
    end

    it "includes the organization description when there is one" do
      expect(mail.body.encoded).to include("We send cards")
    end
  end
end
