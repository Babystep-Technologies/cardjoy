require "rails_helper"

RSpec.describe SupportTicketMailer, type: :mailer do
  let(:frontend_url) { "https://example.com" }
  let(:customer) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:ticket) { create(:support_ticket, user: customer, subject: "Can't redeem my promo code", external_id: "ABCDEFG") }
  let(:reply) { create(:support_ticket_message, :admin, support_ticket: ticket, body: "Try this instead.") }

  before { allow(AppConfig).to receive(:frontend_url).and_return(frontend_url) }

  subject(:mail) { described_class.admin_reply(reply) }

  it "goes to the customer and references the ticket in the subject" do
    expect(mail.to).to eq([ "dana@example.com" ])
    expect(mail.subject).to eq("Re: Can't redeem my promo code [#ABCDEFG]")
  end

  it "includes the reply body" do
    expect(mail.body.encoded).to include("Try this instead.")
  end

  it "links to the customer's thread in the web app" do
    expect(mail.body.encoded).to include("#{frontend_url}/support/ABCDEFG")
  end

  it "renders through the branded layout" do
    expect(mail.body.encoded).to include(MailerBrand::ACCENT_COLOR)
  end
end
