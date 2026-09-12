require "rails_helper"

RSpec.describe SupportTicket, type: :model do
  describe "reply_token (#174)" do
    it "generates a random token on create" do
      ticket = create(:support_ticket)
      expect(ticket.reply_token).to be_present
      expect(ticket.reply_token).not_to eq(create(:support_ticket).reply_token)
    end

    it "builds the mail-in reply address from the token" do
      ticket = create(:support_ticket)
      expect(ticket.reply_to_address).to eq("support+#{ticket.reply_token}@#{AppConfig.support_inbound_email_domain}")
    end

    describe ".active_for_reply_token" do
      it "finds the ticket for a live token" do
        ticket = create(:support_ticket)
        expect(described_class.active_for_reply_token(ticket.reply_token)).to eq(ticket)
      end

      it "returns nil for an unknown token" do
        create(:support_ticket)
        expect(described_class.active_for_reply_token("not-a-real-token")).to be_nil
      end

      it "returns nil for a blank token" do
        expect(described_class.active_for_reply_token(nil)).to be_nil
        expect(described_class.active_for_reply_token("")).to be_nil
      end

      it "returns nil once the token is revoked" do
        ticket = create(:support_ticket)
        ticket.revoke_reply_token!
        expect(described_class.active_for_reply_token(ticket.reply_token)).to be_nil
      end

      it "returns nil once the ticket is deleted" do
        ticket = create(:support_ticket)
        ticket.delete!
        expect(described_class.active_for_reply_token(ticket.reply_token)).to be_nil
      end
    end

    it "#revoke_reply_token! marks the token revoked without deleting the ticket" do
      ticket = create(:support_ticket)
      ticket.revoke_reply_token!
      expect(ticket.reply_token_revoked?).to be(true)
      expect(ticket.deleted?).to be(false)
    end
  end

  describe "#record_customer_reply!" do
    it "stamps inbound_email_id when a reply arrived by mail" do
      ticket = create(:support_ticket, :pending)
      ticket.record_customer_reply!(user: ticket.user, body: "By email", inbound_email_id: "42")
      expect(ticket.messages.last.inbound_email_id).to eq("42")
      expect(ticket.reload.status).to eq(SupportTicket::OPEN)
    end

    it "leaves inbound_email_id nil for a reply through the customer mutation" do
      ticket = create(:support_ticket)
      ticket.record_customer_reply!(user: ticket.user, body: "From the app")
      expect(ticket.messages.last.inbound_email_id).to be_nil
    end
  end
end
